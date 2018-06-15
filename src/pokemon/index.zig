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
const io = std.io;
const mem = std.mem;

const Little = little.Little;
const Namespace = @typeOf(std);

const u9 = @IntType(false, 9);
const u10 = @IntType(false, 10);

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

    // Dispatch a generic function with signature fn(comptime Namespace, @typeOf(context)) Result
    // based on the versions runtime gen.
    pub fn dispatch(
        version: Version,
        comptime Result: type,
        context: var,
        comptime func: var
    ) Result {
        const offset = 3;
        const g = version.gen();
        const gen_table = []Namespace{
            gen3,
            gen4,
            gen5,
        };

        inline for (gen_table) |namespace, i| {
            if (i + offset == g)
                return func(namespace, context);
        }

        unreachable;
    }

    pub fn hasPhysicalSpecialSplit(gen: Gen) bool {
        return @TagType(Gen)(gen) > 3;
    }

    // TODO: Can we find all legendaries in a game without having these hardcoded tables?
    //       I mean, all legendaries have over 600 total stats, and all appear as static pokemons
    //       somewhere. Most of them also have custom music. There are lots of stuff to look for
    //       and I think we can make it work.
    pub fn legendaries(version: Version) []const u16 {
        return version.dispatch([]const u16, void{}, legendariesHelper);
    }

    pub fn legendariesHelper(comptime g: Namespace, c: void) []const u16 {
        return switch (g) {
            gen3 =>[]u16{
                0x090, 0x091, 0x092, // Articuno, Zapdos, Moltres
                0x096, 0x097, 0x0F3, // Mewtwo, Mew, Raikou
                0x0F4, 0x0F5, 0x0F9, // Entei, Suicune, Lugia
                0x0FA, 0x0FB, 0x191, // Ho-Oh, Celebi, Regirock
                0x192, 0x193, 0x194, // Regice, Registeel, Kyogre
                0x195, 0x196, 0x197, // Groudon, Rayquaza, Latias
                0x198, 0x199, 0x19A, // Latios, Jirachi, Deoxys
            },
            gen4 => common.legendaries[0..32],
            gen5 => common.legendaries,
            else => unreachable,
        };
    }
};

const Hidden = @OpaqueType();

pub const Type = extern enum {
    Invalid,
    Normal,
    Fighting,
    Flying,
    Poison,
    Ground,
    Rock,
    Bug,
    Ghost,
    Steel,
    Fire,
    Water,
    Grass,
    Electric,
    Psychic,
    Ice,
    Dragon,
    Dark,
    Fairy,

    pub fn fromGame(version: Version, id: u8) Type {
        return version.dispatch(Type, id, fromGameHelper);
    }

    fn fromGameHelper(comptime gen: Namespace, id: u8) Type {
        return toOther(version, Type, @bitCast(gen.Type, @TagType(gen.Type)(id))) ?? Type.Invalid;
    }

    pub fn toGame(version: Version, t: Type) u8 {
        // TODO: What do we do when the type does not exist in the game we are hacking.
        //       For now, we just output 0xAA which is highly likely to not be a type in the game,
        //       so the game will probably crash.
        //       Should we assert here instead? Throw an error? What if the game have hacked in
        //       types? Maybe these functions are only for convinience when hacking mainline games
        //       and are useless on hacked games.
        return version.dispatch(Type, t, toGameHelper);
    }

    fn toGameHelper(comptime gen: Namespace, t: Type) u8 {
        return toOther(version, gen.Type, t) ?? 0xAA;
    }

    fn toOther(version: Version, comptime Out: type, in: var) ?Out {
        const In = @typeOf(in);
        const in_tags = @typeInfo(@typeOf(in)).Enum.fields;
        const out_tags = @typeInfo(Out).Enum.fields;
        inline for (in_tags) |in_tag| {
            inline for (out_tags) |out_tag| {
                if (!mem.eql(u8, in_tag.name, out_tag.name))
                    continue;

                if (out_tag.value == @TagType(In)(in))
                    return (Out)(out_tag.value);
            }
        }

        return null;
    }
};

