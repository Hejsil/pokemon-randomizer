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

const toLittle = little.toLittle;
const Little = little.Little;
const Namespace = @typeOf(std);

const u9 = @IntType(false, 9);
const u10 = @IntType(false, 10);

test "pokemon" {
    _ = @import("common.zig");
    _ = @import("gen2-constants.zig");
    _ = @import("gen2.zig");
    _ = @import("gen3-constants.zig");
    _ = @import("gen3.zig");
    _ = @import("gen4-constants.zig");
    _ = @import("gen4.zig");
    _ = @import("gen5-constants.zig");
    _ = @import("gen5.zig");
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

    /// Dispatches a generic function with signature fn(comptime Namespace, @typeOf(context)) Result
    /// based on the result of ::version.gen(). The first parameter passed to ::func is a comptime
    /// known ::Namespace containing the declarations for the generation that ::version.get()
    /// corrispons too. This allows us to write ::func once, but have it use different types
    /// depending on the generation of Pokémon games we are working on.
    pub fn dispatch(
        version: Version,
        comptime Result: type,
        context: var,
        comptime func: var,
    ) Result {
        return switch (version.gen()) {
            1 => @panic("TODO: Gen1"),
            2 => @panic("TODO: Gen1"),
            3 => func(gen3, context),
            4 => func(gen4, context),
            5 => func(gen5, context),
            6 => @panic("TODO: Gen1"),
            7 => @panic("TODO: Gen1"),
            else => unreachable,
        };
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
            gen3 => []u16{
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
        return toOther(Type, @bitCast(gen.Type, @TagType(gen.Type)(id))) orelse Type.Invalid;
    }

    pub fn toGame(version: Version, t: Type) u8 {
        // TODO: What do we do when the type does not exist in the game we are hacking.
        //       For now, we just output 0xAA which is highly likely to not be a type in the game,
        //       so the game will probably crash.
        //       Should we assert here instead? Throw an error? What if the game have hacked in
        //       types? Maybe these functions are only for convinience when hacking mainline games
        //       and are useless on hacked games.
        return version.dispatch(u8, t, toGameHelper);
    }

    fn toGameHelper(comptime gen: Namespace, t: Type) u8 {
        const res = toOther(gen.Type, t) orelse return 0xAA;
        return u8(res);
    }

    fn toOther(comptime Out: type, in: var) ?Out {
        const In = @typeOf(in);
        const in_tags = @typeInfo(@typeOf(in)).Enum.fields;
        const out_tags = @typeInfo(Out).Enum.fields;
        inline for (in_tags) |in_tag| {
            inline for (out_tags) |out_tag| {
                if (!mem.eql(u8, in_tag.name, out_tag.name))
                    continue;

                const out_value = @TagType(Out)(out_tag.value);
                return Out(out_value);
            }
        }

        return null;
    }
};

pub const LevelUpMove = extern struct {
    version: Version,
    data: *u8,

    pub fn level(move: LevelUpMove) u8 {
        return move.version.dispatch(u8, move, levelHelper);
    }

    fn levelHelper(comptime gen: Namespace, lvl_up_move: *const LevelUpMove) u8 {
        const lvl = @ptrCast(*gen.LevelUpMove, lvl_up_move.data).level;
        return if (gen == gen5) @intCast(u8, lvl.get()) else lvl;
    }

    pub fn setLevel(move: LevelUpMove, lvl: u8) void {
        move.version.dispatch(void, SetLvlC{
            .move = move,
            .lvl = lvl,
        }, setLevelHelper);
    }

    const SetLvlC = struct {
        move: LevelUpMove,
        lvl: u8,
    };

    fn setLevelHelper(comptime gen: Namespace, c: var) void {
        const lvl = if (gen == gen5) toLittle(u16(c.lvl)) else u7(c.lvl);
        @ptrCast(*gen.LevelUpMove, c.move.data).level = lvl;
    }

    pub fn moveId(move: LevelUpMove) u16 {
        return move.version.dispatch(u16, move, moveIdHelper);
    }

    fn moveIdHelper(comptime gen: Namespace, move: var) u16 {
        const move_id = @ptrCast(*gen.LevelUpMove, move.data).move_id;
        return if (gen == gen5) move_id.get() else move_id;
    }

    pub fn setMoveId(move: LevelUpMove, id: u16) void {
        move.version.dispatch(u16, SetMoveIdC{
            .move = move,
            .id = id,
        }, setLevelHelper);
    }

    const SetMoveIdC = struct {
        move: LevelUpMove,
        id: u8,
    };

    fn setMoveIdHelper(comptime gen: Namespace, c: var) void {
        const id = if (gen == gen5) toLittle(u16(c.id)) else u9(c.id);
        @ptrCast(*gen.LevelUpMove, c.move.data).move_id = id;
    }
};

pub const LevelUpMoves = extern struct {
    version: Version,
    data_len: usize,
    data: [*]u8,

    pub fn at(moves: LevelUpMoves, index: usize) LevelUpMove {
        return moves.version.dispatch(LevelUpMove, atC{
            .moves = moves,
            .index = index,
        }, atHelper);
    }

    const atC = struct {
        moves: LevelUpMoves,
        index: usize,
    };

    fn atHelper(comptime gen: Namespace, c: var) LevelUpMove {
        const moves = @ptrCast([*]gen.LevelUpMove, c.moves.data)[0..c.moves.data_len];
        return LevelUpMove{
            .version = c.moves.version,
            .data = @ptrCast(*u8, &moves[c.index]),
        };
    }

    pub fn len(moves: LevelUpMoves) usize {
        return moves.data_len;
    }

    pub fn iterator(moves: LevelUpMoves) Iter {
        return Iter.init(moves);
    }

    const Iter = Iterator(LevelUpMoves, LevelUpMove);
};

const MachineKind = enum {
    Hidden,
    Technical,
};

pub const TmLearnset = Learnset(MachineKind.Technical);
pub const HmLearnset = Learnset(MachineKind.Hidden);

pub fn Learnset(comptime kind: MachineKind) type {
    return extern struct {
        const Self = this;
        game: *const BaseGame,
        data: *u8,

        pub fn at(learnset: Self, index: usize) bool {
            return learnset.game.version.dispatch(bool, atC{
                .learnset = learnset,
                .index = index,
            }, atHelper);
        }

        const atC = struct {
            learnset: Self,
            index: usize,
        };

        fn atHelper(comptime gen: Namespace, c: var) bool {
            const i = c.learnset.indexInLearnset(gen, c.index);

            const T = if (gen == gen3) u64 else u128;
            const learnset = @ptrCast(*Little(T), c.learnset.data);
            return bits.get(T, learnset.get(), @intCast(math.Log2Int(T), i));
        }

        pub fn atSet(learnset: Self, index: usize, value: bool) void {
            learnset.game.version.dispatch(bool, atSetC{
                .learnset = learnset,
                .index = index,
                .value = value,
            }, atSetHelper);
        }

        const atSetC = struct {
            learnset: Self,
            index: usize,
            value: bool,
        };

        fn atSetHelper(comptime gen: Namespace, c: var) void {
            const i = c.learnset.indexInLearnset(gen, index);

            const T = if (gen == gen3) u64 else u128;
            const learnset = @ptrCast(*Little(T), learnset.data);
            learnset.set(bits.set(T, learnset.get(), math.Log2Int(T)(i), c.value));
        }

        fn indexInLearnset(learnset: Self, comptime gen: Namespace, index: usize) usize {
            const game = @fieldParentPtr(gen.Game, "base", learnset.game);
            const i = switch (gen) {
                gen3, gen4 => {
                    if (kind == MachineKind.Hidden) {
                        debug.assert(index < game.hms.len);
                        return index + game.tms.len;
                    }

                    debug.assert(index < game.tms.len);
                    return index;
                },
                gen5 => {
                    if (kind == MachineKind.Hidden) {
                        debug.assert(index < game.hms.len);
                        return index + game.tms1.len;
                    }

                    debug.assert(index < game.tms1.len + game.tms2.len);
                    return if (index < game.tms1.len) index else index + game.hms.len;
                },
                else => @compileError("Gen not supported!"),
            };
        }

        pub fn len(learnset: Self) usize {
            return learnset.game.version.dispatch(usize, learnset, lenHelper);
        }

        fn lenHelper(comptime gen: Namespace, learnset: var) usize {
            const game = @fieldParentPtr(gen.Game, "base", learnset.game);
            if (kind == MachineKind.Hidden)
                return game.hms.len;

            return switch (gen) {
                gen3, gen4 => game.tms.len,
                gen5 => game.tms1.len + game.tms2.len,
                else => @compileError("Gen not supported!"),
            };
        }

        pub fn iterator(learnset: Self) Iter {
            return Iter.init(learnset);
        }

        const Iter = Iterator(Self, bool);
    };
}

pub const Pokemon = extern struct {
    game: *const BaseGame,

    base: *u8,
    learnset: *u8,
    level_up_moves_len: usize,
    level_up_moves: [*]u8,

    pub fn hp(pokemon: Pokemon) *u8 {
        return pokemon.game.version.dispatch(*u8, pokemon, hpHelper);
    }

    fn hpHelper(comptime gen: Namespace, pokemon: var) *u8 {
        return &@ptrCast(*gen.BasePokemon, pokemon.base).stats.hp;
    }

    pub fn attack(pokemon: Pokemon) *u8 {
        return pokemon.game.version.dispatch(*u8, pokemon, attackHelper);
    }

    fn attackHelper(comptime gen: Namespace, pokemon: var) *u8 {
        return &@ptrCast(*gen.BasePokemon, pokemon.base).stats.attack;
    }

    pub fn defense(pokemon: Pokemon) *u8 {
        return pokemon.game.version.dispatch(*u8, pokemon, defenseHelper);
    }

    fn defenseHelper(comptime gen: Namespace, pokemon: var) *u8 {
        return &@ptrCast(*gen.BasePokemon, pokemon.base).stats.defense;
    }

    pub fn speed(pokemon: Pokemon) *u8 {
        return pokemon.game.version.dispatch(*u8, pokemon, speedHelper);
    }

    fn speedHelper(comptime gen: Namespace, pokemon: var) *u8 {
        return &@ptrCast(*gen.BasePokemon, pokemon.base).stats.speed;
    }

    pub fn spAttack(pokemon: Pokemon) *u8 {
        return pokemon.game.version.dispatch(*u8, pokemon, spAttackHelper);
    }

    fn spAttackHelper(comptime gen: Namespace, pokemon: var) *u8 {
        return &@ptrCast(*gen.BasePokemon, pokemon.base).stats.sp_attack;
    }

    pub fn spDefense(pokemon: Pokemon) *u8 {
        return pokemon.game.version.dispatch(*u8, pokemon, spDefenseHelper);
    }

    fn spDefenseHelper(comptime gen: Namespace, pokemon: var) *u8 {
        return &@ptrCast(*gen.BasePokemon, pokemon.base).stats.sp_defense;
    }

    pub fn levelUpMoves(pokemon: Pokemon) LevelUpMoves {
        return LevelUpMoves{
            .version = pokemon.game.version,
            .data_len = pokemon.level_up_moves_len,
            .data = pokemon.level_up_moves,
        };
    }

    pub fn totalStats(pokemon: Pokemon) u16 {
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

    pub fn types(pokemon: Pokemon) *[2]u8 {
        return pokemon.game.version.dispatch(*[2]u8, pokemon, typesHelper);
    }

    fn typesHelper(comptime gen: Namespace, pokemon: Pokemon) *[2]u8 {
        const ts = &@ptrCast(*gen.BasePokemon, pokemon.base).types;
        return @ptrCast(*[2]u8, ts);
    }

    pub fn tmLearnset(pokemon: Pokemon) TmLearnset {
        return TmLearnset{
            .game = pokemon.game,
            .data = pokemon.learnset,
        };
    }

    pub fn hmLearnset(pokemon: Pokemon) HmLearnset {
        return HmLearnset{
            .game = pokemon.game,
            .data = pokemon.learnset,
        };
    }
};

pub const Pokemons = extern struct {
    game: *const BaseGame,

    pub fn at(pokemons: Pokemons, index: usize) AtErrs!Pokemon {
        return pokemons.game.version.dispatch(AtErrs!Pokemon, atC{
            .pokemons = pokemons,
            .index = index,
        }, atHelper);
    }

    const AtErrs = error{
        InvalidOffset,
        FileToSmall,
    };

    const atC = struct {
        pokemons: Pokemons,
        index: usize,
    };

    fn atHelper(comptime gen: Namespace, c: var) AtErrs!Pokemon {
        const index = c.index;
        const pokemons = c.pokemons;
        const game = @fieldParentPtr(gen.Game, "base", pokemons.game);

        var base_pokemon: *gen.BasePokemon = undefined;
        var learnset: *u8 = undefined;
        switch (gen) {
            gen3 => {
                base_pokemon = &game.base_stats[index];
                learnset = @ptrCast(*u8, &game.tm_hm_learnset[index]);
            },
            gen4, gen5 => {
                base_pokemon = try getFileAsType(gen.BasePokemon, game.base_stats, index);
                learnset = @ptrCast(*u8, &base_pokemon.tm_hm_learnset);
            },
            else => @compileError("Gen not supported!"),
        }

        const level_up_moves = blk: {
            var start: usize = undefined;
            var data: []u8 = undefined;
            switch (gen) {
                gen3 => {
                    const s = generic.at(game.level_up_learnset_pointers, index) catch return error.InvalidOffset;
                    start = math.sub(usize, s.get(), 0x8000000) catch return error.InvalidOffset;
                    data = game.data;
                },
                gen4, gen5 => {
                    start = 0;
                    data = game.level_up_moves[index].data;
                },
                else => @compileError("Gen not supported!"),
            }

            // gen3,4,5 all have 0xFF ** @sizeOf(gen.LevelUpMove) terminated level up moves,
            // even though gen4,5 stores level up moves in files with a length.
            const terminator = []u8{0xFF} ** @sizeOf(gen.LevelUpMove);
            const res = generic.widenTrim(data[start..], gen.LevelUpMove);
            for (res) |level_up_move, i| {
                const bytes = utils.toBytes(@typeOf(level_up_move), level_up_move);
                if (std.mem.eql(u8, bytes, terminator))
                    break :blk res[0..i];
            }

            break :blk res;
        };

        return Pokemon{
            .game = pokemons.game,
            .base = @ptrCast(*u8, base_pokemon),
            .learnset = learnset,
            .level_up_moves_len = level_up_moves.len,
            .level_up_moves = @ptrCast([*]u8, level_up_moves.ptr),
        };
    }

    pub fn len(pokemons: Pokemons) usize {
        return pokemons.game.version.dispatch(usize, pokemons, lenHelper);
    }

    fn lenHelper(comptime gen: Namespace, pokemons: Pokemons) usize {
        const game = @fieldParentPtr(gen.Game, "base", pokemons.game);

        var min = game.base_stats.len;
        if (gen == gen3) {
            min = math.min(min, game.tm_hm_learnset.len);
            min = math.min(min, game.evolution_table.len);
            min = math.min(min, game.level_up_learnset_pointers.len);
        }
        if (gen == gen4 or gen == gen5) {
            min = math.min(min, game.level_up_moves.len);
        }

        return min;
    }

    pub fn iterator(pokemons: Pokemons) Iter {
        return Iter.init(pokemons);
    }

    const Iter = ErrIterator(Pokemons, Pokemon);
};

const PartyMemberMoves = extern struct {
    game: *const BaseGame,
    data: [*]u8,

    pub fn at(moves: PartyMemberMoves, index: usize) u16 {
        return moves.game.version.dispatch(u16, AtC{
            .moves = moves,
            .index = index,
        }, atHelper);
    }

    const AtC = struct {
        moves: PartyMemberMoves,
        index: usize,
    };

    fn atHelper(comptime gen: Namespace, c: AtC) u16 {
        const moves = @ptrCast(*[4]Little(u16), c.moves.data);
        return moves[c.index].get();
    }

    pub fn atSet(moves: PartyMemberMoves, index: usize, value: u16) void {
        moves.game.version.dispatch(void, AtSetC{
            .moves = moves,
            .index = index,
            .value = value,
        }, atSetHelper);
    }

    const AtSetC = struct {
        moves: PartyMemberMoves,
        index: usize,
        value: u16,
    };

    fn atSetHelper(comptime gen: Namespace, c: AtSetC) void {
        const moves = @ptrCast(*[4]Little(u16), c.moves.data);
        return moves[c.index].set(c.value);
    }

    pub fn len(moves: PartyMemberMoves) usize {
        return 4;
    }

    pub fn iterator(moves: PartyMemberMoves) Iter {
        return Iter.init(pokemons);
    }

    const Iter = Iterator(PartyMemberMoves, u16);
};

pub const PartyMember = extern struct {
    game: *const BaseGame,
    base: *u8,
    item_ptr: ?*u8,
    moves_ptr: ?[*]u8,

    pub fn species(member: PartyMember) u16 {
        return member.game.version.dispatch(u16, member, speciesHelper);
    }

    fn speciesHelper(comptime gen: Namespace, member: PartyMember) u16 {
        const s = @ptrCast(*gen.PartyMember, member.base).species;
        return if (gen != gen4) s.get() else s;
    }

    pub fn setSpecies(member: PartyMember, v: u16) void {
        member.game.version.dispatch(void, SetSpeciesC{
            .member = member,
            .value = v,
        }, setSpeciesHelper);
    }

    const SetSpeciesC = struct {
        member: PartyMember,
        value: u16,
    };

    fn setSpeciesHelper(comptime gen: Namespace, c: SetSpeciesC) void {
        const s = if (gen != gen4) toLittle(c.value) else @intCast(u10, c.value);
        @ptrCast(*gen.PartyMember, c.member.base).species = s;
    }

    pub fn level(member: PartyMember) u8 {
        return member.game.version.dispatch(u8, member, levelHelper);
    }

    fn levelHelper(comptime gen: Namespace, member: var) u8 {
        const lvl = @ptrCast(*gen.PartyMember, member.base).level;
        return if (gen != gen5) @intCast(u8, lvl.get()) else lvl;
    }

    pub fn setLevel(member: PartyMember, lvl: u8) void {
        return member.game.version.dispatch(void, SetLvlC{
            .member = member,
            .value = lvl,
        }, setLevelHelper);
    }

    const SetLvlC = struct {
        member: PartyMember,
        value: u8,
    };

    fn setLevelHelper(comptime gen: Namespace, c: SetLvlC) void {
        const lvl = if (gen != gen5) toLittle(u16(c.value)) else c.value;
        @ptrCast(*gen.PartyMember, c.member.base).level = lvl;
    }

    pub fn item(member: PartyMember) ?u16 {
        return member.game.version.dispatch(?u16, member, itemHelper);
    }

    fn itemHelper(comptime gen: Namespace, member: var) ?u16 {
        const item_ptr = @ptrCast(?*Little(u16), member.item_ptr) orelse return null;
        return item_ptr.get();
    }

    pub fn setItem(member: PartyMember, v: u16) SetItemErr!void {
        return member.game.version.dispatch(SetItemErr!void, SetItemC{
            .member = member,
            .value = v,
        }, setItemHelper);
    }

    const SetItemErr = error{HasNoItem};
    const SetItemC = struct {
        member: PartyMember,
        value: u16,
    };

    fn setItemHelper(comptime gen: Namespace, c: SetItemC) SetItemErr!void {
        const item_ptr = @ptrCast(?*Little(u16), c.member.item_ptr) orelse return SetItemErr.HasNoItem;
        return item_ptr.set(c.value);
    }

    pub fn moves(member: PartyMember) ?PartyMemberMoves {
        return PartyMemberMoves{
            .game = member.game,
            .data = member.moves_ptr orelse return null,
        };
    }
};

pub const Party = extern struct {
    trainer: *const Trainer,

    pub fn at(party: Party, index: usize) PartyMember {
        return party.trainer.game.version.dispatch(PartyMember, AtC{
            .party = party,
            .index = index,
        }, atHelper);
    }

    const AtC = struct {
        party: Party,
        index: usize,
    };

    fn atHelper(comptime gen: Namespace, c: AtC) PartyMember {
        const index = c.index;
        const trainer = @ptrCast(*gen.Trainer, c.party.trainer.base);
        const member_size = c.party.memberSize();
        const party_size = if (gen == gen3) trainer.party_size.get() else trainer.party_size;
        const party_data = c.party.trainer.party_ptr[0 .. party_size * member_size];
        const member_data = party_data[index * member_size ..][0..member_size];
        var off: usize = 0;

        const base = &member_data[off];
        off += @sizeOf(gen.PartyMember);

        const item = blk: {
            const has_item = trainer.party_type & gen.PartyMember.has_item != 0;
            if (has_item) {
                const end = off + @sizeOf(u16);
                defer off = end;
                break :blk @ptrCast(*u8, &member_data[off..end][0]);
            }

            break :blk null;
        };

        const moves = blk: {
            const has_item = trainer.party_type & gen.PartyMember.has_moves != 0;
            if (has_item) {
                const end = off + @sizeOf([4]u16);
                defer off = end;
                break :blk member_data[off..end].ptr;
            }

            break :blk null;
        };

        if (gen == gen3) {
            if (item == null)
                off += @sizeOf(u16);
        }

        off += switch (c.party.trainer.game.version) {
            Version.HeartGold, Version.SoulSilver, Version.Platinum => usize(@sizeOf(u16)),
            else => usize(0),
        };

        // It's a bug, if we haven't read all member_data
        debug.assert(member_data.len == off);

        return PartyMember{
            .game = c.party.trainer.game,
            .base = base,
            .item_ptr = item,
            .moves_ptr = moves,
        };
    }

    pub fn len(party: Party) usize {
        return party.trainer.game.version.dispatch(usize, party, lenHelper);
    }

    fn lenHelper(comptime gen: Namespace, party: var) usize {
        const trainer = @ptrCast(*gen.Trainer, party.trainer.base);
        return switch (gen) {
            gen3 => trainer.party_size.get(),
            gen4, gen5 => trainer.party_size,
            else => @compileError("Gen not supported!"),
        };
    }

    fn memberSize(party: Party) usize {
        return party.trainer.game.version.dispatch(usize, party, memberSizeHelper);
    }

    fn memberSizeHelper(comptime gen: Namespace, party: Party) usize {
        const trainer = @ptrCast(*gen.Trainer, party.trainer.base);
        var res: usize = @sizeOf(gen.PartyMember);
        if (gen == gen3) {
            res += @sizeOf(u16);
        } else if (trainer.party_type & gen.PartyMember.has_item != 0) {
            res += @sizeOf(u16);
        }
        if (trainer.party_type & gen.PartyMember.has_moves != 0)
            res += @sizeOf([4]u16);

        // In HG/SS/Plat party members are padded with two extra bytes.
        res += switch (party.trainer.game.version) {
            Version.HeartGold, Version.SoulSilver, Version.Platinum => usize(2),
            else => usize(0),
        };

        return res;
    }

    pub fn iterator(party: Party) Iter {
        return Iter.init(party);
    }

    const Iter = Iterator(Party, PartyMember);
};

pub const Trainer = extern struct {
    game: *const BaseGame,

    base: *u8,
    party_ptr: [*]u8,

    pub fn party(trainer: Trainer) Party {
        return Party{ .trainer = trainer };
    }
};

pub const Trainers = extern struct {
    game: *const BaseGame,

    pub fn at(trainers: Trainers, index: usize) AtErr!Trainer {
        return trainers.game.version.dispatch(AtErr!Trainer, AtC{
            .trainers = trainers,
            .index = index,
        }, atHelper);
    }

    const AtErr = error{
        InvalidOffset,
        FileToSmall,
        InvalidPartySize,
    };

    const AtC = struct {
        trainers: Trainers,
        index: usize,
    };

    fn atHelper(comptime gen: Namespace, c: AtC) AtErr!Trainer {
        const trainers = c.trainers;
        const index = c.index;
        const game = @fieldParentPtr(gen.Game, "base", trainers.game);

        const trainer = if (gen == gen3) &game.trainers[index] else try getFileAsType(gen.Trainer, game.trainers, index);
        var res = Trainer{
            .game = &game.base,
            .base = @ptrCast(*u8, trainer),
            .party_ptr = undefined,
        };

        res.party_ptr = switch (gen) {
            gen3 => blk: {
                const start = math.sub(usize, trainer.party_offset.get(), 0x8000000) catch return error.InvalidOffset;
                const end = start + trainer.party_size.get() * res.party().memberSize();
                const party = generic.slice(game.data, start, end) catch return error.InvalidOffset;
                break :blk party.ptr;
            },
            gen4, gen5 => blk: {
                const party_data = game.parties[index].data;
                const min_size = trainer.party_size * res.party().memberSize();
                if (party_data.len < min_size)
                    return error.InvalidPartySize;

                break :blk party_data.ptr;
            },
            else => @compileError("Gen not supported!"),
        };

        return res;
    }

    pub fn len(trainers: Trainers) usize {
        return trainers.game.version.dispatch(usize, trainers, lenHelper);
    }

    fn lenHelper(comptime gen: Namespace, trainers: var) usize {
        const game = @fieldParentPtr(gen.Game, "base", trainers.game);
        var min = game.trainers.len;
        if (gen == gen4 or gen == gen5)
            min = math.min(min, game.parties.len);

        return min;
    }

    pub fn iterator(trainers: Trainers) Iter {
        return Iter.init(trainers);
    }

    const Iter = ErrIterator(Trainers, Trainer);
};

pub const Tms = Machines(MachineKind.Technical);
pub const Hms = Machines(MachineKind.Hidden);

pub fn Machines(comptime kind: MachineKind) type {
    return extern struct {
        const Self = this;

        game: *const BaseGame,

        pub fn at(machines: Self, index: usize) u16 {
            return machines.game.version.dispatch(u16, AtC{
                .machines = machines,
                .index = index,
            }, atHelper);
        }

        const AtC = struct {
            machines: Self,
            index: usize,
        };

        fn atHelper(comptime gen: Namespace, c: AtC) u16 {
            var index = c.index;
            const machines = getMachines(gen, c.machines, &index);
            return machines[index].get();
        }

        pub fn atSet(machines: Self, index: usize, value: u16) void {
            return machines.game.version.dispatch(void, AtSetC{
                .machines = machines,
                .index = index,
                .value = value,
            }, atSetHelper);
        }

        const AtSetC = struct {
            machines: *const Self,
            index: usize,
            value: u16,
        };

        fn atSetHelper(comptime gen: Namespace, c: AtSetC) void {
            var index = c.index;
            const machines = getMachines(gen, c.machines, &index);
            machines[index].set(c.value);
        }

        fn getMachines(comptime gen: Namespace, machines: Self, index: *usize) []Little(u16) {
            const game = @fieldParentPtr(gen.Game, "base", machines.game);
            switch (gen) {
                gen3, gen4 => return if (kind == MachineKind.Hidden) game.hms else game.tms,
                gen5 => {
                    if (kind == MachineKind.Hidden)
                        return game.hms;

                    if (index.* < game.tms1.len)
                        return game.tms1;

                    index.* -= game.tms1.len;
                    return game.tms2;
                },
                else => @compileError("Gen not supported!"),
            }
        }

        pub fn len(machines: Self) usize {
            return machines.game.version.dispatch(usize, machines, lenHelper);
        }

        fn lenHelper(comptime gen: Namespace, machines: Self) usize {
            const game = @fieldParentPtr(gen.Game, "base", machines.game);
            return switch (gen) {
                gen3, gen4 => game.tms.len,
                gen5 => game.tms1.len + game.tms2,
                else => @compileError("Gen not supported!"),
            };
        }

        pub fn iterator(machines: Self) Iterator {
            return Iterator.init(machines);
        }

        const Iterator = GenerateIterator(Machines, u16);
    };
}

pub const Move = extern struct {
    game: *const BaseGame,
    data: *u8,

    pub fn types(move: Move) *[1]u8 {
        return move.game.version.dispatch(*[1]u8, move, typesHelper);
    }

    fn typesHelper(comptime gen: Namespace, move: var) *[1]u8 {
        const t = &@ptrCast(*gen.Move, move.data).@"type";
        return @ptrCast(*[1]u8, t);
    }

    pub fn power(move: Move) *u8 {
        return move.game.version.dispatch(*u8, move, powerHelper);
    }

    fn powerHelper(comptime gen: Namespace, move: Move) *u8 {
        return &@ptrCast(*gen.Move, move.data).power;
    }

    pub fn pp(move: Move) *u8 {
        return move.game.version.dispatch(*u8, move, ppHelper);
    }

    fn ppHelper(comptime gen: Namespace, move: Move) *u8 {
        return &@ptrCast(*gen.Move, move.data).pp;
    }
};

pub const Moves = extern struct {
    game: *const BaseGame,

    pub fn at(moves: Moves, index: usize) Move {
        return moves.game.version.dispatch(Move, AtC{
            .moves = moves,
            .index = index,
        }, atHelper);
    }

    const AtC = struct {
        moves: Moves,
        index: usize,
    };

    fn atHelper(comptime gen: Namespace, c: AtC) Move {
        const index = c.index;
        const moves = c.moves;
        const game = @fieldParentPtr(gen.Game, "base", moves.game);
        const move = switch (gen) {
            gen3 => &game.moves[index],
            gen4, gen5 => game.moves[index],
            else => @compileError("Gen not supported!"),
        };

        return Move{
            .game = moves.game,
            .data = @ptrCast(*u8, move),
        };
    }

    pub fn len(moves: Moves) usize {
        return moves.game.version.dispatch(usize, moves, lenHelper);
    }

    fn lenHelper(comptime gen: Namespace, moves: var) usize {
        const game = @fieldParentPtr(gen.Game, "base", moves.game);
        return game.moves.len;
    }

    pub fn iterator(moves: Moves) Iterator {
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
    nds_rom: ?*nds.Rom,

    pub fn load(file: *os.File, allocator: *mem.Allocator) !Game {
        const start = try file.getPos();
        gba_blk: {
            try file.seekTo(start);
            const game = gen3.Game.fromFile(file, allocator) catch break :gba_blk;
            const alloced_game = try allocator.construct(game);

            return Game{
                .base = &alloced_game.base,
                .allocator = allocator,
                .nds_rom = null,
            };
        }

        nds_blk: {
            try file.seekTo(start);
            const nds_rom = try allocator.create(nds.Rom);
            nds_rom.* = nds.Rom.fromFile(file, allocator) catch {
                allocator.destroy(nds_rom);
                break :nds_blk;
            };

            if (gen4.Game.fromRom(nds_rom.*)) |game| {
                const alloced_game = try allocator.construct(game);
                return Game{
                    .base = &alloced_game.base,
                    .allocator = allocator,
                    .nds_rom = nds_rom,
                };
            } else |e1| if (gen5.Game.fromRom(nds_rom.*)) |game| {
                const alloced_game = try allocator.construct(game);
                return Game{
                    .base = &alloced_game.base,
                    .allocator = allocator,
                    .nds_rom = nds_rom,
                };
            } else |e2| {
                break :nds_blk;
            }
        }

        return error.InvalidGame;
    }

    pub fn save(game: Game, file: *os.File) !void {
        const gen = game.base.version.gen();
        if (gen == 3) {
            const g = @fieldParentPtr(gen3.Game, "base", game.base);
            var file_stream = io.FileOutStream.init(file);
            try g.writeToStream(&file_stream.stream);
        }

        if (game.nds_rom) |nds_rom|
            try nds_rom.writeToFile(file, game.allocator);
    }

    pub fn deinit(game: *Game) void {
        game.base.version.dispatch(void, game, deinitHelper);
    }

    fn deinitHelper(comptime gen: Namespace, game: *Game) void {
        const allocator = @ptrCast(*mem.Allocator, game.allocator);
        const g = @fieldParentPtr(gen.Game, "base", game.base);

        if (gen == gen3)
            g.deinit();
        if (game.nds_rom) |nds_rom| {
            nds_rom.deinit();
            allocator.destroy(nds_rom);
        }

        allocator.destroy(g);
        game.* = undefined;
    }

    pub fn pokemons(game: Game) Pokemons {
        return Pokemons{ .game = game.base };
    }

    pub fn trainers(game: Game) Trainers {
        return Trainers{ .game = game.base };
    }

    pub fn tms(game: Game) Tms {
        return Tms{ .game = game.base };
    }

    pub fn hms(game: Game) Hms {
        return Hms{ .game = game.base };
    }

    pub fn moves(game: Game) Moves {
        return Moves{ .game = game.base };
    }
};

fn Iterator(comptime Items: type, comptime Result: type) type {
    return struct {
        const Self = this;

        items: Items,
        curr: usize,

        pub const Pair = struct {
            index: usize,
            value: Result,
        };

        pub fn init(items: Items) Self {
            return Self{
                .items = items,
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

fn ErrIterator(comptime Items: type, comptime Result: type) type {
    return struct {
        const Self = this;

        items: Items,
        curr: usize,

        pub const Pair = struct {
            index: usize,
            value: Result,
        };

        pub fn init(items: Items) Self {
            return Self{
                .items = items,
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

fn getFileAsType(comptime T: type, files: []const *nds.fs.Narc.File, index: usize) !*T {
    const data = generic.widenTrim(files[index].data, T);
    return generic.at(data, 0) catch error.FileToSmall;
}
