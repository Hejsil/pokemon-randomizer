const std       = @import("std");
const little    = @import("../little.zig");
const nds       = @import("../nds/index.zig");
const utils     = @import("../utils/index.zig");
const common    = @import("common.zig");
const constants = @import("gen4-constants.zig");

const mem = std.mem;

const Little = little.Little;

const u10 = @IntType(false, 10);

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
    Standard  = 0x00,
    WithMoves = 0x01,
    WithHeld  = 0x02,
    WithBoth  = 0x03,
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
    const legendaries = common.legendaries;

    base_stats: []const &nds.fs.Narc.File,
    moves: []const &nds.fs.Narc.File,
    level_up_moves: []const &nds.fs.Narc.File,
    trainer_data: []const &nds.fs.Narc.File,
    trainer_pokemons: []const &nds.fs.Narc.File,
    tms: []Little(u16),
    hms: []Little(u16),

    pub fn fromRom(rom: &nds.Rom) !Game {
        std.debug.warn("{}\n", rom.header.gamecode);

        const file_names = try getFileNames(rom.header.gamecode);
        const hm_tm_prefix_index = mem.indexOf(u8, rom.arm9, file_names.hm_tm_prefix) ?? return error.CouldNotFindTmsOrHms;
        const hm_tm_index = hm_tm_prefix_index + file_names.hm_tm_prefix.len;
        const hm_tms = ([]Little(u16))(rom.arm9[hm_tm_index..][0..(constants.tm_count + constants.hm_count) * @sizeOf(u16)]);

        return Game {
            .base_stats       = try getNarcFiles(rom.file_system, file_names.base_stats),
            .level_up_moves   = try getNarcFiles(rom.file_system, file_names.level_up_moves),
            .moves            = try getNarcFiles(rom.file_system, file_names.moves),
            .trainer_data     = try getNarcFiles(rom.file_system, file_names.trainer_data),
            .trainer_pokemons = try getNarcFiles(rom.file_system, file_names.trainer_pokemons),
            .tms              = hm_tms[0..92],
            .hms              = hm_tms[92..],
        };
    }

    fn getNarcFiles(file_system: &const nds.fs.Nitro, path: []const u8) ![]const &nds.fs.Narc.File {
        const file = file_system.getFile(path) ?? return error.CouldntFindFile;

        switch (file.@"type") {
            nds.fs.Nitro.File.Type.Binary => return error.InvalidFileType,
            nds.fs.Nitro.File.Type.Narc => |f| return f.root.files.toSliceConst(),
        }
    }

    fn getFileNames(gamecode: []const u8) !constants.Files {
        //if (mem.eql(u8, gamecode, "IREO")) return constants.black2_files;
        //if (mem.eql(u8, gamecode, "IRDO")) return constants.white2_files;
        //if (mem.eql(u8, gamecode, "IRBO")) return constants.black_files;
        //if (mem.eql(u8, gamecode, "IRAO")) return constants.white_files;

        return error.InvalidGen5GameCode;
    }
};
