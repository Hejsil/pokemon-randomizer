pub const common = @import("common.zig");
pub const gen2 = @import("gen2.zig");
pub const gen3 = @import("gen3.zig");
pub const gen4 = @import("gen4.zig");
pub const gen5 = @import("gen5.zig");

const std = @import("std");
const fun = @import("fun");
const nds = @import("../nds/index.zig");
const utils = @import("../utils/index.zig");
const little = @import("../little.zig");
const bits = @import("../bits.zig");

const generic = fun.generic;

const math = std.math;
const debug = std.debug;

const Collection = utils.Collection;

test "pokemon" {
    _ = common;
    _ = gen3;
    _ = gen4;
    _ = gen5;
}

pub const Gen = extern enum {
    I = 1,
    II = 2,
    III = 3,
    IV = 4,
    V = 5,
    VI = 6,
    VII = 7,

    pub fn hasPhysicalSpecialSplit(gen: Gen) bool {
        return @TagType(Gen)(gen) > 3;
    }
};

pub const Version = extern enum {
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

    pub fn gen(version: Version) Gen {
        const V = Version;
        // TODO: Fix format
        return switch (version) {
            V.Red, V.Blue, V.Yellow => Gen.I,
            V.Gold, V.Silver, V.Crystal => Gen.II,
            V.Ruby, V.Sapphire, V.Emerald, V.FireRed, V.LeafGreen => Gen.III,
            V.Diamond, V.Pearl, V.Platinum, V.HeartGold, V.SoulSilver => Gen.IV,
            V.Black, V.White, V.Black2, V.White2 => Gen.V,
            V.X, V.Y, V.OmegaRuby, V.AlphaSapphire => Gen.VI,
            V.Sun, V.Moon, V.UltraSun, V.UltraMoon => Gen.VII,
        };
    }
};

const Species = u16;
const Trainer = u16;

pub const Game = struct {
    version: Version,
};
