pub const common = @import("common.zig");
pub const gen2   = @import("gen2.zig");
pub const gen3   = @import("gen3.zig");
pub const gen4   = @import("gen4.zig");
pub const gen5   = @import("gen5.zig");

const std    = @import("std");
const fun    = @import("fun");
const nds    = @import("../nds/index.zig");
const utils  = @import("../utils/index.zig");
const little = @import("../little.zig");
const bits   = @import("../bits.zig");

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

pub const Gen3 = struct {
    pub const Game = gen3.Game;
    pub const BasePokemon = gen3.BasePokemon;
    pub const Evolution = common.Evolution;
    pub const PartyType = gen3.PartyType;
    pub const BaseTrainer = gen3.Trainer;
    pub const PartyMember = gen3.PartyMemberBase;
    pub const Move = gen3.Move;
    pub const LevelUpMove = common.LevelUpMove;
    pub const Item = gen3.Item;
    pub const Type = gen3.Type;

    pub const Pokemons = Collection(Pokemon, error{InvalidOffset});
    pub fn pokemons(game: &const Game) Pokemons {
        return Pokemons.initExternFunctionsAndContext(
            struct {
                fn at(g: &const Game, index: usize) !Pokemon {
                    const base_pokemons = g.base_stats;
                    const offset = blk: {
                        const res = generic.at(g.level_up_learnset_pointers, index) catch return error.InvalidOffset;
                        if (res.get() < 0x8000000) return error.InvalidOffset;
                        break :blk res.get() - 0x8000000;
                    };
                    if (g.data.len < offset) return error.InvalidOffset;

                    const end = blk: {
                        var i : usize = offset;
                        while (true) : (i += @sizeOf(LevelUpMove)) {
                            if (g.data.len < i)     return error.InvalidOffset;
                            if (g.data.len < i + 1) return error.InvalidOffset;
                            if (g.data[i] == 0xFF and g.data[i+1] == 0xFF) break;
                        }

                        break :blk i;
                    };

                    return Pokemon {
                        .base = &base_pokemons[index],
                        .game = g,
                        .level_up_moves = ([]LevelUpMove)(g.data[offset..end]),
                        .learnset = generic.at(g.tm_hm_learnset, index) catch return error.InvalidOffset,
                    };
                }

                fn length(g: &const Game) usize {
                    return g.base_stats.len;
                }
            },
            Game,
            game,
        );
    }

    pub const Pokemon = struct {
        base: &BasePokemon,
        game: &const Game,
        level_up_moves: []LevelUpMove,
        learnset: &little.Little(u64),

        pub const LevelUpMoves = Collection(&LevelUpMove, error{});
        pub fn levelUpMoves(pokemon: &const Pokemon) LevelUpMoves {
            return LevelUpMoves.initSlice(LevelUpMove, pokemon.level_up_moves);
        }

        pub const Learnset = Collection(bool, error{});
        pub fn tmLearnset(pokemon: &const Pokemon) Learnset {
            return Learnset.initExternFunctionsAndContext(
                struct {
                    fn at(p: &const Pokemon, index: usize) (error{}!bool) {
                        debug.assert(index < length(p));
                        return bits.get(u64, p.learnset.get(), u6(index));
                    }

                    fn length(p: &const Pokemon) usize {
                        return p.game.tms.len;
                    }
                },
                Pokemon,
                pokemon
            );
        }

        pub fn hmLearnset(pokemon: &const Pokemon) Learnset {
            return Learnset.initExternFunctionsAndContext(
                struct {
                    fn at(p: &const Pokemon, index: usize) (error{}!bool) {
                        debug.assert(index <= length(p));
                        return bits.get(u64, p.learnset.get(), u6(p.game.tms.len + index));
                    }

                    fn length(p: &const Pokemon) usize {
                        return p.game.hms.len;
                    }
                },
                Pokemon,
                pokemon
            );
        }
    };

    pub const Trainers = Collection(Trainer, error{InvalidOffset,InvalidPartyType});
    pub fn trainers(game: &const Game) Trainers {
        return Trainers.initExternFunctionsAndContext(
            struct {
                fn at(g: &const Game, index: usize) !Trainer {
                    const trainer = &g.trainers[index];
                    const offset = math.sub(usize, trainer.party_offset.get(), 0x8000000) catch return error.InvalidOffset;

                    const data = switch (trainer.party_type) {
                        PartyType.Standard =>  try partyMemberData(gen3.PartyMember,          g.data, offset, trainer.party_size.get()),
                        PartyType.WithMoves => try partyMemberData(gen3.PartyMemberWithMoves, g.data, offset, trainer.party_size.get()),
                        PartyType.WithHeld =>  try partyMemberData(gen3.PartyMemberWithHeld,  g.data, offset, trainer.party_size.get()),
                        PartyType.WithBoth =>  try partyMemberData(gen3.PartyMemberWithBoth,  g.data, offset, trainer.party_size.get()),
                        else => return error.InvalidPartyType,
                    };

                    return Trainer { .base = trainer, .party_data = data };
                }

                fn length(g: &const Game) usize {
                    return g.trainers.len;
                }

                fn partyMemberData(comptime Member: type, data: []u8, offset: usize, size: usize) ![]u8 {
                    const end = offset + size * @sizeOf(Member);
                    if (data.len < end) return error.InvalidOffset;

                    return data[offset..end];
                }
            },
            Game,
            game,
        );
    }

    pub const Trainer = struct {
        base: &BaseTrainer,
        party_data: []u8,

        pub const PartyMembers = Collection(&PartyMember, error{});
        pub fn party(trainer: &const Trainer) PartyMembers {
            return PartyMembers.initExternFunctionsAndContext(
                struct {
                    fn at(t: &const Trainer, index: usize) (error{}!&PartyMember) {

                        return switch (t.base.party_type) {
                            PartyType.Standard =>  basePartyMember(gen3.PartyMember,          t.party_data, index),
                            PartyType.WithMoves => basePartyMember(gen3.PartyMemberWithMoves, t.party_data, index),
                            PartyType.WithHeld =>  basePartyMember(gen3.PartyMemberWithHeld,  t.party_data, index),
                            PartyType.WithBoth =>  basePartyMember(gen3.PartyMemberWithBoth,  t.party_data, index),
                            else => unreachable,
                        };
                    }

                    fn length(t: &const Trainer) usize {
                        return t.base.party_size.get();
                    }

                    fn basePartyMember(comptime TMember: type, data: []u8, index: usize) &PartyMember {
                        const p = ([]TMember)(data);
                        return &p[index].base;
                    }
                },
                Trainer,
                trainer,
            );
        }
    };

    const Moves = Collection(&Move, error{});
    pub fn moves(game: &const Game) Moves {
        return Moves.initSlice(Move, game.moves);
    }

    const Machines = Collection(&little.Little(u16), error{});
    pub fn tms(game: &const Game) Machines {
        return Machines.initSlice(little.Little(u16), game.tms);
    }

    pub fn hms(game: &const Game) Machines {
        return Machines.initSlice(little.Little(u16), game.hms);
    }
};



