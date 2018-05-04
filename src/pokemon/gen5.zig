const std    = @import("std");
const little = @import("../little.zig");
const nds    = @import("../nds/index.zig");
const utils  = @import("../utils/index.zig");
const common = @import("common.zig");

const mem = std.mem;

const Little = little.Little;

pub const BasePokemon = packed struct {
    hp:         u8,
    attack:     u8,
    defense:    u8,
    speed:      u8,
    sp_attack:  u8,
    sp_defense: u8,

    types: [2]Type,

    catch_rate:     u8,

    evs: [3]u8, // TODO: Figure out if common.EvYield fits in these 3 bytes
    items: [3]Little(u16),

    gender_ratio:    u8,
    egg_cycles:      u8,
    base_friendship: u8,

    growth_rate: common.GrowthRate,

    egg_group1: common.EggGroup,
    egg_group1_pad: u4,
    egg_group2: common.EggGroup,
    egg_group2_pad: u4,

    abilities: [3]u8,

    // TODO: The three fields below are kinda unknown
    flee_rate: u8,
    form_stats_start: [2]u8,
    form_sprites_start: [2]u8,

    form_count: u8,

    color: common.Color,
    color_padding: bool,

    base_exp_yield: u8,

    height: Little(u16),
    weight: Little(u16),

    // Memory layout
    // TMS 01-92, HMS 01-06, TMS 93-95
    tm_hm_learnset: Little(u128),

    special_tutors: Little(u32),
    driftveil_tutor: Little(u32),
    lentimas_tutor: Little(u32),
    humilau_tutor: Little(u32),
    nacrene_tutor: Little(u32),
};

// https://projectpokemon.org/home/forums/topic/22629-b2w2-general-rom-info/?do=findComment&comment=153174
pub const PartyMemberBase = packed struct {
    iv: u8,
    gender: u4,
    ability: u4,
    level: u8,
    padding: u8,
    species: Little(u16),
    form: Little(u16),
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
    healer: bool,
    healer_padding: u7,
    cash: u8,
    post_battle_item: Little(u16),
};

// https://projectpokemon.org/home/forums/topic/14212-bw-move-data/?do=findComment&comment=123606
pub const Move = packed struct {
    @"type": Type,
    effect_category: u8,
    category: common.MoveCategory,
    power: u8,
    accuracy: u8,
    pp: u8,
    priority: u8,
    hits: u8,
    min_hits: u4,
    max_hits: u4,
    crit_chance: u8,
    flinch: u8,
    effect: Little(u16),
    target_hp: u8,
    user_hp: u8,
    target: u8,
    stats_affected: [3]u8,
    stats_affected_magnetude: [3]u8,
    stats_affected_chance: [3]u8,

    // TODO: Figure out if this is actually how the last fields are layed out.
    padding: [2]u8,
    flags: Little(u16),
};

pub const LevelUpMove = packed struct {
    move_id: Little(u16),
    level: Little(u16),
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
    Fire     = 0x09,
    Water    = 0x0A,
    Grass    = 0x0B,
    Electric = 0x0C,
    Psychic  = 0x0D,
    Ice      = 0x0E,
    Dragon   = 0x0F,
    Dark     = 0x10,
};

pub const Game = struct {
    const PokemonType = Type;

    const legendaries = common.legendaries;

    base_stats: []const &nds.fs.Narc.File,
    moves: []const &nds.fs.Narc.File,
    level_up_moves: []const &nds.fs.Narc.File,
    trainer_data: []const &nds.fs.Narc.File,
    trainer_pokemons: []const &nds.fs.Narc.File,
    tms1: []Little(u16),
    hms: []Little(u16),
    tms2: []Little(u16),

    pub fn fromRom(rom: &nds.Rom) !Game {
        const tm_count = 95;
        const hm_count = 6;
        const hm_tm_prefix = "\x87\x03\x88\x03";
        const hm_tm_prefix_index = mem.indexOf(u8, rom.arm9, hm_tm_prefix) ?? return error.CouldNotFindTmsOrHms;
        const hm_tm_index = hm_tm_prefix_index + hm_tm_prefix.len;
        const hm_tms = ([]Little(u16))(rom.arm9[hm_tm_index..][0..(tm_count + hm_count) * @sizeOf(u16)]);

        return Game {
            .base_stats       = getNarcFiles(rom.file_system, "a/0/1/6") ?? return error.Err,
            .level_up_moves   = getNarcFiles(rom.file_system, "a/0/1/8") ?? return error.Err,
            .moves            = getNarcFiles(rom.file_system, "a/0/2/1") ?? return error.Err,
            .trainer_data     = getNarcFiles(rom.file_system, "a/0/9/1") ?? return error.Err,
            .trainer_pokemons = getNarcFiles(rom.file_system, "a/0/9/2") ?? return error.Err,
            .tms1             = hm_tms[0..92],
            .hms              = hm_tms[92..98],
            .tms2             = hm_tms[98..],
        };
    }

    fn getNarcFiles(file_system: &const nds.fs.Nitro, path: []const u8) ?[]const &nds.fs.Narc.File {
        const file = file_system.getFile(path) ?? return null;

        switch (file.@"type") {
            nds.fs.Nitro.File.Type.Binary => return null,
            nds.fs.Nitro.File.Type.Narc => |f| return f.root.files.toSliceConst(),
        }
    }
};
