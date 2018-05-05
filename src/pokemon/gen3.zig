const std       = @import("std");
const gba       = @import("../gba.zig");
const bits      = @import("../bits.zig");
const little    = @import("../little.zig");
const utils     = @import("../utils/index.zig");
const common    = @import("common.zig");
const constants = @import("gen3-constants.zig");

const mem   = std.mem;
const debug = std.debug;
const io    = std.io;
const os    = std.os;
const slice = utils.slice;

const assert = debug.assert;
const u9     = @IntType(false, 9);

const toLittle = little.toLittle;
const Little   = little.Little;

pub const BasePokemon = packed struct {
    hp:         u8,
    attack:     u8,
    defense:    u8,
    speed:      u8,
    sp_attack:  u8,
    sp_defense: u8,

    types: [2]Type,

    catch_rate:     u8,
    base_exp_yield: u8,

    ev_yield: common.EvYield,

    items: [2]Little(u16),

    gender_ratio:    u8,
    egg_cycles:      u8,
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

    padding: [2]u8
};

pub const EvolutionType = enum(u16) {
    Unused                 = toLittle(u16(0x00)).get(),
    FriendShip             = toLittle(u16(0x01)).get(),
    FriendShipDuringDay    = toLittle(u16(0x02)).get(),
    FriendShipDuringNight  = toLittle(u16(0x03)).get(),
    LevelUp                = toLittle(u16(0x04)).get(),
    Trade                  = toLittle(u16(0x05)).get(),
    TradeHoldingItem       = toLittle(u16(0x06)).get(),
    UseItem                = toLittle(u16(0x07)).get(),
    AttackGthDefense       = toLittle(u16(0x08)).get(),
    AttackEqlDefense       = toLittle(u16(0x09)).get(),
    AttackLthDefense       = toLittle(u16(0x0A)).get(),
    PersonalityValue1      = toLittle(u16(0x0B)).get(),
    PersonalityValue2      = toLittle(u16(0x0C)).get(),
    LevelUpMaySpawnPokemon = toLittle(u16(0x0D)).get(),
    LevelUpSpawnIfCond     = toLittle(u16(0x0E)).get(),
    Beauty                 = toLittle(u16(0x0F)).get(),
};

pub const Evolution = packed struct {
    @"type": EvolutionType,
    param: Little(u16),
    target: Little(u16),
    padding: [2]u8,
};

pub const PartyType = enum(u8) {
    Standard  = 0x00,
    WithMoves = 0x01,
    WithHeld  = 0x02,
    WithBoth  = 0x03,
};

pub const Trainer = packed struct {
    party_type: PartyType,
    class: u8,
    encounter_music: u8,
    trainer_picture: u8,
    name: [12]u8,
    items: [4]Little(u16),
    is_double: Little(u32),
    ai: Little(u32),
    party_size: Little(u32),
    party_offset: Little(u32),
};

pub const PartyMemberBase = packed struct {
    iv: Little(u16),
    level: Little(u16),
    species: Little(u16),
};

pub const PartyMember = packed struct {
    base: PartyMemberBase,
    padding: Little(u16),
};

pub const PartyMemberWithMoves = packed struct {
    base: PartyMemberBase,
    moves: [4]Little(u16),
    padding: Little(u16),
};

pub const PartyMemberWithHeld = packed struct {
    base: PartyMemberBase,
    held_item: Little(u16),
};

pub const PartyMemberWithBoth = packed struct {
    base: PartyMemberBase,
    held_item: Little(u16),
    moves: [4]Little(u16),
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
    flags: Little(u32),
};

pub const LevelUpMove = packed struct {
    move_id: u9,
    level: u7,
};

pub const Item = packed struct {
    name: [14]u8,
    id: Little(u16),
    price: Little(u16),
    hold_effect: u8,
    hold_effect_param: u8,
    description_offset: Little(u32),
    importance: u8,
    unknown: u8,
    pocked: u8,
    @"type": u8,
    field_use_func: Little(u32),
    battle_usage: Little(u32),
    battle_use_func: Little(u32),
    secondary_id: Little(u32),
};

pub const Type = enum(u8) {
    Normal   = 0x00,
    Fighting = 0x01,
    Flying   = 0x02,
    Poison   = 0x03,
    Ground   = 0x04,
    Rock     = 0x05,
    Bug      = 0x06,
    Ghost    = 0x07,
    Steel    = 0x08,

    Fire     = 0x0A,
    Water    = 0x0B,
    Grass    = 0x0C,
    Electric = 0x0D,
    Psychic  = 0x0E,
    Ice      = 0x0F,
    Dragon   = 0x10,
    Dark     = 0x11,
};

pub const Game = struct {
    const legendaries = constants.legendaries;

    data: []u8,

    // All these fields point into data
    header: &gba.Header,
    trainers: []Trainer,
    moves: []Move,
    tm_hm_learnset: []Little(u64),
    base_stats: []BasePokemon,
    evolution_table: [][5]Evolution,
    level_up_learnset_pointers: []Little(u32),
    hms: []Little(u16),
    items: []Item,
    tms: []Little(u16),

    pub fn fromFile(file: &os.File, allocator: &mem.Allocator) !Game {
        var file_in_stream = io.FileInStream.init(file);
        var in_stream = &file_in_stream.stream;

        const header = try utils.stream.read(in_stream, gba.Header);
        try header.validate();
        try file.seekTo(0);

        const offsets = try getOffsets(header.gamecode);
        const rom = try in_stream.readAllAlloc(allocator, @maxValue(usize));
        errdefer allocator.free(rom);

        if (rom.len % 0x1000000 != 0) return error.InvalidRomSize;

        return Game {
            .data                       = rom,
            .header                     = @ptrCast(&gba.Header, &rom[0]),
            .trainers                   = offsets.trainers.getSlice(Trainer, rom),
            .moves                      = offsets.moves.getSlice(Move, rom),
            .tm_hm_learnset             = offsets.tm_hm_learnset.getSlice(Little(u64), rom),
            .base_stats                 = offsets.base_stats.getSlice(BasePokemon, rom),
            .evolution_table            = offsets.evolution_table.getSlice([5]Evolution, rom),
            .level_up_learnset_pointers = offsets.level_up_learnset_pointers.getSlice(Little(u32), rom),
            .hms                        = offsets.hms.getSlice(Little(u16), rom),
            .items                      = offsets.items.getSlice(Item, rom),
            .tms                        = offsets.tms.getSlice(Little(u16), rom),
        };
    }

    pub fn writeToStream(game: &const Game, in_stream: var) !void {
        try game.header.validate();
        try in_stream.write(game.data);
    }

    pub fn destroy(game: &const Game, allocator: &mem.Allocator) void {
        allocator.free(game.data);
    }

    fn getOffsets(gamecode: []const u8) !constants.Offsets {
        if (mem.eql(u8, gamecode, "BPEE")) return constants.emerald_us_offsets;
        if (mem.eql(u8, gamecode, "AXVE")) return constants.ruby_us_offsets;
        if (mem.eql(u8, gamecode, "AXPE")) return constants.sapphire_us_offsets;
        if (mem.eql(u8, gamecode, "BPRE")) return constants.fire_us_offsets;
        if (mem.eql(u8, gamecode, "BPGE")) return constants.leaf_us_offsets;

        return error.InvalidGen3GameCode;
    }
};
