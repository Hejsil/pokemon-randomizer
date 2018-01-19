const std = @import("std");

const debug = std.debug;

const assert = debug.assert;
const u1     = @IntType(false, 1);

// TODO: Figure out if the this have the same id in all games.
//       They probably have, so let's assume that for now and if a bug
//       is ever encountered related to this, we figure it out.
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
    Unknown  = 0x09,
    Fire     = 0x0A,
    Water    = 0x0B,
    Grass    = 0x0C,
    Electric = 0x0D,
    Psychic  = 0x0E,
    Ice      = 0x0F,
    Dragon   = 0x10,
    Dark     = 0x11,
    Fairy    = 0x12,
};

pub const GrowthRate = enum(u8) {
    MediumFast  = 0x00,
    Erratic     = 0x01,
    Fluctuating = 0x02,
    MediumSlow  = 0x03,
    Fast        = 0x04,
    Slow        = 0x05,
};

pub const EggGroup = enum(u4) {
    Monster      = 0x01,
    Water1       = 0x02,
    Bug          = 0x03,
    Flying       = 0x04,
    Field        = 0x05,
    Fairy        = 0x06,
    Grass        = 0x07,
    HumanLike    = 0x08,
    Water3       = 0x09,
    Mineral      = 0x0A,
    Amorphous    = 0x0B,
    Water2       = 0x0C,
    Ditto        = 0x0D,
    Dragon       = 0x0E,
    Undiscovered = 0x0F,
};

pub const Color = enum(u7) {
    Red    = 0x00,
    Blue   = 0x01,
    Yellow = 0x02,
    Green  = 0x03,
    Black  = 0x04,
    Brown  = 0x05,
    Purple = 0x06,
    Gray   = 0x07,
    White  = 0x08,
    Pink   = 0x09,
};

// TODO: Figure out if the this have the same layout in all games that have it.
//       They probably have, so let's assume that for now and if a bug
//       is ever encountered related to this, we figure it out.
pub const EvYield = packed struct {
    hp:         u2,
    attack:     u2,
    defense:    u2,
    speed:      u2,
    sp_attack:  u2,
    sp_defense: u2,
    padding:    u4,
};

pub const Generation = enum(u8) {
    I   = 1,
    II  = 2,
    III = 3,
    IV  = 4,
    V   = 5,
    VI  = 6,
    VII = 7,

    pub fn hasPhysicalSpecialSplit(self: Generation) -> bool {
        return u8(self) > 3;
    }
};

pub const Version = enum {
    Red,
    Blue,
    Yellow,

    Gold,
    Silver,
    Crystal,

    Ruby,
    Sapphire,
    Emerald,
    FireRed,
    LeafGreen,

    Diamond,
    Pearl,
    Platinum,
    HeartGold,
    SoulSilver,

    Black,
    White,
    Black2,
    White2,

    X,
    Y,
    OmegaRuby,
    AlphaSapphire,

    Sun,
    Moon,
    UltraSun,
    UltraMoon,

    pub fn generation(self: Version) -> Generation {
        const V = Version;
        return switch (self) {
            V.Red,  V.Blue,     V.Yellow   => Generation.I,
            V.Gold, V.Silver,   V.Crystal  => Generation.II,
            V.Ruby, V.Sapphire, V.Emerald,
            V.FireRed, V.LeafGreen,        => Generation.III,
            V.Diamond, V.Pearl, V.Platinum,
            V.HeartGold, V.SoulSilver,     => Generation.IV,
            V.Black,  V.White,
            V.Black2, V.White2,            => Generation.V,
            V.X, V.Y, V.OmegaRuby,
            V.AlphaSapphire,               => Generation.VI,
            V.Sun, V.Moon, V.UltraSun,
            V.UltraMoon,                   => Generation.VII
        };
    }
};