pub const LevelUpMove = extern struct {
    game: *const BaseGame,
    data: *Hidden,

    pub fn level(move: *const LevelUpMove) u8 {
        return move.game.version.dispatch(u8, move, levelHelper);
    }

    fn levelHelper(comptime gen: Namespace, lvl_up_move: *const LevelUpMove) u8 {
        const lvl_ptr = &@ptrCast(*gen.LevelUpMove, lvl_up_move.data).level;
        return if (gen == gen5) u8(lvl_ptr.get()) else lvl_ptr.*;
    }

    pub fn setLevel(move: *const LevelUpMove, lvl: u8) void {
        return move.game.version.dispatch(u8, SetLvlC{ .move = move, .lvl = lvl, }, setLevelHelper);
    }

    const SetLvlC = struct { move: *const LevelUpMove, lvl: u8 };
    fn setLevelHelper(comptime gen: Namespace, c: var) void {
        setLevelHelperHelper(
            &@ptrCast(*gen.LevelUpMove, c.move.data).level,
            if (gen == gen5) toLittle(u16(c.lvl)) else u7(c.lvl)
        );
    }

    fn setLevelHelperHelper(ptr: var, lvl: var) u8 {
        ptr.* = lvl;
    }

    pub fn moveId(lvl_up_move: *const LevelUpMove) u16 {
        return lvl_up_move.getSetMoveId(null);
    }

    pub fn setMoveId(lvl_up_move: *const LevelUpMove, id: u16) void {
        _ = lvl_up_move.getSetMoveId(id);
    }

    fn getSetLvl(lvl_up_move: *const LevelUpMove, setter: ?u8) u8 {
        return switch (lvl_up_move.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3, 4 => {
                const lvl_ptr = switch (lvl_up_move.game.version.gen()) {
                    3 => lvl_up_move.dataFieldPtr(gen3, *align(1:9:16) u7, [][]const u8{ "level" }),
                    4 => lvl_up_move.dataFieldPtr(gen4, *align(1:9:16) u7, [][]const u8{ "level" }),
                    else => unreachable,
                };
                if (setter) |v|
                    lvl_ptr.* = u7(v);

                return u8(lvl_ptr.*);
            },
            5 => {
                const lvl_ptr = lvl_up_move.dataFieldPtr(gen5, *Little(u16), [][]const u8{ "level" });
                if (setter) |v|
                    lvl_ptr.set(v);

                return u8(lvl_ptr.get());
            },
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    fn getSetMoveId(lvl_up_move: *const LevelUpMove, setter: ?u16) u16 {
        return switch (lvl_up_move.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3, 4 => {
                const move_id = switch (lvl_up_move.game.version.gen()) {
                    3 => lvl_up_move.dataFieldPtr(gen3, *align(1:0:9) u9, [][]const u8{ "move_id" }),
                    4 => lvl_up_move.dataFieldPtr(gen4, *align(1:0:9) u9, [][]const u8{ "move_id" }),
                    else => unreachable,
                };
                if (setter) |v|
                    move_id.* = u9(v);

                return move_id.*;
            },
            5 => {
                const move_id = lvl_up_move.dataFieldPtr(gen5, *Little(u16), [][]const u8{ "move_id" });
                if (setter) |v|
                    move_id.set(v);

                return move_id.get();
            },
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    fn dataFieldPtr(lvl_up_move: *const LevelUpMove, comptime gen: Namespace, comptime T: type, comptime fields: []const []const u8) T {
        const base = @ptrCast(*gen.LevelUpMove, lvl_up_move.data);
        return fieldPtr(base, T, fields);
    }
};

pub const LevelUpMoves = extern struct {
    game: *const BaseGame,
    data_len: usize,
    data: *Hidden,

    pub fn at(moves: *const LevelUpMoves, index: usize) LevelUpMove {
        return switch (moves.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => moves.atHelper(gen3, index),
            4 => moves.atHelper(gen4, index),
            5 => moves.atHelper(gen5, index),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    fn atHelper(moves: *const LevelUpMoves, comptime gen: Namespace, index: usize) LevelUpMove {
        const game = @fieldParentPtr(gen.Game, "base", moves.game);
        const lvl_up_moves = @ptrCast([*]gen.LevelUpMove, moves.data)[0..moves.data_len];
        return LevelUpMove{
            .game = moves.game,
            .data = @ptrCast(*Hidden, &lvl_up_moves[index]),
        };
    }

    pub fn len(moves: *const LevelUpMoves) usize {
        return moves.data_len;
    }

    pub fn iterator(moves: *const LevelUpMoves) Iter {
        return Iter.init(moves);
    }

    const Iter = Iterator(LevelUpMoves, LevelUpMove);
};

pub const TmLearnset = Learnset(false);
pub const HmLearnset = Learnset(true);

pub fn Learnset(comptime is_hms: bool) type {
    return extern struct {
        const Self = this;
        game: *const BaseGame,
        data: *Hidden,

        pub fn at(learnset: *const Self, index: usize) bool {
            return switch (learnset.game.version.gen()) {
                1 => @panic("TODO: Gen1"),
                2 => @panic("TODO: Gen2"),
                3 => learnset.atHelper(gen3, index, null),
                4 => learnset.atHelper(gen4, index, null),
                5 => learnset.atHelper(gen5, index, null),
                6 => @panic("TODO: Gen6"),
                7 => @panic("TODO: Gen7"),
                else => unreachable,
            };
        }

        pub fn atSet(learnset: *const Self, index: usize, value: bool) void {
            switch (learnset.game.version.gen()) {
                1 => @panic("TODO: Gen1"),
                2 => @panic("TODO: Gen2"),
                3 => _ = learnset.atHelper(gen3, index, value),
                4 => _ = learnset.atHelper(gen4, index, value),
                5 => _ = learnset.atHelper(gen5, index, value),
                6 => @panic("TODO: Gen6"),
                7 => @panic("TODO: Gen7"),
                else => unreachable,
            }
        }

        fn atHelper(learnset: *const Self, comptime gen: Namespace, index: usize, setter: ?bool) bool {
            const game = @fieldParentPtr(gen.Game, "base", learnset.game);
            const T = if (gen == gen3) u64 else u128;
            const Log2T = math.Log2Int(T);
            const l = @ptrCast(*Little(T), learnset.data);
            const i = switch (gen) {
                gen3, gen4 => blk: {
                    if (is_hms) {
                        debug.assert(index < game.hms.len);
                        break :blk index + game.tms.len;
                    }

                    debug.assert(index < game.tms.len);
                    break :blk index;
                },
                gen5 => blk: {
                    if (is_hms) {
                        debug.assert(index < game.hms.len);
                        break :blk index + game.tms1.len;
                    }

                    debug.assert(index < game.tms1.len + game.tms2.len);
                    break :blk if (index < game.tms1.len) index else index + game.hms.len;
                },
                else => @compileError("Gen not supported!"),
            };

            if (setter) |b|
                l.set(bits.set(T, l.get(), Log2T(i), b));

            return bits.get(T, l.get(), Log2T(i));
        }

        pub fn len(learnset: *const Self) usize {
            return switch (learnset.game.version.gen()) {
                1 => @panic("TODO: Gen1"),
                2 => @panic("TODO: Gen2"),
                3 => learnset.lenHelper(gen3),
                4 => learnset.lenHelper(gen4),
                5 => learnset.lenHelper(gen5),
                6 => @panic("TODO: Gen6"),
                7 => @panic("TODO: Gen7"),
                else => unreachable,
            };
        }

        fn lenHelper(learnset: *const Self, comptime gen: Namespace) usize {
            const game = @fieldParentPtr(gen.Game, "base", learnset.game);
            return switch (gen) {
                gen3, gen4 => game.tms.len,
                gen5 => game.tms1.len + game.tms2.len,
                else => @compileError("Gen not supported!"),
            };
        }

        pub fn iterator(learnset: *const Self) Iter {
            return Iter.init(learnset);
        }

        const Iter = Iterator(Self, bool);
    };
}

pub const Pokemon = extern struct {
    game: *const BaseGame,

    base: *Hidden,
    learnset: *Hidden,
    level_up_moves_len: usize,
    level_up_moves: *Hidden,

    pub fn hp(pokemon: *const Pokemon) *u8 {
        return pokemon.baseFieldPtr(*u8, [][]const u8{ "stats", "hp" });
    }

    pub fn attack(pokemon: *const Pokemon) *u8 {
        return pokemon.baseFieldPtr(*u8, [][]const u8{ "stats", "attack" });
    }

    pub fn defense(pokemon: *const Pokemon) *u8 {
        return pokemon.baseFieldPtr(*u8, [][]const u8{ "stats", "defense" });
    }

    pub fn speed(pokemon: *const Pokemon) *u8 {
        return pokemon.baseFieldPtr(*u8, [][]const u8{ "stats", "speed" });
    }

    pub fn spAttack(pokemon: *const Pokemon) *u8 {
        return pokemon.baseFieldPtr(*u8, [][]const u8{ "stats", "sp_attack" });
    }

    pub fn spDefense(pokemon: *const Pokemon) *u8 {
        return pokemon.baseFieldPtr(*u8, [][]const u8{ "stats", "sp_defense" });
    }

    pub fn levelUpMoves(pokemon: *const Pokemon) LevelUpMoves {
        return LevelUpMoves{
            .game = pokemon.game,
            .data_len = pokemon.level_up_moves_len,
            .data = pokemon.level_up_moves,
        };
    }

    pub fn totalStats(pokemon: *const Pokemon) u16 {
        const gen = pokemon.game.version.gen();
        var total: u16 = pokemon.hp().*;
        total += pokemon.attack().*;
        total += pokemon.defense().*;
        total += pokemon.speed().*;
        total += pokemon.spAttack().*;

        if (gen != 1)
            total += pokemon.spDefense().*;

        return total;
    }

    pub fn types(pokemon: *const Pokemon) *[2]u8 {
        return switch (pokemon.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => {
                const base = @ptrCast(*gen3.BasePokemon, pokemon.base);
                return @ptrCast(*[2]u8, fieldPtr(base, *[2]gen3.Type, [][]const u8{ "types" }));
            },
            4 => {
                const base = @ptrCast(*gen4.BasePokemon, pokemon.base);
                return @ptrCast(*[2]u8, fieldPtr(base, *[2]gen4.Type, [][]const u8{ "types" }));
            },
            5 => {
                const base = @ptrCast(*gen5.BasePokemon, pokemon.base);
                return @ptrCast(*[2]u8, fieldPtr(base, *[2]gen5.Type, [][]const u8{ "types" }));
            },
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    pub fn tmLearnset(pokemon: *const Pokemon) TmLearnset {
        return TmLearnset{
            .game = pokemon.game,
            .data = pokemon.learnset,
        };
    }

    pub fn hmLearnset(pokemon: *const Pokemon) HmLearnset {
        return HmLearnset{
            .game = pokemon.game,
            .data = pokemon.learnset,
        };
    }

    fn baseFieldPtr(pokemon: *const Pokemon, comptime T: type, comptime fields: []const []const u8) T {
        return switch (pokemon.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => {
                const base = @ptrCast(*gen3.BasePokemon, pokemon.base);
                return fieldPtr(base, T, fields);
            },
            4 => {
                const base = @ptrCast(*gen4.BasePokemon, pokemon.base);
                return fieldPtr(base, T, fields);
            },
            5 => {
                const base = @ptrCast(*gen5.BasePokemon, pokemon.base);
                return fieldPtr(base, T, fields);
            },
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }
};

pub const Pokemons = extern struct {
    game: *const BaseGame,

    pub fn at(pokemons: *const Pokemons, id: usize) !Pokemon {
        return switch (pokemons.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => try pokemons.atHelper(gen3, id),
            4 => try pokemons.atHelper(gen4, id),
            5 => try pokemons.atHelper(gen5, id),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    fn atHelper(pokemons: *const Pokemons, comptime gen: Namespace, index: usize) !Pokemon {
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
                        while (true) : (i += @sizeOf(gen.LevelUpMove)) {
                            const a = generic.at(game.data, i) catch return error.InvalidOffset;
                            const b = generic.at(game.data, i + 1) catch return error.InvalidOffset;
                            if (a.* == 0xFF and b.* == 0xFF)
                                break;
                        }

                        break :end_blk i;
                    };

                    break :blk ([]gen.LevelUpMove)(game.data[start..end]);
                };

                return Pokemon{
                    .game = pokemons.game,
                    .base = @ptrCast(*Hidden, &game.base_stats[index]),
                    .learnset = @ptrCast(*Hidden, &game.tm_hm_learnset[index]),
                    .level_up_moves_len = level_up_moves.len,
                    .level_up_moves = @ptrCast(*Hidden, level_up_moves.ptr),
                };
            },
            gen4, gen5 => {
                const base_pokemon = try getFileAsType(gen.BasePokemon, game.base_stats, index);
                const level_up_moves = blk: {
                    var tmp = game.level_up_moves[index].data;
                    const res = ([]gen.LevelUpMove)(tmp[0 .. tmp.len - (tmp.len % @sizeOf(gen.LevelUpMove))]);

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
                    .game = pokemons.game,
                    .base = @ptrCast(*Hidden, base_pokemon),
                    .learnset = @ptrCast(*Hidden, &base_pokemon.tm_hm_learnset),
                    .level_up_moves_len = level_up_moves.len,
                    .level_up_moves = @ptrCast(*Hidden, level_up_moves.ptr),
                };
            },
            else => @compileError("Gen not supported!"),
        }
    }

    pub fn len(pokemons: *const Pokemons) usize {
        return switch (pokemons.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => pokemons.lenHelper(gen3),
            4 => pokemons.lenHelper(gen4),
            5 => pokemons.lenHelper(gen5),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    fn lenHelper(pokemons: *const Pokemons, comptime gen: Namespace) usize {
        const game = @fieldParentPtr(gen.Game, "base", pokemons.game);
        switch (gen) {
            gen3 => {
                var min = game.tm_hm_learnset.len;
                min = math.min(min, game.base_stats.len);
                min = math.min(min, game.evolution_table.len);
                min = math.min(min, game.level_up_learnset_pointers.len);
                return u16(min);
            },
            gen4, gen5 => {
                var min = game.base_stats.len;
                min = math.min(min, game.level_up_moves.len);
                return u16(min);
            },
            else => @compileError("Gen not supported!"),
        }
    }

    pub fn iterator(pokemons: *const Pokemons) Iter {
        return Iter.init(pokemons);
    }

    const Iter = ErrIterator(Pokemons, Pokemon);
};

pub const PartyMember = extern struct {
    game: *const BaseGame,
    base: *Hidden,
    item_ptr: ?*Hidden,
    moves_ptr: ?*Hidden,

    pub fn species(member: *const PartyMember) u16 {
        return member.getSetSpecies(null);
    }

    pub fn setSpecies(member: *const PartyMember, v: u16) void {
        _ = member.getSetSpecies(v);
    }

    fn getSetSpecies(member: *const PartyMember, setter: ?u16) u16 {
        return switch (member.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            4 => {
                const species_ptr = member.baseFieldPtr(gen4, *align(1:0:10) u10, [][]const u8{ "species" });
                if (setter) |v|
                    species_ptr.* = u10(v);

                return species_ptr.*;
            },
            3, 5 => {
                const species_ptr = switch (member.game.version.gen()) {
                    3 => member.baseFieldPtr(gen3, *Little(u16), [][]const u8{ "species" }),
                    5 => member.baseFieldPtr(gen5, *Little(u16), [][]const u8{ "species" }),
                    else => unreachable,
                };
                if (setter) |v|
                    species_ptr.set(v);

                return species_ptr.get();
            },
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    pub fn level(member: *const PartyMember) u8 {
        return member.getSetLvl(null);
    }

    pub fn setLevel(member: *const PartyMember, lvl: u8) void {
        _ = member.getSetLvl(lvl);
    }

    fn getSetLvl(member: *const PartyMember, setter: ?u8) u8 {
        return switch (member.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3, 4 => {
                @breakpoint();
                const lvl_ptr = switch (member.game.version.gen()) {
                    3 => member.baseFieldPtr(gen3, *Little(u16), [][]const u8{ "level" }),
                    4 => member.baseFieldPtr(gen4, *Little(u16), [][]const u8{ "level" }),
                    else => unreachable,
                };
                if (setter) |v|
                    lvl_ptr.set(v);

                const lvl = lvl_ptr.get();
                return u8(lvl);
            },
            5 => {
                const lvl_ptr = member.baseFieldPtr(gen5, *u8, [][]const u8{ "level" });
                if (setter) |v|
                    lvl_ptr.* = v;

                return lvl_ptr.*;
            },
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    pub fn item(member: *const PartyMember) !u16 {
        return member.getSetItem(null) ?? error.HasNoItem;
    }

    pub fn setItem(member: *const PartyMember, v: u16) !void {
        _ = member.getSetItem(v) ?? return error.HasNoItem;
    }

    fn getSetItem(member: *const PartyMember, setter: ?u16) ?u16 {
        switch (member.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3, 4, 5 => {
                const item_ptr = @ptrCast(?*Little(u16), member.item_ptr) ?? return null;
                if (setter) |v|
                    item_ptr.set(v);

                return item_ptr.get();
            },
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        }
    }

    pub fn move(member: *const PartyMember, i: u2) !u16 {
        return member.getSetMove(i, null) ?? error.HasNoMoves;
    }

    pub fn setMove(member: *const PartyMember, i: u2, v: u16) !void {
        _ = member.getSetMove(i, v) ?? return error.HasNoMoves;
    }

    fn getSetMove(member: *const PartyMember, i: u2, setter: ?u16) ?u16 {
        return switch (member.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3, 4, 5 => {
                const moves = @ptrCast(?*[4]Little(u16), member.moves_ptr) ?? return null;
                if (setter) |v|
                    moves[i].set(v);

                return moves[i].get();
            },
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    fn baseFieldPtr(member: *const PartyMember, comptime gen: Namespace, comptime T: type, comptime fields: []const []const u8) T {
        const base = @ptrCast(*gen.PartyMember, member.base);
        return fieldPtr(base, T, fields);
    }
};

pub const Party = extern struct {
    trainer: *const Trainer,

    pub fn at(party: *const Party, index: usize) PartyMember {
        return switch (party.trainer.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => party.atHelper(gen3, index),
            4 => @panic("TODO: Gen4"),
            5 => @panic("TODO: Gen5"),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    pub fn atHelper(party: *const Party, comptime gen: Namespace, index: usize) PartyMember {
        const trainer = @ptrCast(*gen.Trainer, party.trainer.base);
        @breakpoint();
        switch (gen) {
            gen3 => {
                const member_size = party.memberSize();
                const party_ptr = @ptrCast([*]u8, party.trainer.party_ptr);
                const party_data = party_ptr[0..trainer.party_size.get() * member_size];
                const member_data = party_data[index * member_size..][0..member_size];
                var off: usize = 0;

                const base = @ptrCast(*Hidden, &member_data[off]);
                off += @sizeOf(gen.PartyMember);

                const item = blk: {
                    const has_item = trainer.party_type & gen.PartyMember.has_item != 0;
                    if (has_item) {
                        const end = off + @sizeOf(u16);
                        defer off = end;
                        break :blk @ptrCast(*Hidden, &member_data[off..end][0]);
                    }

                    break :blk null;
                };

                const moves = blk: {
                    const has_item = trainer.party_type & gen.PartyMember.has_moves != 0;
                    if (has_item) {
                        const end = off + @sizeOf([4]u16);
                        defer off = end;
                        break :blk @ptrCast(*Hidden, member_data[off..end].ptr);
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

    pub fn len(party: *const Party) usize {
        return switch (party.trainer.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => party.lenHelper(gen3),
            4 => party.lenHelper(gen4),
            5 => party.lenHelper(gen5),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    pub fn lenHelper(party: *const Party, comptime gen: Namespace) usize {
        const trainer = @ptrCast(*gen.Trainer, party.trainer.base);
        return switch (gen) {
            gen3 => trainer.party_size.get(),
            gen4, gen5 => trainer.party_size,
            else => @compileError("Gen not supported!"),
        };
    }

    fn memberSize(party: *const Party) usize {
        return switch (party.trainer.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => party.memberSizeHelper(gen3),
            4 => party.memberSizeHelper(gen4),
            5 => party.memberSizeHelper(gen5),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    fn memberSizeHelper(party: *const Party, comptime gen: Namespace) usize {
        const trainer = @ptrCast(*gen.Trainer, party.trainer.base);
        var res: usize = @sizeOf(gen.PartyMember);
        if (gen == gen3 or
            trainer.party_type & gen.PartyMember.has_item != 0) {
            res += @sizeOf(u16);
        }
        if (trainer.party_type & gen.PartyMember.has_moves != 0)
            res += @sizeOf([4]u16);

        // In HG/SS/Plat party members are padded with two extra bytes.
        res += switch (party.trainer.game.version) {
            Version.HeartGold,
            Version.SoulSilver,
            Version.Platinum => usize(2),
            else => usize(0),
        };

        return res;
    }

    pub fn iterator(party: *const Party) Iter {
        return Iter.init(party);
    }

    const Iter = Iterator(Party, PartyMember);
};

pub const Trainer = extern struct {
    game: *const BaseGame,

    base: *Hidden,
    party_ptr: *Hidden,

    pub fn party(trainer: *const Trainer) Party {
        return Party{ .trainer = trainer };
    }
};

pub const Trainers = extern struct {
    game: *const BaseGame,

    pub fn at(trainers: *const Trainers, id: usize) !Trainer {
        return switch (trainers.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => try trainers.atHelper(gen3, id),
            4 => @panic("TODO: Gen4"),
            5 => @panic("TODO: Gen5"),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    pub fn atHelper(trainers: *const Trainers, comptime gen: Namespace, index: usize) !Trainer {
        const game = @fieldParentPtr(gen.Game, "base", trainers.game);
        switch (gen) {
            gen3 => {
                const trainer = &game.trainers[index];
                var res = Trainer{
                    .game = &game.base,
                    .base = @ptrCast(*Hidden, trainer),
                    .party_ptr = undefined,
                };

                const party = blk: {
                    const start = math.sub(usize, trainer.party_offset.get(), 0x8000000) catch return error.InvalidOffset;
                    const end = start + trainer.party_size.get() * res.party().memberSizeHelper(gen);
                    break :blk generic.slice(game.data, start, end) catch return error.InvalidOffset;
                };
                res.party_ptr = @ptrCast(*Hidden, party.ptr);

                return res;
            },
            else => @compileError("Gen not supported!"),
        }
    }

    pub fn len(trainers: *const Trainers) usize {
        return switch (trainers.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => trainers.lenHelper(gen3),
            4 => @panic("TODO: Gen4"),
            5 => @panic("TODO: Gen5"),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    pub fn lenHelper(trainers: *const Trainers, comptime gen: Namespace) usize {
        const game = @fieldParentPtr(gen.Game, "base", trainers.game);
        switch (gen) {
            gen3 => return game.trainers.len,
            else => @compileError("Gen not supported!"),
        }
    }

    pub fn iterator(trainers: *const Trainers) Iter {
        return Iter.init(trainers);
    }

    const Iter = ErrIterator(Trainers, Trainer);
};

pub const Tms = Machines(false);
pub const Hms = Machines(true);

pub fn Machines(comptime is_hms: bool) type {
    return extern struct {
        const Self = this;

        game: *const BaseGame,

        pub fn at(machines: *const Self, index: usize) u16 {
            return switch (machines.game.version.gen()) {
                1 => @panic("TODO: Gen1"),
                2 => @panic("TODO: Gen2"),
                3 => machines.atHelper(gen3, index, null),
                4 => machines.atHelper(gen4, index, null),
                5 => machines.atHelper(gen5, index, null),
                6 => @panic("TODO: Gen6"),
                7 => @panic("TODO: Gen7"),
                else => unreachable,
            };
        }

        pub fn atSet(machines: *const Self, index: usize, value: u16) void {
            switch (machines.game.version.gen()) {
                1 => @panic("TODO: Gen1"),
                2 => @panic("TODO: Gen2"),
                3 => _ = try machines.atHelper(gen3, index, value),
                4 => _ = try machines.atHelper(gen4, index, value),
                5 => _ = try machines.atHelper(gen5, index, value),
                6 => @panic("TODO: Gen6"),
                7 => @panic("TODO: Gen7"),
                else => unreachable,
            }
        }

        fn atHelper(machines: *const Self, comptime gen: Namespace, index: usize, setter: ?u16) u16 {
            const game = @fieldParentPtr(gen.Game, "base", machines.game);
            switch (gen) {
                gen3, gen4 => {
                    const m = if (is_hms) game.tms else game.hms;

                    if (setter) |v|
                        m[index].set(v);
                    return m[index].get();
                },
                gen5 => {
                    var i: usize = index;
                    const m = blk: {
                        if (is_hms)
                            break :blk game.hms;

                        if (i < game.tms1.len)
                            break :blk game.tms1;

                        i -= game.tms1.len;
                        break :blk game.tms2;
                    };

                    if (setter) |v|
                        m[i].set(v);
                    return m[i].get();
                },
                else => @compileError("Gen not supported!"),
            }
        }

        pub fn len(machines: *const Self) usize {
            return switch (pokemons.game.version.gen()) {
                1 => @panic("TODO: Gen1"),
                2 => @panic("TODO: Gen2"),
                3 => pokemons.lenHelper(gen3),
                4 => pokemons.lenHelper(gen4),
                5 => pokemons.lenHelper(gen5),
                6 => @panic("TODO: Gen6"),
                7 => @panic("TODO: Gen7"),
                else => unreachable,
            };
        }

        fn lenHelper(machines: *const Self, comptime gen: Namespace) u16 {
            const game = @fieldParentPtr(gen.Game, "base", pokemons.game);
            switch (gen) {
                gen3, gen4 => game.tms.len,
                gen5 => return game.tms1.len + game.tms2,
                else => @compileError("Gen not supported!"),
            }
        }

        pub fn iterator(machines: *const Self) Iterator {
            return Iterator.init(machines);
        }

        const Iterator = GenerateIterator(Machines, u16);
    };
}

pub const Move = extern struct {
    game: *const BaseGame,
    data: *Hidden,

    pub fn types(move: *const Move) *[1]u8 {
        return switch (move.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => {
                const base = @ptrCast(*gen3.Move, move.data);
                return @ptrCast(*[1]u8, fieldPtr(base, *gen3.Type, [][]const u8{ "type" }));
            },
            4 => {
                const base = @ptrCast(*gen4.Move, move.data);
                return @ptrCast(*[1]u8, fieldPtr(base, *gen4.Type, [][]const u8{ "type" }));
            },
            5 => {
                const base = @ptrCast(*gen5.Move, move.data);
                return @ptrCast(*[1]u8, fieldPtr(base, *gen5.Type, [][]const u8{ "type" }));
            },
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    pub fn power(move: *const Move) *u8 {
        return move.baseFieldPtr(*u8, [][]const u8{ "power" });
    }

    pub fn pp(move: *const Move) *u8 {
        return move.baseFieldPtr(*u8, [][]const u8{ "pp" });
    }

    fn baseFieldPtr(move: *const Move, comptime T: type, comptime fields: []const []const u8) T {
        return switch (move.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => {
                const base = @ptrCast(*gen3.Move, move.data);
                return fieldPtr(base, T, fields);
            },
            4 => {
                const base = @ptrCast(*gen4.Move, move.data);
                return fieldPtr(base, T, fields);
            },
            5 => {
                const base = @ptrCast(*gen5.Move, move.data);
                return fieldPtr(base, T, fields);
            },
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }
};

pub const Moves = extern struct {
    game: *const BaseGame,

    pub fn at(moves: *const Moves, index: usize) Move {
        return switch (moves.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => moves.atHelper(gen3, index),
            4 => moves.atHelper(gen4, index),
            5 => moves.atHelper(gen5, index),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    fn atHelper(moves: *const Moves, comptime gen: Namespace, index: usize) Move {
        const game = @fieldParentPtr(gen.Game, "base", moves.game);
        const move = switch (gen) {
            gen3 => &game.moves[index],
            gen4, gen5 => game.moves[index],
            else => @compileError("Gen not supported!"),
        };

        return Move{
            .game = moves.game,
            .data = @ptrCast(*Hidden, move),
        };
    }

    pub fn len(moves: *const Moves) usize {
        return switch (moves.game.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => moves.lenHelper(gen3),
            4 => moves.lenHelper(gen4),
            5 => moves.lenHelper(gen5),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        };
    }

    fn lenHelper(moves: *const Moves, comptime gen: Namespace) usize {
        const game = @fieldParentPtr(gen.Game, "base", moves.game);
        return game.moves.len;
    }

    pub fn iterator(moves: *const Moves) Iterator {
        return Iterator.init(moves);
    }

    const Iterator = GenerateIterator(Moves, u16);
};

pub const BaseGame = extern struct {
    version: Version,
};

pub const Game = extern struct {
    base: *BaseGame,
    allocator: *mem.Allocator,
    other: ?*Hidden,

    pub fn load(file: *os.File, allocator: *mem.Allocator) !Game {
        const start = try file.getPos();
        gba_blk: {
            try file.seekTo(start);
            const game = gen3.Game.fromFile(file, allocator) catch break :gba_blk;
            const alloced_game = try allocator.construct(game);

            return Game{
                .base = &alloced_game.base,
                .allocator = allocator,
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
                    .allocator = allocator,
                    .other = @ptrCast(*Hidden, nds_rom),
                };
            } else |e1| if (gen5.Game.fromRom(nds_rom)) |game| {
                const alloced_game = try allocator.construct(game);
                return Game{
                    .base = &alloced_game.base,
                    .allocator = allocator,
                    .other = @ptrCast(*Hidden, nds_rom),
                };
            } else |e2| {
                break :nds_blk;
            }
        }

        return error.InvalidGame;
    }

    pub fn save(game: *const Game, file: *os.File) !void {
        switch (game.base.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => {
                const g = @fieldParentPtr(gen3.Game, "base", game.base);
                var file_stream = io.FileOutStream.init(file);
                try g.writeToStream(&file_stream.stream);
            },
            4, 5 => {
                const nds_rom = @ptrCast(*nds.Rom, ??game.other);
                try nds_rom.writeToFile(file, game.allocator);
            },
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        }
    }

    pub fn deinit(game: *Game) void {
        defer game.* = undefined;

        switch (game.base.version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen2"),
            3 => game.deinitHelper(gen3),
            4 => game.deinitHelper(gen4),
            5 => game.deinitHelper(gen5),
            6 => @panic("TODO: Gen6"),
            7 => @panic("TODO: Gen7"),
            else => unreachable,
        }
    }

    fn deinitHelper(game: *Game, comptime gen: Namespace) void {
        const allocator = @ptrCast(*mem.Allocator, game.allocator);
        const g = @fieldParentPtr(gen.Game, "base", game.base);
        switch (gen) {
            gen3 => {
                debug.assert(game.other == null);
                g.deinit();
                allocator.destroy(g);
            },
            gen4, gen5 => {
                const nds_rom = @ptrCast(*nds.Rom, ??game.other);
                nds_rom.deinit();
                allocator.destroy(nds_rom);
                allocator.destroy(g);
            },
            else => @compileError("Gen not supported!"),
        }
    }

    pub fn pokemons(game: *const Game) Pokemons {
        return Pokemons{ .game = game.base };
    }

    pub fn trainers(game: *const Game) Trainers {
        return Trainers{ .game = game.base };
    }

    pub fn tms(game: *const Game) Tms {
        return Tms{ .game = game.base };
    }

    pub fn hms(game: *const Game) Hms {
        return Hms{ .game = game.base };
    }

    pub fn moves(game: *const Game) Moves {
        return Moves{ .game = game.base };
    }
};

fn Iterator(comptime T: type, comptime Result: type) type {
    return struct {
        const Self = this;

        items: T,
        curr: usize,

        pub const Pair = struct {
            index: usize,
            value: Result,
        };

        pub fn init(items: *const T) Self {
            return Self{
                .items = items.*,
                .curr = 0,
            };
        }

        pub fn next(iter: *Self) ?Pair {
            if (iter.curr >= iter.items.len())
                return null;

            defer iter.curr += 1;
            return Pair{
                .index = iter.curr,
                .value = iter.items.at(iter.curr),
            };
        }
    };
}

fn ErrIterator(comptime T: type, comptime Result: type) type {
    return struct {
        const Self = this;

        items: T,
        curr: usize,

        pub const Pair = struct {
            index: usize,
            value: Result,
        };

        pub fn init(items: *const T) Self {
            return Self{
                .items = items.*,
                .curr = 0,
            };
        }

        pub fn next(iter: *Self) !?Pair {
            if (iter.curr >= iter.items.len())
                return null;

            defer iter.curr += 1;
            return Pair{
                .index = iter.curr,
                .value = try iter.items.at(iter.curr),
            };
        }

        pub fn nextValid(iter: *Self) ?Pair {
            while (true) {
                const n = iter.next() catch continue;
                return n;
            }
        }
    };
}

fn fieldPtr(s: var, comptime T: type, comptime fields: []const []const u8) T {
    var ptr = @ptrCast(*Hidden, s);
    comptime var PtrT = @typeOf(s);
    comptime var i: usize = 0;

    inline for (fields) |field| {
        ptr = @ptrCast(*Hidden, &@field(@ptrCast(PtrT, ptr), field));
        PtrT = @typeOf(&@field(@ptrCast(PtrT, ptr), field));
    }

    return @ptrCast(PtrT, ptr);
}

test "fieldPtr" {
    const S2 = struct {
        a: u8,
        b: u16,
    };
    const S1 = struct {
        a: u8,
        b: S2,
    };
    var s = S1{
        .a = 2,
        .b = S2{
            .a = 3,
            .b = 22,
        },
    };

    const a = fieldPtr(&s, *u8, [][]const u8{ "b", "a" });
    debug.assert(a.* == 3);
}

fn getFileAsType(comptime T: type, files: []const *nds.fs.Narc.File, index: usize) !*T {
    const data = generic.widenTrim(files[index].data, T);
    return generic.at(data, 0) catch error.FileToSmall;
}
