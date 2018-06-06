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

const Namespace = @typeOf(std);

test "pokemon" {
    _ = common;
    _ = gen3;
    _ = gen4;
    _ = gen5;
}

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

    pub fn gen(version: Version) u8 {
        const V = Version;
        // TODO: Fix format
        return switch (version) {
            V.Red, V.Blue, V.Yellow => u8(1),
            V.Gold, V.Silver, V.Crystal => u8(2),
            V.Ruby, V.Sapphire, V.Emerald, V.FireRed, V.LeafGreen => u8(3),
            V.Diamond, V.Pearl, V.Platinum, V.HeartGold, V.SoulSilver => u8(4),
            V.Black, V.White, V.Black2, V.White2 => u8(5),
            V.X, V.Y, V.OmegaRuby, V.AlphaSapphire => u8(6),
            V.Sun, V.Moon, V.UltraSun, V.UltraMoon => u8(7),
        };
    }

    pub fn hasPhysicalSpecialSplit(gen: Gen) bool {
        return @TagType(Gen)(gen) > 3;
    }
};

const Hidden = @OpaqueType();

pub const Pokemon = extern struct {
    game: *const BaseGame,

    base: *Hidden,
    learnset: *Hidden,
    level_up_moves_len: usize,
    level_up_moves: [*]Hidden,

    pub fn hp(pokemon: *const Pokemon) u8 {
        return pokemon.statPtr(u8, "hp").*;
    }

    pub fn setHp(pokemon: *const Pokemon, v: u8) void {
        pokemon.statPtr(u8, "hp") = v;
    }

    pub fn attack(pokemon: *const Pokemon) u8 {
        return pokemon.statPtr(u8, "attack").*;
    }

    pub fn setAttack(pokemon: *const Pokemon, v: u8) void {
        pokemon.statPtr(u8, "attack").* = v;
    }

    pub fn defense(pokemon: *const Pokemon) u8 {
        return pokemon.statPtr(u8, "defense").*;
    }

    pub fn setDefense(pokemon: *const Pokemon, v: u8) void {
        pokemon.statPtr(u8, "defense").* = v;
    }

    pub fn speed(pokemon: *const Pokemon) u8 {
        return pokemon.statPtr(u8, "speed").*;
    }

    pub fn setSpeed(pokemon: *const Pokemon, v: u8) void {
        pokemon.statPtr(u8, "speed").* = v;
    }

    pub fn spAttack(pokemon: *const Pokemon) u8 {
        return pokemon.statPtr(u8, "sp_attack").*;
    }

    pub fn setSpAttack(pokemon: *const Pokemon, v: u8) void {
        pokemon.statPtr(u8, "sp_attack").* = v;
    }

    pub fn spDefense(pokemon: *const Pokemon) u8 {
        return pokemon.statPtr(u8, "sp_defense").*;
    }

    pub fn setSpDefense(pokemon: *const Pokemon, v: u8) void {
        pokemon.statPtr(u8, "sp_defense").* = v;
    }

    pub fn totalStats(pokemon: *const Pokemon) u16 {
        const gen = pokemons.game.version.gen();
        var total =
            pokemon.hp().* +
            pokemon.attack().* +
            pokemon.defense().* +
            pokemon.speed().* +
            pokemon.spAttack().*;

        if (gen != 1)
            total += pokemon.spDefense().*;

        return total;
    }

    fn statPtr(pokemon: *const Pokemon, comptime field: []const u8) *u8 {
        return switch (pokemons.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => pokemon.uncheckedStatPtr(gen3, field),
            4 => pokemon.uncheckedStatPtr(gen4, field),
            5 => pokemon.uncheckedStatPtr(gen5, field),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
        };
    }

    fn uncheckedStatPtr(pokemon: *const Pokemon, comptime gen: Namespace, comptime field: []const u8) *u8 {
        const base = @ptrCast(*gen.BasePokemon, pokemon.base);
        switch (gen) {
            gen3, gen4, gen5 => {
                return &@field(base.stats, field);
            },
            else => @compileError("Gen not supported!"),
        }
    }
};

