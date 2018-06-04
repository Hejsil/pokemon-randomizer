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
    level_up_moves_len: usize,
    level_up_moves: [*]Hidden,
};

pub const Pokemons = extern struct {
    game: *const BaseGame,

    pub fn at(pokemons: *const Pokemons, id: u16) !Pokemon {
        const game = pokemons.game;
        switch (game.version.gen()) {
            Gen.I => @panic("TODO: Gen1"),
            Gen.II => @panic("TODO: Gen2"),
            Gen.III => {
                const g = @fieldParentPtr(gen3.Game, "base", game);
                const level_up_moves = blk: {
                    const start = blk: {
                        const res = generic.at(g.level_up_learnset_pointers, index) catch return error.InvalidOffset;
                        break :blk math.sub(usize, res.get(), 0x8000000) catch return error.InvalidOffset;
                    };

                    const end = end_blk: {
                        var i: usize = start;
                        while (true) : (i += @sizeOf(LevelUpMove)) {
                            const a = generic.at(g.data, i) catch return error.InvalidOffset;
                            const b = generic.at(g.data, i + 1) catch return error.InvalidOffset;
                            if (a == 0xFF and b == 0xFF)
                                break;
                        }

                        break :end_blk i;
                    };

                    break :blk ([]LevelUpMove)(g.data[start..end]);
                };

                return Pokemon{
                    .base = @ptrCast(*Hidden, &g.base_stats[id]),
                    .learnset = @ptrCast(*Hidden, &g.tm_hm_learnset[id]),
                    .level_up_moves_len = level_up_moves.len,
                    .level_up_moves = @ptrCast([*]Hidden, level_up_moves.ptr),
                };
            },
            Gen.IV => {
                const g = @fieldParentPtr(gen4.Game, "base", game);
                return gen45At(gen4.Game, g, id);
            },
            Gen.V => {
                const g = @fieldParentPtr(gen5.Game, "base", game);
                return gen45At(gen5.Game, g, id);
            },
            Gen.VI => @panic("TODO: Gen6"),
            Gen.VII => @panic("TODO: Gen7"),
        }
    }

    fn gen45At(comptime Game: type, game: *const Game, id: usize) !Pokemon {
        const base_pokemon = try getFileAsType(BasePokemon, g.base_stats, index);
        const level_up_moves = blk: {
            var tmp = g.level_up_moves[index].data;
            const res = ([]LevelUpMove)(tmp[0 .. tmp.len - (tmp.len % @sizeOf(LevelUpMove))]);

            // Even though each level up move have it's own file, level up moves still
            // end with 0xFFFF.
            for (res) |level_up_move, i| {
                if (std.mem.eql(u8, ([]const u8)((&level_up_move)[0..1]), []u8{ 0xFF, 0xFF }))
                    break :blk res[0..i];
            }

            // In the case where we don't find the end 0xFFFF, we just
            // return the level up moves, and assume things are correct.
            break :blk res;
        };

        return Pokemon{
            .base = @ptrCast(*Hidden, base_pokemon),
            .learnset = @ptrCast(*Hidden, base_pokemon.tm_hm_learnset),
            .level_up_moves_len = level_up_moves.len,
            .level_up_moves = @ptrCast([*]Hidden, level_up_moves.ptr),
        };
    }

    pub fn len(pokemons: *const Pokemons) u16 {
        const game = pokemons.game;
        switch (game.version.gen()) {
            Gen.I => @panic("TODO: Gen1"),
            Gen.II => @panic("TODO: Gen2"),
            Gen.III => {
                const g = @fieldParentPtr(gen3.Game, "base", game);
                var min = g.tm_hm_learnset.len;
                min = math.min(min, g.base_stats.len);
                min = math.min(min, g.evolution_table.len);
                return math.min(min, g.level_up_learnset_pointers.len);
            },
            Gen.IV => {
                const g = @fieldParentPtr(gen4.Game, "base", game);
                return gen45Len(gen4.Game, g);
            },
            Gen.V => {
                const g = @fieldParentPtr(gen5.Game, "base", game);
                return gen45Len(gen5.Game, g);
            },
            Gen.VI => @panic("TODO: Gen6"),
            Gen.VII => @panic("TODO: Gen7"),
        }
    }

    fn gen45Len(comptime Game: type, game: *const Game) usize {
        var min = math.min(min, game.base_stats.len);
        return math.min(min, game.level_up_moves.len);
    }
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
            Gen.IV, Gen.V => {
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

    pub fn pokemons(game: *const Game) Pokemons {
        return Pokemons{ .game = game.base };
    }
};

fn getFileAsType(comptime T: type, files: []const *nds.fs.Narc.File, index: usize) !*T {
    const data = generic.widenTrim(files[index].data, T);
    return generic.at(data, 0) catch error.FileToSmall;
}