pub const Gen4 = struct {
    pub const Game = gen4.Game;
    pub const BasePokemon = gen4.BasePokemon;
    pub const Evolution = common.Evolution;
    pub const PartyType = gen4.PartyType;
    pub const BaseTrainer = gen4.Trainer;
    pub const PartyMember = gen4.PartyMemberBase;
    pub const Move = gen4.Move;
    pub const LevelUpMove = common.LevelUpMove;
    pub const Item = gen4.Item;
    pub const Type = gen4.Type;

    pub const Pokemons = Collection(Pokemon, error{DataTooSmall});
    pub fn pokemons(game: &const Game) Pokemons {
        return Pokemons.initExternFunctionsAndContext(
            struct {
                fn at(g: &const Game, index: usize) !Pokemon {
                    const base_pokemon = try getFileAsType(BasePokemon, g.base_stats, index);
                    const level_up_moves = blk: {
                        var tmp = g.level_up_moves[index].data;
                        const res = ([]LevelUpMove)(tmp[0..tmp.len - (tmp.len % @sizeOf(LevelUpMove))]);

                        // Even though each level up move have it's own file, level up moves still
                        // end with 0xFFFF.
                        for (res) |level_up_move, i| {
                            if (std.mem.eql(u8, ([]const u8)((&level_up_move)[0..1]), []u8{0xFF,0xFF}))
                                break :blk res[0..i];
                        }

                        // In the case where we don't find the end 0xFFFF, we just
                        // return the level up moves, and assume things are correct.
                        break :blk res;
                    };


                    return Pokemon {
                        .base = base_pokemon,
                        .game = g,
                        .level_up_moves = level_up_moves,
                    };
                }

                fn length(g: &const Game) usize {
                    return math.min(g.base_stats.len, g.level_up_moves.len);
                }
            },
            Game,
            game,
        );
    }

    pub const Pokemon = struct {
        base: &BasePokemon,
        game: &const Game,
        level_up_moves: []LevelUpMove,

        pub const LevelUpMoves = Collection(&LevelUpMove, error{});
        pub fn levelUpMoves(pokemon: &const Pokemon) LevelUpMoves {
            return LevelUpMoves.initSlice(LevelUpMove, pokemon.level_up_moves);
        }

        pub const Learnset = Collection(bool, error{});
        pub fn tmLearnset(pokemon: &const Pokemon) Learnset {
            return Learnset.initExternFunctionsAndContext(
                struct {
                    fn at(p: &const Pokemon, index: usize) (error{}!bool) {
                        debug.assert(index < length(p));
                        return bits.get(u128, p.base.tm_hm_learnset.get(), u7(index));
                    }

                    fn length(p: &const Pokemon) usize {
                        return p.game.tms.len;
                    }
                },
                Pokemon,
                pokemon
            );
        }

        pub fn hmLearnset(pokemon: &const Pokemon) Learnset {
            return Learnset.initExternFunctionsAndContext(
                struct {
                    fn at(p: &const Pokemon, index: usize) (error{}!bool) {
                        debug.assert(index < length(p));
                        return bits.get(u128, p.base.tm_hm_learnset.get(), u7(p.game.tms.len + index));
                    }

                    fn length(p: &const Pokemon) usize {
                        return p.game.hms.len;
                    }
                },
                Pokemon,
                pokemon
            );
        }
    };

    pub const Trainers = Collection(Trainer, error{DataTooSmall,InvalidPartyType,InvalidPartySize});
    pub fn trainers(game: &const Game) Trainers {
        return Trainers.initExternFunctionsAndContext(
            struct {
                fn at(g: &const Game, index: usize) !Trainer {
                    const trainer = try getFileAsType(BaseTrainer, g.trainer_data, index);
                    const party = g.trainer_pokemons[index].data;

                    const data = switch (trainer.party_type) {
                        PartyType.Standard  => try partyMemberData(gen4.PartyMemberBase,      g.version, party, trainer.party_size),
                        PartyType.WithMoves => try partyMemberData(gen4.PartyMemberWithMoves, g.version, party, trainer.party_size),
                        PartyType.WithHeld  => try partyMemberData(gen4.PartyMemberWithHeld,  g.version, party, trainer.party_size),
                        PartyType.WithBoth  => try partyMemberData(gen4.PartyMemberWithBoth,  g.version, party, trainer.party_size),
                        else => return error.InvalidPartyType,
                    };

                    return Trainer {
                        .base = trainer,
                        .version = g.version,
                        .party_data = data
                    };
                }

                fn length(g: &const Game) usize {
                    return math.min(g.trainer_data.len, g.trainer_pokemons.len);
                }

                fn partyMemberData(comptime Member: type, version: common.Version, data: []u8, size: usize) ![]u8 {
                    // In HGSS/Plat party members are padded with two extra bytes.
                    const padding = switch (version) {
                        common.Version.HeartGold, common.Version.SoulSilver,
                        common.Version.Platinum => usize(2),
                        common.Version.Diamond,
                        common.Version.Pearl => usize(0),
                        else => unreachable,
                    };
                    const byte_size = size * (@sizeOf(Member) + padding);
                    if (data.len < byte_size) return error.InvalidPartySize;

                    return data[0..byte_size];
                }
            },
            Game,
            game,
        );
    }

    pub const Trainer = struct {
        base: &BaseTrainer,
        version: common.Version,
        party_data: []u8,

        pub const PartyMembers = Collection(&PartyMember, error{});
        pub fn party(trainer: &const Trainer) PartyMembers {
            return PartyMembers.initExternFunctionsAndContext(
                struct {
                    fn at(t: &const Trainer, index: usize) (error{}!&PartyMember) {
                        return switch (t.base.party_type) {
                            PartyType.Standard  => basePartyMember(gen4.PartyMemberBase,      t, index),
                            PartyType.WithMoves => basePartyMember(gen4.PartyMemberWithMoves, t, index),
                            PartyType.WithHeld  => basePartyMember(gen4.PartyMemberWithHeld,  t, index),
                            PartyType.WithBoth  => basePartyMember(gen4.PartyMemberWithBoth,  t, index),
                            else => unreachable,
                        };
                    }

                    fn length(t: &const Trainer) usize {
                        return t.base.party_size;
                    }

                    fn basePartyMember(comptime TMember: type, t: &const Trainer, index: usize) &PartyMember {
                        // In HGSS/Plat party members are padded with two extra bytes.
                        const padding = switch (t.version) {
                            common.Version.HeartGold, common.Version.SoulSilver,
                            common.Version.Platinum => usize(2),
                            common.Version.Diamond,
                            common.Version.Pearl => usize(0),
                            else => unreachable,
                        };

                        const data_index = (@sizeOf(TMember) + padding) * index;
                        const member_data = t.party_data[data_index..][0..@sizeOf(PartyMember)];
                        return &([]PartyMember)(member_data)[0];
                    }
                },
                Trainer,
                trainer,
            );
        }
    };

    const Moves = Collection(&Move, error{DataTooSmall});
    pub fn moves(game: &const Game) Moves {
        return Moves.initExternFunctionsAndContext(
            struct {
                fn at(m: &const []const &nds.fs.Narc.File, index: usize) !&Move {
                    return try getFileAsType(Move, m.*, index);
                }

                fn length(m: &const []const &nds.fs.Narc.File) usize {
                    return m.len;
                }
            },
            []const &nds.fs.Narc.File,
            game.moves,
        );
    }

    const Machines = Collection(&little.Little(u16), error{});
    pub fn tms(game: &const Game) Machines {
        return Machines.initExternFunctionsAndContext(
            struct {
                fn at(g: &const Game, index: usize) (error{}!&little.Little(u16)) {
                    debug.assert(index < g.tms.len);
                    return &g.tms[index];
                }

                fn length(g: &const Game) usize {
                    return g.tms.len;
                }
            },
            Game,
            game,
        );
    }

    pub fn hms(game: &const Game) Machines {
        return Machines.initSlice(little.Little(u16), game.hms);
    }
};