pub const Pokemons = extern struct {
    game: *const BaseGame,

    pub fn at(pokemons: *const Pokemons, id: u16) !Pokemon {
        return switch (pokemons.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => try pokemons.uncheckedAt(gen3, id),
            4 => try pokemons.uncheckedAt(gen4, id),
            5 => try pokemons.uncheckedAt(gen5, id),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
        };
    }

    pub fn uncheckedAt(pokemons: *const Pokemons, comptime gen: Namespace, type, id: u16) !Pokemon {
        const game = @fieldParentPtr(gen.Game, "base", pokemons.game);
        switch (gen) {
            gen3 => {
                const level_up_moves = blk: {
                    const start = blk: {
                        const res = generic.at(game.level_up_learnset_pointers, index) catch return error.InvalidOffset;
                        break :blk math.sub(usize, res.get(), 0x8000000) catch return error.InvalidOffset;
                    };

                    const end = end_blk: {
                        var i: usize = start;
                        while (true) : (i += @sizeOf(LevelUpMove)) {
                            const a = generic.at(game.data, i) catch return error.InvalidOffset;
                            const b = generic.at(game.data, i + 1) catch return error.InvalidOffset;
                            if (a == 0xFF and b == 0xFF)
                                break;
                        }

                        break :end_blk i;
                    };

                    break :blk ([]LevelUpMove)(game.data[start..end]);
                };

                return Pokemon{
                    .base = @ptrCast(*Hidden, &game.base_stats[id]),
                    .learnset = @ptrCast(*Hidden, &game.tm_hm_learnset[id]),
                    .level_up_moves_len = level_up_moves.len,
                    .level_up_moves = @ptrCast([*]Hidden, level_up_moves.ptr),
                };
            },
            gen4, gen5 => {
                const base_pokemon = try getFileAsType(BasePokemon, game.base_stats, index);
                const level_up_moves = blk: {
                    var tmp = game.level_up_moves[index].data;
                    const res = ([]LevelUpMove)(tmp[0 .. tmp.len - (tmp.len % @sizeOf(LevelUpMove))]);

                    // Even though each level up move have it's own file, level up moves still
                    // end with 0xFFFF.
                    for (res) |level_up_move, i| {
                        const bytes = utils.toBytes(@typeOf(level_up_move), level_up_move);
                        if (std.mem.eql(u8, bytes, []u8{ 0xFF, 0xFF }))
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
            },
            else => @compileError("Gen not supported!"),
        }
    }

    pub fn len(pokemons: *const Pokemons) u16 {
        return switch (pokemons.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => pokemons.uncheckedLen(gen3),
            4 => pokemons.uncheckedLen(gen4),
            5 => pokemons.uncheckedLen(gen5),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
        };
    }

    pub fn uncheckedLen(pokemons: *const Pokemons, comptime gen: Namespace) usize {
        const game = @fieldParentPtr(gen.Game, "base", pokemons.game);
        switch (gen) {
            gen3 => {
                var min = game.tm_hm_learnset.len;
                min = math.min(min, game.base_stats.len);
                min = math.min(min, game.evolution_table.len);
                return math.min(min, game.level_up_learnset_pointers.len);
            },
            gen4, gen5 => {
                var min = math.min(min, game.base_stats.len);
                return math.min(min, game.level_up_moves.len);
            },
            else => @compileError("Gen not supported!"),
        }
    }
};

pub const PartyMember = extern struct {
    game: *const BaseGame,
    base: *Hidden,
    item_ptr: ?*Hidden,
    moves_ptr: ?[*]Hidden,
};

pub const Party = extern struct {
    trainer: *const Trainer,

    pub fn at(party: *const Party, index: u3) !PartyMember {
        return switch (party.trainer.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => try party.uncheckedAt(gen3, index),
            4 => @panic("TODO: Gen4"),
            5 => @panic("TODO: Gen5"),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
        };
    }

    pub fn uncheckedAt(party: *const Party, comptime gen: Namespace, index: u3) !PartyMember {
        const trainer = @ptrCast(*gen.Trainer, party.trainer);
        switch (gen) {
            gen3 => {
                const trainer = @ptrCast(*gen3.Trainer, party.trainer.base);
                const member_size = party.memberSize();
                const party_ptr = @ptrCast([*]u8, trainer.party_ptr);
                const party_data = party_ptr[0..trainer.party_size * member_size];
                const member_data = party_data[id * member_size..][0..member_size];
                var off = 0;

                const base = @ptrCast(*Hidden, &member_data[off]);
                off += @sizeOf(gen3.BasePartyMember);

                const item = blk: {
                    const has_item = trainer.party_type & gen3.BasePartyMember.has_item != 0;
                    if (has_item) {
                        const end = off + @sizeOf(u16);
                        defer off = end;
                        break :blk @ptrCast(*Hidden, &member_data[off..end][0]);
                    }

                    break :blk null;
                };

                const moves = blk: {
                    const has_item = trainer.party_type & gen3.BasePartyMember.has_moves != 0;
                    if (has_item) {
                        const end = off + @sizeOf([4]u16);
                        defer off = end;
                        break :blk @ptrCast([*]Hidden, member_data[off..end].ptr);
                    }

                    break :blk null;
                };

                return PartyMember{
                    .game = party.trainer.game,
                    .base = base,
                    .item_ptr = item,
                    .moves_ptr = moves,
                };
            },
            else => @compileError("Gen not supported!"),
        }
    }

    pub fn len(party: *const Party) u3 {
        const game = party.trainer.game;
        return switch (game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => party.uncheckedLen(gen3),
            4 => party.uncheckedLen(gen4),
            5 => party.uncheckedLen(gen5),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
        };
    }

    pub fn uncheckedLen(party: *const Party, comptime gen: Namespace) u3 {
        const trainer = @ptrCast(*gen.Trainer, party.trainer);

        switch (gen) {
            gen3, gen4, gen5 => return u3(trainer.party_size),
            else => @compileError("Gen not supported!"),
        }
    }

    fn memberSize(party: *const Party) usize {
        switch (party.trainer.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => party.uncheckedMemberSize(gen3),
            4 => party.uncheckedMemberSize(gen4),
            5 => party.uncheckedMemberSize(gen5),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
        }
    }

    fn uncheckedMemberSize(party: *const Party, comptime gen: Namespace) usize {
        const trainer = @ptrCast(*gen.Trainer, party.trainer);

        switch (gen) {
            gen3 => {
                // Party members are either padded with u16, or have an held item of type u16.
                // We therefore just always add @sizeOf(u16).
                var res = @sizeOf(gen.BasePartyMember) + @sizeOf(u16);
                if (trainer.party_type & gen.BasePartyMember.has_moves != 0)
                    res += @sizeOf([4]u16);

                return res;
            },
            gen4, gen5 => {
                var res = @sizeOf(gen.BasePartyMember);
                if (trainer.party_type & gen.BasePartyMember.has_item != 0)
                    res += @sizeOf(u16);
                if (trainer.party_type & gen.BasePartyMember.has_moves != 0)
                    res += @sizeOf([4]u16);

                // In HG/SS/Plat party members are padded with two extra bytes.
                res += switch (game.version) {
                    Version.HeartGold,
                    Version.SoulSilver,
                    Version.Platinum => usize(2),
                    else => usize(0),
                };

                return res;
            },
            else => @compileError("Gen not supported!"),
        }
    }
};

pub const Trainer = extern struct {
    game: *const BaseGame,

    id: u16,
    base: *Hidden,
    party_ptr: [*]Hidden,

    pub fn party(trainer: *const Trainer) Party {
        return Party{ .trainer = trainer };
    }
};

pub const Trainers = extern struct {
    game: *const BaseGame,

    pub fn at(trainers: *const Trainers, id: u16) !Trainer {
        return switch (trainers.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => try trainers.uncheckedAt(gen3, id),
            4 => @panic("TODO: Gen4"),
            5 => @panic("TODO: Gen5"),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
        };
    }

    pub fn uncheckedAt(pokemons: *const Pokemons, comptime gen: Namespace, id: u16) !Trainer {
        const game = @fieldParentPtr(gen.Game, "base", pokemons.game);

        switch (gen) {
            gen3 => {
                const trainer = &game.trainers[id];
                var res = Trainer{
                    .id = id,
                    .game = &game.base,
                    .base = @ptrCast(*Hidden, trainer),
                    .party = undefined,
                };

                const party = blk: {
                    const start = math.sub(usize, trainer.party_offset.get(), 0x8000000) catch return error.InvalidOffset;
                    const end = start + trainer.party_size * res.party().uncheckedMemberSize(gen);
                    break :blk generic.slice(game.data, start, end) catch return error.InvalidOffset;
                };
                res.party = @ptrCast([*]Hidden, party.ptr);

                return res;
            },
            else => @compileError("Gen not supported!"),
        }
    }

    pub fn len(pokemons: *const Pokemons) u16 {
        return switch (pokemons.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => pokemons.uncheckedLen(gen3),
            4 =>  @panic("TODO: Gen4"),
            5 => @panic("TODO: Gen5"),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
        };
    }

    pub fn uncheckedLen(pokemons: *const Pokemons, comptime gen: Namespace) usize {
        const game = @fieldParentPtr(gen.Game, "base", pokemons.game);

        switch (gen) {
            gen3 => return game.trainers.len,
            else => @compileError("Gen not supported!"),
        }
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
            const alloced_game = try allocator.construct(game);

            return Game{
                .base = &alloced_game.base,
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
                const alloced_game = try allocator.construct(game);
                return Game{
                    .base = &alloced_game.base,
                    .allocator = @ptrCast(*Hidden, allocator),
                    .other = @ptrCast(*Hidden, nds_rom),
                };
            } else |e1| if (gen5.Game.fromRom(nds_rom)) |game| {
                const alloced_game = try allocator.construct(game);
                return Game{
                    .base = &alloced_game.base,
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
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => {
                const g = @fieldParentPtr(gen3.Game, "base", game.base);
                var file_stream = io.FileOutStream.init(file);
                try g.writeToStream(&file_stream.stream);
            },
            4, 5 => {
                const nds_rom = @ptrCast(*Hidden, ??game.other);
                try nds_rom.writeToFile(file, allocator);
            },
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
        }
    }

    pub fn deinit(game: *Game) void {
        const allocator = @ptrCast(*mem.Allocator, game.allocator);
        defer game.* = undefined;

        switch (game.base.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => {
                const g = @fieldParentPtr(gen3.Game, "base", game.base);

                debug.assert(game.other == null);
                g.deinit();
                allocator.free(g);
            },
            4 => {
                const g = @fieldParentPtr(gen4.Game, "base", game.base);
                const nds_rom = @ptrCast(*Hidden, ??game.other);

                nds_rom.deinit();
                allocator.free(nds_rom);
                allocator.free(g);
            },
            5 => {
                const g = @fieldParentPtr(gen5.Game, "base", game.base);
                const nds_rom = @ptrCast(*Hidden, ??game.other);

                nds_rom.deinit();
                allocator.free(nds_rom);
                allocator.free(g);
            },
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
        }
    }

    pub fn pokemons(game: *const Game) Pokemons {
        return Pokemons{ .game = game.base };
    }

    pub fn trainers(game: *const Game) Trainers {
        return Trainers{ .game = game.base };
    }
};

fn getFileAsType(comptime T: type, files: []const *nds.fs.Narc.File, index: usize) !*T {
    const data = generic.widenTrim(files[index].data, T);
    return generic.at(data, 0) catch error.FileToSmall;
}
