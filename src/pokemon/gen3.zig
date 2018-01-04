const std = @import("std");
const gba = @import("../gba.zig");
const little = @import("../little.zig");
const debug = std.debug;

const assert = debug.assert;

const Little = little.Little;

const egg_cycle_steps = 256;

pub const Type = enum(u8) {
    Normal   = 00,
    Fighting = 01,
    Flying   = 02,
    Poison   = 03,
    Ground   = 04,
    Rock     = 05,
    Bug      = 06,
    Ghost    = 07,
    Steel    = 08,
    Unknown  = 09,
    Fire     = 10,
    Water    = 11,
    Grass    = 12,
    Electric = 13,
    Psychic  = 14,
    Ice      = 15,
    Dragon   = 16,
    Dark     = 17,
};

pub const EffortYield = packed struct {
    hp: u2,
    attack: u2,
    defense: u2,
    speed: u2,
    sp_attack: u2,
    sp_defense: u2,
    padding: u4,
};

test "pokemon.gen3.EffortYield: Offsets" {
    var effort : EffortYield = undefined;
    const base = @ptrToInt(&effort);

    assert(@ptrToInt(&effort.hp        ) - base == 0x00);
    assert(@ptrToInt(&effort.attack    ) - base == 0x00);
    assert(@ptrToInt(&effort.defense   ) - base == 0x00);
    assert(@ptrToInt(&effort.speed     ) - base == 0x00);
    assert(@ptrToInt(&effort.sp_attack ) - base == 0x01);
    assert(@ptrToInt(&effort.sp_defense) - base == 0x01);
    assert(@ptrToInt(&effort.padding   ) - base == 0x01);

    assert(@typeOf(&effort.hp)         == &align(1:0:2) u2);
    assert(@typeOf(&effort.attack)     == &align(1:2:4) u2);
    assert(@typeOf(&effort.defense)    == &align(1:4:6) u2);
    assert(@typeOf(&effort.speed)      == &align(1:6:8) u2);
    assert(@typeOf(&effort.sp_attack)  == &align(1:0:2) u2);
    assert(@typeOf(&effort.sp_defense) == &align(1:2:4) u2);
    assert(@typeOf(&effort.padding)    == &align(1:4:8) u4);
}

pub const LevelUpType = enum(u8) {
    MediumFast  = 0,
    Erratic     = 1,
    Fluctuating = 2,
    MediumSlow  = 3,
    Fast        = 4,
    Slow        = 5,
};

pub const EggGroup = enum(u8) {
    Monster      = 01,
    Water1       = 02,
    Bug          = 03,
    Flying       = 04,
    Field        = 05,
    Fairy        = 06,
    Grass        = 07,
    HumanLike    = 08,
    Water3       = 09,
    Mineral      = 10,
    Amorphous    = 11,
    Water2       = 12,
    Ditto        = 13,
    Dragon       = 14,
    Undiscovered = 15,
};

pub const ColorAndFlip = enum(u8) {
    Red    = 0,
    Blue   = 1,
    Yellow = 2,
    Green  = 3,
    Black  = 4,
    Brown  = 5,
    Purple = 6,
    Gray   = 7,
    White  = 8,
    Pink   = 9,
};

pub const BasePokemon = packed struct {
    hp:         u8,
    attack:     u8,
    defense:    u8,
    speed:      u8,
    sp_attack:  u8,
    sp_defense: u8,

    type1: Type,
    type2: Type,

    catch_rate:     u8,
    base_exp_yield: u8,

    effort_yield: EffortYield,

    item1: Little(u16),
    item2: Little(u16),

    gender:          u8,
    egg_cycles:      u8,
    base_friendship: u8,

    level_up_type: LevelUpType,

    egg_group1: EggGroup,
    egg_group2: EggGroup,

    abillity1: u8,
    abillity2: u8,

    safari_zone_rate: u8,

    color_and_flip: ColorAndFlip,

    padding: [2]u8
};

test "pokemon.gen3.BasePokemon: Offsets" {
    const stats : BasePokemon = undefined;
    const base = @ptrToInt(&stats);

    assert(@ptrToInt(&stats.hp              ) - base == 00);
    assert(@ptrToInt(&stats.attack          ) - base == 01);
    assert(@ptrToInt(&stats.defense         ) - base == 02);
    assert(@ptrToInt(&stats.speed           ) - base == 03);
    assert(@ptrToInt(&stats.sp_attack       ) - base == 04);
    assert(@ptrToInt(&stats.sp_defense      ) - base == 05);

    assert(@ptrToInt(&stats.type1           ) - base == 06);
    assert(@ptrToInt(&stats.type2           ) - base == 07);

    assert(@ptrToInt(&stats.catch_rate      ) - base == 08);
    assert(@ptrToInt(&stats.base_exp_yield  ) - base == 09);

    assert(@ptrToInt(&stats.effort_yield    ) - base == 10);
    assert(@ptrToInt(&stats.item1           ) - base == 12);
    assert(@ptrToInt(&stats.item2           ) - base == 14);

    assert(@ptrToInt(&stats.gender          ) - base == 16);
    assert(@ptrToInt(&stats.egg_cycles      ) - base == 17);
    assert(@ptrToInt(&stats.base_friendship ) - base == 18);
    assert(@ptrToInt(&stats.level_up_type   ) - base == 19);

    assert(@ptrToInt(&stats.egg_group1      ) - base == 20);
    assert(@ptrToInt(&stats.egg_group2      ) - base == 21);

    assert(@ptrToInt(&stats.abillity1       ) - base == 22);
    assert(@ptrToInt(&stats.abillity2       ) - base == 23);

    assert(@ptrToInt(&stats.safari_zone_rate) - base == 24);
    assert(@ptrToInt(&stats.color_and_flip  ) - base == 25);
    assert(@ptrToInt(&stats.padding         ) - base == 26);

    assert(@sizeOf(BasePokemon) == 28);
}

pub const bulbasaur = BasePokemon {
    .hp         = 45,
    .attack     = 49,
    .defense    = 49,
    .speed      = 45,
    .sp_attack  = 65,
    .sp_defense = 65,

    .type1 = Type.Grass,
    .type2 = Type.Poison,

    .catch_rate     = 45,
    .base_exp_yield = 64,

    .effort_yield = EffortYield {
        .hp         = 0,
        .attack     = 0,
        .defense    = 0,
        .speed      = 0,
        .sp_attack  = 1,
        .sp_defense = 0,
        .padding    = 0,
    },

    .item1 = Little(u16).init(0),
    .item2 = Little(u16).init(0),

    // Bulbasaur gender ration is 1/7
    .gender          = 31,
    .egg_cycles      = 20,
    .base_friendship = 70,

    .level_up_type = LevelUpType.MediumSlow,

    .egg_group1 = EggGroup.Monster,
    .egg_group2 = EggGroup.Grass,

    .abillity1 = 65,
    .abillity2 = 00,

    .safari_zone_rate = 0,

    .color_and_flip = ColorAndFlip.Green,

    .padding = []u8 { 0, 0 },

};

pub const Game = struct {

};