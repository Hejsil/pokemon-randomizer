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
    pub const Trainer = gen3.Trainer;
    pub const PartyMember = gen3.PartyMemberBase;
    pub const Move = gen3.Move;
    pub const LevelUpMove = gen3.LevelUpMove;
    pub const Item = gen3.Item;
    pub const Type = gen3.Type;

    pub fn basePokemons(game: &const Game) BasePokemonCollection {
        return BasePokemonCollection.init(game.base_stats);
    }

    pub fn trainers(game: &const Game) TrainerCollection {
        return TrainerCollection.init(game.trainers);
    }

    pub fn party(game: &const Game, trainer: &const Trainer) !PartyMemberCollection {
        const offset = math.sub(usize, trainer.party_offset.get(), 0x8000000) catch return error.InvalidOffset;

        const data = switch (trainer.party_type) {
            PartyType.Standard =>  try partyMemberData(gen3.PartyMember,          game.data, offset, trainer.party_size.get()),
            PartyType.WithMoves => try partyMemberData(gen3.PartyMemberWithMoves, game.data, offset, trainer.party_size.get()),
            PartyType.WithHeld =>  try partyMemberData(gen3.PartyMemberWithHeld,  game.data, offset, trainer.party_size.get()),
            PartyType.WithBoth =>  try partyMemberData(gen3.PartyMemberWithBoth,  game.data, offset, trainer.party_size.get()),
            else => return error.InvalidPartyType,
        };

        return PartyMemberCollection.init(PartyMemberContext { .data = data, .trainer = trainer });
    }

    pub fn moves(game: &const Game) MoveCollection {
        return MoveCollection.init(game.moves);
    }

    pub fn levelUpMoves(game: &const Game, species: usize) !LevelUpMoveCollection {
        const offset = blk: {
            const res = utils.slice.atOrNull(game.level_up_learnset_pointers, species) ?? return error.InvalidSpecies;
            if (res.get() < 0x8000000) return error.InvalidOffset;
            break :blk res.get() - 0x8000000;
        };
        if (game.data.len < offset) return error.InvalidOffset;

        const end = blk: {
            var i : usize = offset;
            while (true) : (i += @sizeOf(LevelUpMove)) {
                if (game.data.len < i)     return error.InvalidOffset;
                if (game.data.len < i + 1) return error.InvalidOffset;
                if (game.data[i] == 0xFF and game.data[i+1] == 0xFF) break;
            }

            break :blk i;
        };

        return LevelUpMoveCollection.init(([]LevelUpMove)(game.data[offset..end]));
    }

    pub fn tms(game: &const Game) MachineCollection {
        return MachineCollection.init(game.tms);
    }

    pub fn hms(game: &const Game) MachineCollection {
        return MachineCollection.init(game.hms);
    }

    pub fn tmLearnset(game: &const Game, species: usize) !LearnsetCollection {
        const learnset = utils.slice.atOrNull(game.tm_hm_learnset, species) ?? return error.OutOfBound;
        return LearnsetCollection.init(LearnsetContext { .offset = 0, .count = game.tms.len, .learnset = learnset });
    }

    pub fn hmLearnset(game: &const Game, species: usize) !LearnsetCollection {
        const learnset = utils.slice.atOrNull(game.tm_hm_learnset, species) ?? return error.OutOfBound;
        return LearnsetCollection.init(LearnsetContext { .offset = game.tms.len, .count = game.hms.len, .learnset = learnset });
    }

    const BasePokemonCollection = SliceCollection([]BasePokemon);
    const TrainerCollection = SliceCollection([]Trainer);
    const PartyMemberCollection = Collection(
        PartyMemberContext,
        struct {
            fn at(context: &const PartyMemberContext, index: usize) (error{}!&PartyMember) {
                const trainer = context.trainer;
                const data = context.data;

                return switch (trainer.party_type) {
                    PartyType.Standard =>  basePartyMember(gen3.PartyMember,          data, index),
                    PartyType.WithMoves => basePartyMember(gen3.PartyMemberWithMoves, data, index),
                    PartyType.WithHeld =>  basePartyMember(gen3.PartyMemberWithHeld,  data, index),
                    PartyType.WithBoth =>  basePartyMember(gen3.PartyMemberWithBoth,  data, index),
                    else => unreachable,
                };
            }

            fn count(context: &const PartyMemberContext) usize {
                return context.trainer.party_size.get();
            }
        }
    );

    const PartyMemberContext = struct {
        data: []u8,
        trainer: &const Trainer,
    };

    fn basePartyMember(comptime TMember: type, data: []u8, index: usize) &PartyMember {
        const p = ([]TMember)(data);
        return &p[index].base;
    }

    fn partyMemberData(comptime Member: type, data: []u8, offset: usize, size: usize) ![]u8 {
        const end = offset + size * @sizeOf(Member);
        if (data.len < end) return error.InvalidOffset;

        return data[offset..end];
    }

    const MoveCollection = SliceCollection([]Move);
    const LevelUpMoveCollection = SliceCollection([]LevelUpMove);
    const MachineCollection = SliceCollection([]little.Little(u16));
    const LearnsetCollection = Collection(
        LearnsetContext,
        struct {
            fn at(context: &const LearnsetContext, index: usize) (error{}!bool) {
                debug.assert(context.count <= context.offset + index);
                return bits.get(u64, context.learnset.get(), u6(context.offset + index));
            }

            fn count(context: &const LearnsetContext) usize {
                return context.count;
            }
        }
    );

    const LearnsetContext = struct {
        offset: usize,
        count: usize,
        learnset: little.Little(u64),
    };
};

pub fn Collection(
    comptime Context: type,
    comptime Functions: type) type
{
    return struct {
        const Item = @typeOf(Functions.at).ReturnType.Payload;
        const Errors = @typeOf(Functions.at).ReturnType.ErrorSet;
        const Self = this;
        context: Context,

        pub fn init(context: &const Context) Self {
            return Self { .context = *context };
        }

        pub fn at(coll: &const Self, index: usize) Errors!Item {
            return Functions.at(coll.context, index);
        }

        pub fn count(coll: &const Self) usize {
            return Functions.count(coll.context);
        }

        pub fn iterator(coll: &const Self) Iterator {
            return Iterator {
                .collection = *coll,
                .current = 0,
            };
        }

        const Iterator = struct {
            collection: Self,
            current: usize,

            pub fn next(it: &Iterator) Errors!?Item {
                if (it.collection.count() <= it.current) {
                    return null;
                }

                defer it.current += 1;
                return try it.collection.at(it.current);
            }

            pub fn nextNoError(it: &Iterator) ?Item {
                while (it.next()) |res| {
                    return res;
                } else |_| { }
            }
        };
    };
}

pub fn SliceCollection(comptime Slice: type) type {
    const Item = Slice.Child;
    comptime debug.assert(Slice == []Item or Slice == []const Item);

    return Collection(
        Slice,
        struct {
            fn at(s: &const Slice, index: usize) (error{}!&Item) { return &(*s)[index]; }
            fn count(v: &const Slice) usize { return v.len; }
        }
    );
}
