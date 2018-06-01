const std = @import("std");
const little = @import("../little.zig");
const nds = @import("../nds/index.zig");
const utils = @import("../utils/index.zig");
const common = @import("common.zig");
const constants = @import("gen4-constants.zig");

const mem = std.mem;

const Little = little.Little;

const u10 = @IntType(false, 10);

pub const BasePokemon = packed struct {
    hp: u8,
    attack: u8,
    defense: u8,
    speed: u8,
    sp_attack: u8,
    sp_defense: u8,

    types: [2]Type,

    catch_rate: u8,
    base_exp_yield: u8,

    evs: common.EvYield,
    items: [2]Little(u16),

    gender_ratio: u8,
    egg_cycles: u8,
    base_friendship: u8,
    growth_rate: common.GrowthRate,

    egg_group1: common.EggGroup,
    egg_group1_pad: u4,
    egg_group2: common.EggGroup,
    egg_group2_pad: u4,

    abilities: [2]u8,
    flee_rate: u8,

    color: common.Color,
    color_padding: bool,

    // Memory layout
    // TMS 01-92, HMS 01-08
    tm_hm_learnset: Little(u128),
};

pub const MoveTutor = packed struct {
    move: Little(u16),
    cost: u8,
    tutor: u8,
};

pub const PartyMemberBase = packed struct {
    iv: u8,
    gender: u4,
    ability: u4,
    level: Little(u16),
    species: u10,
    form: u6,
};

pub const PartyMemberWithMoves = packed struct {
    base: PartyMemberBase,
    moves: [4]Little(u16),
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

pub const PartyType = enum(u8) {
    Standard = 0x00,
    WithMoves = 0x01,
    WithHeld = 0x02,
    WithBoth = 0x03,
};

pub const Trainer = packed struct {
    party_type: PartyType,
    class: u8,
    battle_type: u8, // TODO: This should probably be an enum
    party_size: u8,
    items: [4]Little(u16),
    ai: Little(u32),
    battle_type2: u8,
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

// TODO: This is the first data structure I had to decode from scratch as I couldn't find a proper resource
//       for it... Fill it out!
pub const Move = packed struct {
    u8_0: u8,
    u8_1: u8,
    category: common.MoveCategory,
    power: u8,
    @"type": Type,
    accuracy: u8,
    pp: u8,
    u8_7: u8,
    u8_8: u8,
    u8_9: u8,
    u8_10: u8,
    u8_11: u8,
    u8_12: u8,
    u8_13: u8,
    u8_14: u8,
    u8_15: u8,
};

pub const Game = struct {
    const legendaries = common.legendaries;

    version: common.Version,
    base_stats: []const *nds.fs.Narc.File,
    moves: []const *nds.fs.Narc.File,
    level_up_moves: []const *nds.fs.Narc.File,
    trainer_data: []const *nds.fs.Narc.File,
    trainer_pokemons: []const *nds.fs.Narc.File,
    tms: []Little(u16),
    hms: []Little(u16),

    pub fn fromRom(rom: *nds.Rom) !Game {
        const info = try getInfo(rom.header.gamecode);
        const hm_tm_prefix_index = mem.indexOf(u8, rom.arm9, info.hm_tm_prefix) ?? return error.CouldNotFindTmsOrHms;
        const hm_tm_index = hm_tm_prefix_index + info.hm_tm_prefix.len;
        const hm_tms = ([]Little(u16))(rom.arm9[hm_tm_index..][0 .. (constants.tm_count + constants.hm_count) * @sizeOf(u16)]);

        return Game{
            .version = info.version,
            .base_stats = try getNarcFiles(rom.file_system, info.base_stats),
            .level_up_moves = try getNarcFiles(rom.file_system, info.level_up_moves),
            .moves = try getNarcFiles(rom.file_system, info.moves),
            .trainer_data = try getNarcFiles(rom.file_system, info.trainer_data),
            .trainer_pokemons = try getNarcFiles(rom.file_system, info.trainer_pokemons),
            .tms = hm_tms[0..92],
            .hms = hm_tms[92..],
        };
    }

    fn getNarcFiles(file_system: *const nds.fs.Nitro, path: []const u8) ![]const *nds.fs.Narc.File {
        const file = file_system.getFile(path) ?? return error.CouldntFindFile;

        switch (file.@"type") {
            nds.fs.Nitro.File.Type.Binary => return error.InvalidFileType,
            nds.fs.Nitro.File.Type.Narc => |f| return f.root.files.toSliceConst(),
        }
    }

    fn getInfo(gamecode: []const u8) !constants.Info {
        if (mem.eql(u8, gamecode, "IPGE")) return constants.ss_info;
        if (mem.eql(u8, gamecode, "IPKE")) return constants.hg_info;
        if (mem.eql(u8, gamecode, "ADAE")) return constants.diamond_info;
        if (mem.eql(u8, gamecode, "APAE")) return constants.pearl_info;
        if (mem.eql(u8, gamecode, "CPUE")) return constants.platinum_info;

        return error.InvalidGen4GameCode;
    }
};
