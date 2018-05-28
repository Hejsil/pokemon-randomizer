const common = @import("common.zig");
const little = @import("../little.zig");

const toLittle = little.toLittle;
const Little   = little.Little;

pub const BasePokemon = packed struct {
    pokedex_number: u8,

    hp:         u8,
    attack:     u8,
    defense:    u8,
    speed:      u8,
    sp_attack:  u8,
    sp_defense: u8,

    types: [2]Type,

    catch_rate:     u8,
    base_exp_yield: u8,
    items:       [2]u8,
    gender_ratio:   u8,

    unknown1:   u8,
    egg_cycles: u8,
    unknown2:   u8,

    dimension_of_front_sprite: u8,

    blank: [4]u8,

    growth_rate: common.GrowthRate,
    egg_group1: common.EggGroup,
    egg_group2: common.EggGroup,

    tm_hm_learnset: Little(u64),
};

pub const Type = enum(u8) {
    Normal = 0x00,
    Fighting = 0x01,
    Flying = 0x02,
    Poison = 0x03,
    Ground = 0x04,
    Rock = 0x05,
    Bird = 0x06,
    Bug = 0x07,
    Ghost = 0x08,
    Steel = 0x09,

    Unknown = 0x13,
    Fire = 0x14,
    Water = 0x15,
    Grass = 0x16,
    Electric = 0x17,
    Psychic = 0x18,
    Ice = 0x19,
    Dragon = 0x1a,
    Dark = 0x1b,
};

pub const Trainer = packed struct {
    items: [2]u8,
    reward: u8,
    ai: Little(u16),

    // TODO: This seems to have something to do with when trainers should switch, or something
    unknown: Little(u16),
};

pub const PartyType = enum(u8) {
    Standard  = 0x00,
    WithMoves = 0x01,
    WithHeld  = 0x02,
    WithBoth  = 0x03,
};

pub const PartyMember = packed struct {
    level: u8,
    species: u8,

    pub const WithMoves = packed struct {
        base: PartyMember,
        moves: [4]u8,
    };

    pub const WithHeld = packed struct {
        base: PartyMember,
        item: u8,
    };

    pub const WithBoth = packed struct {
        base: PartyMember,
        item: u8,
        moves: [4]u8,
    };
};
