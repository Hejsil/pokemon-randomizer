pub const common = @import("common.zig");
pub const gen3   = @import("gen3.zig");
pub const gen5   = @import("gen5.zig");

const std    = @import("std");
const utils  = @import("../utils/index.zig");
const little = @import("../little.zig");
const bits   = @import("../bits.zig");

const math = std.math;
const debug = std.debug;

test "pokemon" {
    _ = @import("common.zig");
    _ = @import("gen3.zig");
    _ = @import("gen5.zig");
}

pub const Gen3 = struct {
    pub const Game = gen3.Game;
    pub const BasePokemon = gen3.BasePokemon;
    pub const EvolutionType = gen3.EvolutionType;
    pub const Evolution = gen3.Evolution;
    pub const PartyType = gen3.PartyType;
    pub const BaseTrainer = gen3.Trainer;
    pub const PartyMember = gen3.PartyMemberBase;
    pub const Move = gen3.Move;
    pub const LevelUpMove = gen3.LevelUpMove;
    pub const Item = gen3.Item;
    pub const Type = gen3.Type;

    pub const Pokemons = Collection(Pokemon, error{InvalidOffset});
    pub fn pokemons(game: &const Game) Pokemons {
        return Pokemons.initExternFunctionsAndContext(
            struct {
                fn at(g: &const Game, index: usize) !Pokemon {
                    const base_pokemons = g.base_stats;
                    const offset = blk: {
                        const res = utils.slice.atOrNull(g.level_up_learnset_pointers, index) ?? return error.InvalidOffset;
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
                        .level_up_moves = ([]LevelUpMove)(g.data[offset..end]),
                        .learnset = utils.slice.ptrAtOrNull(g.tm_hm_learnset, index) ?? return error.InvalidOffset,
                        .tm_count = g.tms.len,
                        .hm_count = g.hms.len,
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
        level_up_moves: []LevelUpMove,
        learnset: &little.Little(u64),
        tm_count: usize,
        hm_count: usize,

        pub const LevelUpMoves = Collection(&LevelUpMove, error{});
        pub fn levelUpMoves(pokemon: &const Pokemon) LevelUpMoves {
            return LevelUpMoves.initSlice(LevelUpMove, pokemon.level_up_moves);
        }

        pub const Learnset = Collection(bool, error{});
        pub fn tmLearnset(pokemon: &const Pokemon) Learnset {
            return Learnset.initExternFunctionsAndContext(
                struct {
                    fn at(p: &const Pokemon, index: usize) (error{}!bool) {
                        debug.assert(index < p.tm_count);
                        return bits.get(u64, p.learnset.get(), u6(index));
                    }

                    fn length(p: &const Pokemon) usize {
                        return p.tm_count;
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
                        debug.assert(index <= p.hm_count);
                        return bits.get(u64, p.learnset.get(), u6(p.tm_count + index));
                    }

                    fn length(p: &const Pokemon) usize {
                        return p.hm_count;
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

pub fn Collection(comptime Item: type, comptime Errors: type) type {
    const VTable = struct {
        const Self = this;

        at: fn(&const u8, usize) Errors!Item,
        length: fn(&const u8) usize,

        fn init(comptime Functions: type, comptime Context: type) Self {
            return Self {
                .at = struct {
                    fn at(d: &const u8, i: usize) Errors!Item {
                        return Functions.at(cast(Context, d), i);
                    }
                }.at,

                .length = struct {
                    fn length(d: &const u8) usize {
                        return Functions.length(cast(Context, d));
                    }
                }.length,
            };
        }

        fn cast(comptime Context: type, ptr: &const u8) &const Context {
            return @ptrCast(&const Context, @alignCast(@alignOf(Context), ptr));
        }
    };

    return struct {
        const Self = this;

        data: &const u8,
        vtable: &const VTable,

        pub fn initContext(context: var) Self {
            return initExternFunctionsAndContext(@TypeOf(*context), @TypeOf(*context), context);
        }

        pub fn initSlice(comptime T: type, slice: &const []T) Self {
            return initExternFunctionsAndContext(
                struct {
                    fn at(s: &const []T, index: usize) (Errors!&T) { return &(*s)[index]; }
                    fn length(s: &const []T) usize { return s.len; }
                },
                []T, slice);
        }

        pub fn initSliceConst(comptime T: type, slice: &const []const T) Self {
            return initExternFunctionsAndContext(
                struct {
                    fn at(s: []const T, index: usize) (Errors!&const T) { return &s[index]; }
                    fn length(s: []T) usize { return s.len; }
                },
                []const T, slice);
        }

        pub fn initExternFunctionsAndContext(comptime Functions: type, comptime Context: type, context: &const Context) Self {
            return Self {
                .data = @ptrCast(&const u8, context),
                .vtable = &comptime VTable.init(Functions, Context),
            };
        }

        pub fn at(coll: &const Self, index: usize) Errors!Item {
            return coll.vtable.at(coll.data, index);
        }

        pub fn length(coll: &const Self) usize {
            return coll.vtable.length(coll.data);
        }

        pub fn iterator(coll: &const Self) Iterator {
            return Iterator {
                .current = 0,
                .collection = coll,
            };
        }

        const Iterator = struct {
            current: usize,
            collection: &const Self,

            const Pair = struct {
                value: Item,
                index: usize,
            };

            pub fn next(it: &Iterator) ?Pair {
                while (true) {
                    const res = it.nextWithErrors() catch continue;
                    return res;
                }
            }

            pub fn nextWithErrors(it: &Iterator) Errors!?Pair {
                const l = it.collection.length();
                if (l <= it.current) return null;

                defer it.current += 1;
                return Pair {
                    .value = try it.collection.at(it.current),
                    .index = it.current,
                };
            }
        };
    };
}
