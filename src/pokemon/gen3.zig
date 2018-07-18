const std = @import("std");
const pokemon = @import("index.zig");
const gba = @import("../gba.zig");
const bits = @import("../bits.zig");
const int = @import("../int.zig");
const utils = @import("../utils/index.zig");
const common = @import("common.zig");

const mem = std.mem;
const debug = std.debug;
const io = std.io;
const os = std.os;
const slice = utils.slice;

const assert = debug.assert;

const lu16 = int.lu16;
const lu32 = int.lu32;
const lu64 = int.lu64;

pub const constants = @import("gen3-constants.zig");

pub const BasePokemon = packed struct {
    stats: common.Stats,
    types: [2]Type,

    catch_rate: u8,
    base_exp_yield: u8,

    ev_yield: common.EvYield,

    items: [2]lu16,

    gender_ratio: u8,
    egg_cycles: u8,
    base_friendship: u8,

    growth_rate: common.GrowthRate,

    egg_group1: common.EggGroup,
    egg_group1_pad: u4,
    egg_group2: common.EggGroup,
    egg_group2_pad: u4,

    abilities: [2]u8,
    safari_zone_rate: u8,

    color: common.Color,
    flip: bool,

    padding: [2]u8,
};

pub const Trainer = packed struct {
    const has_item = 0b10;
    const has_moves = 0b01;

    party_type: u8,
    class: u8,
    encounter_music: u8,
    trainer_picture: u8,
    name: [12]u8,
    items: [4]lu16,
    is_double: lu32,
    ai: lu32,
    party_size: lu32,
    party_offset: lu32,
};

/// All party members have this as the base.
/// * If trainer.party_type & 0b10 then there is an additional u16 after the base, which is the held
///   item. If this is not true, the the party member is padded with u16
/// * If trainer.party_type & 0b01 then there is an additional 4 * u16 after the base, which are
///   the party members moveset.
pub const PartyMember = packed struct {
    iv: lu16,
    level: lu16,
    species: lu16,
};

pub const Move = packed struct {
    effect: u8,
    power: u8,
    @"type": Type,
    accuracy: u8,
    pp: u8,
    side_effect_chance: u8,
    target: u8,
    priority: u8,
    flags: lu32,
};

pub const Item = packed struct {
    name: [14]u8,
    id: lu16,
    price: lu16,
    hold_effect: u8,
    hold_effect_param: u8,
    description_offset: lu32,
    importance: u8,
    unknown: u8,
    pocked: u8,
    @"type": u8,
    field_use_func: lu32,
    battle_usage: lu32,
    battle_use_func: lu32,
    secondary_id: lu32,
};

pub const Type = enum(u8) {
    Normal = 0x00,
    Fighting = 0x01,
    Flying = 0x02,
    Poison = 0x03,
    Ground = 0x04,
    Rock = 0x05,
    Bug = 0x06,
    Ghost = 0x07,
    Steel = 0x08,

    Fire = 0x0A,
    Water = 0x0B,
    Grass = 0x0C,
    Electric = 0x0D,
    Psychic = 0x0E,
    Ice = 0x0F,
    Dragon = 0x10,
    Dark = 0x11,
};

pub const LevelUpMove = packed struct {
    move_id: u9,
    level: u7,
};

pub const Game = struct {
    base: pokemon.BaseGame,
    allocator: *mem.Allocator,
    data: []u8,

    // All these fields point into data
    header: *gba.Header,
    trainers: []Trainer,
    moves: []Move,
    tm_hm_learnset: []lu64,
    base_stats: []BasePokemon,
    evolution_table: [][5]common.Evolution,
    level_up_learnset_pointers: []lu32,
    items: []Item,
    hms: []lu16,
    tms: []lu16,

    pub fn fromFile(file: *os.File, allocator: *mem.Allocator) !Game {
        var file_in_stream = io.FileInStream.init(file);
        var in_stream = &file_in_stream.stream;

        const header = try utils.stream.read(in_stream, gba.Header);
        try header.validate();
        try file.seekTo(0);

        const info = try getInfo(header.game_title, header.gamecode);
        const size = try file.getEndPos();

        if (size % 0x1000000 != 0)
            return error.InvalidRomSize;

        const rom = try allocator.alloc(u8, size);
        errdefer allocator.free(rom);

        try in_stream.readNoEof(rom);

        return Game{
            .base = pokemon.BaseGame{ .version = info.version },
            .allocator = allocator,
            .data = rom,
            .header = @ptrCast(*gba.Header, &rom[0]),
            .trainers = info.trainers.slice(rom),
            .moves = info.moves.slice(rom),
            .tm_hm_learnset = info.machine_learnsets.slice(rom),
            .base_stats = info.base_stats.slice(rom),
            .evolution_table = info.evolutions.slice(rom),
            .level_up_learnset_pointers = info.level_up_learnset_pointers.slice(rom),
            .items = info.items.slice(rom),
            .hms = info.hms.slice(rom),
            .tms = info.tms.slice(rom),
        };
    }

    pub fn writeToStream(game: Game, in_stream: var) !void {
        try game.header.validate();
        try in_stream.write(game.data);
    }

    pub fn deinit(game: *Game) void {
        game.allocator.free(game.data);
        game.* = undefined;
    }

    fn getInfo(game_title: []const u8, gamecode: []const u8) !constants.Info {
        for (constants.infos) |info| {
            if (!mem.eql(u8, info.game_title, game_title))
                continue;
            if (!mem.eql(u8, info.gamecode, gamecode))
                continue;

            return info;
        }

        return error.NotGen3Game;
    }
};