pub const Gen5 = struct {
    pub const Game = gen5.Game;
    pub const BasePokemon = gen5.BasePokemon;
    pub const Evolution = common.Evolution;
    pub const PartyType = gen5.PartyType;
    pub const BaseTrainer = gen5.Trainer;
    pub const PartyMember = gen5.PartyMemberBase;
    pub const Move = gen5.Move;
    pub const LevelUpMove = gen5.LevelUpMove;
    pub const Item = gen5.Item;
    pub const Type = gen5.Type;

    pub const Pokemons = Collection(Pokemon, error{DataTooSmall});
    pub fn pokemons(game: &const Game) Pokemons {
        return Pokemons.initExternFunctionsAndContext(
            struct {
                fn at(g: &const Game, index: usize) !Pokemon {
                    const base_pokemon = try getFileAsType(BasePokemon, g.base_stats, index);
                    const level_up_moves = blk: {
                        var tmp = g.level_up_moves[index].data;
                        const res = ([]LevelUpMove)(tmp[0..tmp.len - (tmp.len % @sizeOf(LevelUpMove))]);

                        // Even though each level up move have it's own file, level up moves still
                        // end with 0xFFFF 0xFFFF.
                        for (res) |level_up_move, i| {
                            if (level_up_move.move_id.get() == 0xFFFF and level_up_move.level.get() == 0xFFFF)
                                break :blk res[0..i];
                        }

                        // In the case where we don't find the end 0xFFFF 0xFFFF, we just
                        // return the level up moves, and assume things are correct.
                        break :blk res;
                    };


                    return Pokemon {
                        .base = base_pokemon,
                        .game = g,
                        .level_up_moves = level_up_moves,
                    };
                }

                fn length(g: &const Game) usize {
                    return math.min(g.base_stats.len, g.level_up_moves.len);
                }
            },
            Game,
            game,
        );
    }

    pub const Pokemon = struct {
        base: &BasePokemon,
        game: &const Game,
        level_up_moves: []LevelUpMove,

        pub const LevelUpMoves = Collection(&LevelUpMove, error{});
        pub fn levelUpMoves(pokemon: &const Pokemon) LevelUpMoves {
            return LevelUpMoves.initSlice(LevelUpMove, pokemon.level_up_moves);
        }

        pub const Learnset = Collection(bool, error{});
        pub fn tmLearnset(pokemon: &const Pokemon) Learnset {
            return Learnset.initExternFunctionsAndContext(
                struct {
                    fn at(p: &const Pokemon, index: usize) (error{}!bool) {
                        debug.assert(index < length(p));
                        if (index < p.game.tms1.len) {
                            return bits.get(u128, p.base.tm_hm_learnset.get(), u7(index));
                        }

                        return bits.get(u128, p.base.tm_hm_learnset.get(), u7(p.game.hms.len + index));
                    }

                    fn length(p: &const Pokemon) usize {
                        return p.game.tms1.len + p.game.tms2.len;
                    }
                },
                Pokemon,
                pokemon
            );
        }

        pub fn hmLearnset(pokemon: &const Pokemon) Learnset {
            return Learnset.initExternFunctionsAndContext(
                struct {
                    fn at(p: &const Pokemon, index: usize) (error{}!bool) {
                        debug.assert(index < length(p));
                        return bits.get(u128, p.base.tm_hm_learnset.get(), u7(p.game.tms1.len + index));
                    }

                    fn length(p: &const Pokemon) usize {
                        return p.game.hms.len;
                    }
                },
                Pokemon,
                pokemon
            );
        }
    };

    pub const Trainers = Collection(Trainer, error{DataTooSmall,InvalidPartyType,InvalidPartySize});
    pub fn trainers(game: &const Game) Trainers {
        return Trainers.initExternFunctionsAndContext(
            struct {
                fn at(g: &const Game, index: usize) !Trainer {
                    const trainer = try getFileAsType(BaseTrainer, g.trainer_data, index);
                    const party = g.trainer_pokemons[index].data;

                    const data = switch (trainer.party_type) {
                        PartyType.Standard  => try partyMemberData(gen5.PartyMemberBase,      party, trainer.party_size),
                        PartyType.WithMoves => try partyMemberData(gen5.PartyMemberWithMoves, party, trainer.party_size),
                        PartyType.WithHeld  => try partyMemberData(gen5.PartyMemberWithHeld,  party, trainer.party_size),
                        PartyType.WithBoth  => try partyMemberData(gen5.PartyMemberWithBoth,  party, trainer.party_size),
                        else => return error.InvalidPartyType,
                    };

                    return Trainer { .base = trainer, .party_data = data };
                }

                fn length(g: &const Game) usize {
                    return math.min(g.trainer_data.len, g.trainer_pokemons.len);
                }

                fn partyMemberData(comptime Member: type, data: []u8, size: usize) ![]u8 {
                    const byte_size = size * @sizeOf(Member);
                    if (data.len < byte_size) return error.InvalidPartySize;

                    return data[0..byte_size];
                }
            },
            Game,
            game,
        );
    }

    pub const Trainer = struct {
        base: &BaseTrainer,
        party_data: []u8,

        pub const PartyMembers = Collection(&PartyMember, error{});
        pub fn party(trainer: &const Trainer) PartyMembers {
            return PartyMembers.initExternFunctionsAndContext(
                struct {
                    fn at(t: &const Trainer, index: usize) (error{}!&PartyMember) {
                        return switch (t.base.party_type) {
                            PartyType.Standard  => basePartyMember(gen5.PartyMemberBase,      t.party_data, index),
                            PartyType.WithMoves => basePartyMember(gen5.PartyMemberWithMoves, t.party_data, index),
                            PartyType.WithHeld  => basePartyMember(gen5.PartyMemberWithHeld,  t.party_data, index),
                            PartyType.WithBoth  => basePartyMember(gen5.PartyMemberWithBoth,  t.party_data, index),
                            else => unreachable,
                        };
                    }

                    fn length(t: &const Trainer) usize {
                        return t.base.party_size;
                    }

                    fn basePartyMember(comptime TMember: type, data: []u8, index: usize) &PartyMember {
                        const member = &([]TMember)(data)[index];
                        return if (TMember == PartyMember) member else &member.base;
                    }
                },
                Trainer,
                trainer,
            );
        }
    };

    const Moves = Collection(&Move, error{DataTooSmall});
    pub fn moves(game: &const Game) Moves {
        return Moves.initExternFunctionsAndContext(
            struct {
                fn at(m: &const []const &nds.fs.Narc.File, index: usize) !&Move {
                    return try getFileAsType(Move, m.*, index);
                }

                fn length(m: &const []const &nds.fs.Narc.File) usize {
                    return m.len;
                }
            },
            []const &nds.fs.Narc.File,
            game.moves,
        );
    }

    const Machines = Collection(&little.Little(u16), error{});
    pub fn tms(game: &const Game) Machines {
        return Machines.initExternFunctionsAndContext(
            struct {
                fn at(g: &const Game, index: usize) (error{}!&little.Little(u16)) {
                    debug.assert(index < g.tms1.len + g.tms2.len);
                    if (index < g.tms1.len)
                        return &g.tms1[index];

                    return &g.tms2[index - g.tms1.len];
                }

                fn length(g: &const Game) usize {
                    return g.tms1.len + g.tms2.len;
                }
            },
            Game,
            game,
        );
    }

    pub fn hms(game: &const Game) Machines {
        return Machines.initSlice(little.Little(u16), game.hms);
    }
};


fn getFileAsType(comptime T: type, files: []const &nds.fs.Narc.File, index: usize) !&T {
    const data = generic.widenTrim(files[index].data, T);
    return generic.at(data, 0) catch error.DataTooSmall;
}
