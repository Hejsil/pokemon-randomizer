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
const os = std.os;
const mem = std.mem;

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

const Hidden = @OpaqueType();

pub const Pokemon = extern struct {
    game: *const Game,

    base: *Hidden,
    learnset: *Hidden,
    level_up_moves: [*]Hidden,
    level_up_moves_count: usize,
};

pub const BaseGame = extern struct {
    version: Version,
};

pub const Game = extern struct {
    base: *BaseGame,
    allocator: *Hidden,
    other: ?*Hidden,

    pub fn load(file: *os.File, allocator: *mem.Allocator) !Game {
        const start = try file.getPos();
        gba_blk: {
            try file.seekTo(start);
            const game = gen3.Game.fromFile(file, allocator) catch break :gba_blk;

            return Game{
                .base = &(try allocator.construct(game)).base,
                .allocator = @ptrCast(*Hidden, allocator),
                .other = null,
            };
        }

        nds_blk: {
            try file.seekTo(start);
            const nds_rom = try allocator.create(nds.Rom);
            nds_rom.* = nds.Rom.fromFile(file, allocator) catch {
                allocator.destroy(nds_rom);
                break :nds_blk;
            };

            if (gen4.Game.fromRom(nds_rom)) |game| {
                return Game{
                    .base = &(try allocator.construct(game)).base,
                    .allocator = @ptrCast(*Hidden, allocator),
                    .other = @ptrCast(*Hidden, nds_rom),
                };
            } else |e1| if (gen5.Game.fromRom(nds_rom)) |game| {
                return Game{
                    .base = &(try allocator.construct(game)).base,
                    .allocator = @ptrCast(*Hidden, allocator),
                    .other = @ptrCast(*Hidden, nds_rom),
                };
            } else |e2| {
                break :nds_blk;
            }
        }

        return error.InvalidGame;
    }

    pub fn save(game: *const Game, file: *os.File) !void {
        const allocator = @ptrCast(*mem.Allocator, game.allocator);

        switch (game.base.version.gen()) {
            Gen.I => @panic("TODO: Gen1"),
            Gen.II => @panic("TODO: Gen2"),
            Gen.III => {
                const g = @fieldParentPtr(gen3.Game, "base", game.base);
                var file_stream = io.FileOutStream.init(file);
                try g.writeToStream(&file_stream.stream);
            },
            Gen.IV,
            Gen.V => {
                const nds_rom = @ptrCast(*Hidden, ??game.other);
                try nds_rom.writeToFile(file, allocator);
            },
            Gen.VI => @panic("TODO: Gen6"),
            Gen.VII => @panic("TODO: Gen7"),
        }
    }

    pub fn deinit(game: *Game) void {
        const allocator = @ptrCast(*mem.Allocator, game.allocator);
        defer game.* = undefined;

        switch (game.base.version.gen()) {
            Gen.I => @panic("TODO: Gen1"),
            Gen.II => @panic("TODO: Gen2"),
            Gen.III => {
                const g = @fieldParentPtr(gen3.Game, "base", game.base);

                debug.assert(game.other == null);
                g.deinit();
                allocator.free(g);
            },
            Gen.IV => {
                const g = @fieldParentPtr(gen4.Game, "base", game.base);
                const nds_rom = @ptrCast(*Hidden, ??game.other);

                nds_rom.deinit();
                allocator.free(nds_rom);
                allocator.free(g);
            },
            Gen.V => {
                const g = @fieldParentPtr(gen5.Game, "base", game.base);
                const nds_rom = @ptrCast(*Hidden, ??game.other);

                nds_rom.deinit();
                allocator.free(nds_rom);
                allocator.free(g);
            },
            Gen.VI => @panic("TODO: Gen6"),
            Gen.VII => @panic("TODO: Gen7"),
        }
    }
};
