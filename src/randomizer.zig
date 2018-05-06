const std     = @import("std");
const bits    = @import("bits.zig");
const little = @import("little.zig");

const math  = std.math;
const mem   = std.mem;
const rand  = std.rand;
const debug = std.debug;

const common = @import("pokemon/index.zig").common;
const gen3   = @import("pokemon/index.zig").gen3;
const gen5   = @import("pokemon/index.zig").gen5;

const Little = little.Little;

const assert = debug.assert;

/// A generic enum for different randomization options.
pub const GenericOption = enum {
    Same,
    Random,
    Best
};

pub const Options = struct {
    pub const Trainer = struct {
        pub const Pokemon = enum {
            /// Trainers Pokémon wont be randomized.
            Same,

            /// Each trainer will be given random Pokémons.
            Random,

            /// Trainer Pokémon will be replaced with a random one of the same
            /// type. For dual typing, the replacement ratio is 80% primary,
            /// 20% secondary.
            SameType,

            /// Each trainer will have a type trainer_theme, and will be given random
            /// Pokémons from that type.
            TypeThemed,

            /// All trainers will be given only random legendary Pokémons
            Legendaries,
        };

        pub const HeldItems = enum {
            /// Trainer Pokémons will have no held items.
            None,

            /// Trainer Pokémon held items will not change.
            Same,

            // TODO: Figure out how to implement these:
            /// Trainer Pokémons will have random held items.
            //Random,

            /// Trainer Pokémons will have random, but useful, held items.
            //RandomUseful,

            /// Trainer Pokémons will hold the best held items in the game.
            //RandomBest,
        };

        pub const Moves = enum {
            /// Trainer Pokémon moves will not change.
            Same,

            /// If possible, Trainer Pokémon will have random moves.
            Random,

            /// If possible, Trainer Pokémon will have random moves selected from
            /// the pool of moves the Pokémon can already learn.
            RandomWithinLearnset,

            /// If possible, Trainer Pokémon will be given the most powerful moves
            /// they can learn.
            Best,
        };

        /// The the way trainers Pokémons should be randomized.
        pokemon: Pokemon,

        /// Trainer Pokémons will be replaced by once of simular strength (base on
        /// Pokémon's base stats).
        same_total_stats: bool,

        /// Which held items each trainer Pokémon will be given.
        held_items: HeldItems,

        /// Which moves each trainer Pokémon will be given.
        moves: Moves,

        /// How the trainer Pokémon ivs should be randomized.
        iv: GenericOption,

        /// Trainer Pokémons will have their level increased by x%.
        level_modifier: f64,

        pub fn default() Trainer {
            return Trainer {
                .pokemon = Pokemon.Same,
                .same_total_stats = false,
                .held_items = HeldItems.Same,
                .moves = Moves.Same,
                .iv = GenericOption.Same,
                .level_modifier = 1.0,
            };
        }
    };

    trainer: Trainer,

    pub fn default() Options {
        return Options {
            .trainer = Trainer.default(),
        };
    }
};

pub fn Randomizer(comptime Gen: type) type {
    return struct {
        const Self = this;
        const Game = Gen.Game;
        const BasePokemon = Gen.BasePokemon;
        const Type = Gen.Type;
        const PartyMember = Gen.PartyMember;

        fn hash_type(t: Type) u32 { return @TagType(Type)(t); }
        fn type_eql(t1: Type, t2: Type) bool { return t1 == t2; }
        const SpeciesByType = std.HashMap(Type, std.ArrayList(u16), hash_type, type_eql);

        game: &const Game,
        random: &rand.Random,
        allocator: &mem.Allocator,
        species_by_type: ?SpeciesByType,

        pub fn init(game: &const Game, random: &rand.Random, allocator: &mem.Allocator) Self {
            return Self {
                .game = game,
                .allocator = allocator,
                .random = random,
                .species_by_type = null,
            };
        }

        pub fn deinit(randomizer: &Self) void {
            if (randomizer.species_by_type) |*by_type| {
                freeSpeciesByType(by_type);
            }
        }

        pub fn randomize(randomizer: &Self, options: &const Options) !void {
            try randomizer.randomizeTrainers(options.trainer);
        }

        pub fn randomizeTrainers(randomizer: &Self, options: &const Options.Trainer) !void {
            const game = randomizer.game;
            var by_type = try randomizer.speciesByType();

            const pokemons = Gen.pokemons(game);
            const trainers = Gen.trainers(game);

            var trainer_it = trainers.iterator();
            while (trainer_it.next()) |trainer_item| {
                const trainer = trainer_item.value;
                const trainer_theme = switch (options.pokemon) {
                    Options.Trainer.Pokemon.TypeThemed => randomizer.randomType(),
                    else => null,
                };

                const party = trainer.party();
                var party_it = party.iterator();

                while (party_it.next()) |party_item| {
                    const trainer_pokemon = party_item.value;
                    // HACK: TODO: Remove this when https://github.com/zig-lang/zig/issues/649 is a thing
                    const curr_pokemon = try pokemons.at(toInt(trainer_pokemon.species));
                    switch (options.pokemon) {
                        Options.Trainer.Pokemon.Same => {},
                        Options.Trainer.Pokemon.Random => {
                            // TODO: Types probably shouldn't be weighted equally, as
                            //       there is a different number of Pokémons per type.
                            // TODO: If a Pokémon is dual type, it has a higher chance of
                            //       being chosen. I think?
                            const pokemon_type = randomizer.randomType();
                            const pick_form = (??by_type.get(pokemon_type)).value.toSliceConst();
                            const new_pokemon = try randomizer.randomTrainerPokemon(curr_pokemon.base, options.same_total_stats, pick_form);
                            // HACK: TODO: Remove this when https://github.com/zig-lang/zig/issues/649 is a thing
                            trainer_pokemon.species = toLittle(@typeOf(trainer_pokemon.species), new_pokemon);
                        },
                        Options.Trainer.Pokemon.SameType => {
                            const pokemon_type = blk: {
                                const roll = randomizer.random.float(f32);
                                break :blk if (roll < 0.80) curr_pokemon.base.types[0] else curr_pokemon.base.types[1];
                            };

                            const pick_form = (??by_type.get(pokemon_type)).value.toSliceConst();
                            const new_pokemon = try randomizer.randomTrainerPokemon(curr_pokemon.base, options.same_total_stats, pick_form);
                            // HACK: TODO: Remove this when https://github.com/zig-lang/zig/issues/649 is a thing
                            trainer_pokemon.species = toLittle(@typeOf(trainer_pokemon.species), new_pokemon);
                        },
                        Options.Trainer.Pokemon.TypeThemed => {
                            const pick_form = (??by_type.get(??trainer_theme)).value.toSliceConst();
                            const new_pokemon = try randomizer.randomTrainerPokemon(curr_pokemon.base, options.same_total_stats, pick_form);
                            // HACK: TODO: Remove this when https://github.com/zig-lang/zig/issues/649 is a thing
                            trainer_pokemon.species = toLittle(@typeOf(trainer_pokemon.species), new_pokemon);
                        },
                        Options.Trainer.Pokemon.Legendaries => {
                            const new_pokemon = try randomizer.randomTrainerPokemon(curr_pokemon.base, options.same_total_stats, Game.legendaries);
                            // HACK: TODO: Remove this when https://github.com/zig-lang/zig/issues/649 is a thing
                            trainer_pokemon.species = toLittle(@typeOf(trainer_pokemon.species), new_pokemon);
                        }
                    }

                    switch (Game) {
                        gen3.Game => {
                            switch (trainer.base.party_type) {
                                gen3.PartyType.WithHeld => {
                                    const member = @fieldParentPtr(gen3.PartyMemberWithHeld, "base", trainer_pokemon);
                                    randomizer.randomizeTrainerPokemonHeldItem(member, options.held_items);
                                },
                                gen3.PartyType.WithMoves => {
                                    const member = @fieldParentPtr(gen3.PartyMemberWithMoves, "base", trainer_pokemon);
                                    try randomizer.randomizeTrainerPokemonMoves(member, options);
                                },
                                gen3.PartyType.WithBoth => {
                                    const member = @fieldParentPtr(gen3.PartyMemberWithBoth, "base", trainer_pokemon);
                                    randomizer.randomizeTrainerPokemonHeldItem(member, options.held_items);
                                    try randomizer.randomizeTrainerPokemonMoves(member, options);
                                },
                                else => {}
                            }
                        },
                        gen5.Game => {
                            switch (trainer.base.party_type) {
                                gen5.PartyType.WithHeld => {
                                    const member = @fieldParentPtr(gen5.PartyMemberWithHeld, "base", trainer_pokemon);
                                    randomizer.randomizeTrainerPokemonHeldItem(member, options.held_items);
                                },
                                gen5.PartyType.WithMoves => {
                                    const member = @fieldParentPtr(gen5.PartyMemberWithMoves, "base", trainer_pokemon);
                                    try randomizer.randomizeTrainerPokemonMoves(member, options);
                                },
                                gen5.PartyType.WithBoth => {
                                    const member = @fieldParentPtr(gen5.PartyMemberWithBoth, "base", trainer_pokemon);
                                    randomizer.randomizeTrainerPokemonHeldItem(member, options.held_items);
                                    try randomizer.randomizeTrainerPokemonMoves(member, options);
                                },
                                else => {}
                            }
                        },
                        else => comptime unreachable,
                    }

                    const IvType = @IntType(false, @sizeOf(@typeOf(trainer_pokemon.iv)) * 8);
                    const iv_max = @maxValue(IvType);
                    switch (options.iv) {
                        GenericOption.Same => {},
                        GenericOption.Random => trainer_pokemon.iv = toLittle(@typeOf(trainer_pokemon.iv), randomizer.random.range(IvType, 0, iv_max)),
                        GenericOption.Best => trainer_pokemon.iv = toLittle(@typeOf(trainer_pokemon.iv), iv_max),
                    }

                    const new_level = blk: {
                        // HACK: TODO: Remove this when https://github.com/zig-lang/zig/issues/649 is a thing
                        var res = f64(toInt(trainer_pokemon.level)) * options.level_modifier;
                        res = math.min(res, f64(100));
                        res = math.max(res, f64(1));
                        break :blk u8(math.round(res));
                    };
                    trainer_pokemon.level = toLittle(@typeOf(trainer_pokemon.level), new_level);
                }
            }
        }

        fn randomTrainerPokemon(randomizer: &Self, curr_pokemom: &const BasePokemon, same_total_stats: bool, pick_from: []const u16) !u16 {
            const game = randomizer.game;
            const pokemons = Gen.pokemons(game);

            if (same_total_stats) {
                var min_total = totalStats(curr_pokemom);
                var max_total = min_total;
                var matches = std.ArrayList(u16).init(randomizer.allocator);
                defer matches.deinit();

                // If we dont get 25 matches on the first try, we just loop again. This means matches
                // will end up collecting some duplicates. This is fine, as this makes it soo that
                // Pokémon that are a better match, have a higher chance of being picked.
                while (matches.len < 25) {
                    min_total = math.sub(u16, min_total, 5) catch min_total;
                    max_total = math.add(u16, max_total, 5) catch max_total;

                    for (pick_from) |species| {
                        const pokemon = try pokemons.at(species);
                        const total = totalStats(pokemon.base);
                        if (min_total <= total and total <= max_total)
                            try matches.append(species);
                    }
                }

                return matches.toSlice()[randomizer.random.range(usize, 0, matches.len)];
            } else {
                return pick_from[randomizer.random.range(usize, 0, pick_from.len)];
            }
        }

        fn randomizeTrainerPokemonHeldItem(randomizer: &const Self, trainer_pokemon: var, option: Options.Trainer.HeldItems) void {
            const game = randomizer.game;
            switch (option) {
                Options.Trainer.HeldItems.None => {
                    trainer_pokemon.held_item.set(0);
                },
                Options.Trainer.HeldItems.Same => {},
                //Options.Trainer.HeldItems.Random => {
                //    // TODO:
                //},
                //Options.Trainer.HeldItems.RandomUseful => {
                //    // TODO:
                //},
                //Options.Trainer.HeldItems.RandomBest => {
                //    // TODO:
                //},
            }
        }

        fn randomizeTrainerPokemonMoves(randomizer: &Self, trainer_pokemon: var, option: &const Options.Trainer) !void {
            const pokemons = Gen.pokemons(randomizer.game);
            switch (option.moves) {
                Options.Trainer.Moves.Same => {
                    // If trainer Pokémons where randomized, then keeping the same moves
                    // makes no sense. We therefor reset them to something sensible.
                    if (option.pokemon != Options.Trainer.Pokemon.Same) {
                        const MoveLevelPair = struct { level: u8, move_id: u16 };
                        const new_moves = blk: {
                            const pokemon = try pokemons.at(trainer_pokemon.base.species.get());
                            const level_up_moves = pokemon.levelUpMoves();
                            var it = level_up_moves.iterator();
                            var moves = []MoveLevelPair { MoveLevelPair { .level = 0, .move_id = 0, } } ** 4;

                            while (it.next()) |item| {
                                const level_up_move = item.value;
                                for (moves) |*move| {
                                    // HACK: TODO: Remove this when https://github.com/zig-lang/zig/issues/649 is a thing
                                    const move_level = toInt(level_up_move.level);
                                    const trainer_pkm_level = u8(toInt(trainer_pokemon.base.level));
                                    if (move.level < move_level and move_level < trainer_pkm_level) {
                                        move.level = u8(move_level);
                                        move.move_id = u16(toInt(level_up_move.move_id));
                                        break;
                                    }
                                }
                            }

                            break :blk moves;
                        };

                        assert(new_moves.len == trainer_pokemon.moves.len);
                        for (trainer_pokemon.moves) |_, i| {
                            trainer_pokemon.moves[i].set(new_moves[i].move_id);
                        }
                    }
                },
                Options.Trainer.Moves.Random => {
                    for (trainer_pokemon.moves) |*move| {
                        move.set(randomizer.randomMoveId());
                    }
                },
                Options.Trainer.Moves.RandomWithinLearnset => {
                    const learned_moves = try randomizer.movesLearned(trainer_pokemon.base.species.get());
                    defer randomizer.allocator.free(learned_moves);

                    for (trainer_pokemon.moves) |*move| {
                        const pick = learned_moves[randomizer.random.range(usize, 0, learned_moves.len)];
                        move.set(pick);
                    }
                },
                Options.Trainer.Moves.Best => {
                    const moves = Gen.moves(randomizer.game);
                    const pokemon = try pokemons.at(trainer_pokemon.base.species.get());
                    const learned_moves = try randomizer.movesLearned(trainer_pokemon.base.species.get());
                    defer randomizer.allocator.free(learned_moves);

                    for (trainer_pokemon.moves) |*move|
                        move.set(0);

                    for (learned_moves) |learned| {
                        const learned_move = try moves.at(learned);

                        pokemon_moves_loop:
                        for (trainer_pokemon.moves) |*move_id| {
                            const move = try moves.at(move_id.get());

                            // TODO: Rewrite to work with Pokémons that can have N types
                            const move_stab    = if (move.@"type"         == pokemon.base.types[0] or move.@"type"         == pokemon.base.types[1]) f32(1.5) else f32(1.0);
                            const learned_stab = if (learned_move.@"type" == pokemon.base.types[0] or learned_move.@"type" == pokemon.base.types[1]) f32(1.5) else f32(1.0);
                            const move_power    = f32(move.power) * move_stab;
                            const learned_power = f32(learned_move.power) * learned_stab;

                            // TODO: We probably also want Pokémons to have varied types
                            //       of moves, so it has good coverage.
                            // TODO: We probably want to pick attack vs sp_attack moves
                            //       depending on the Pokémons stats.
                            if (move_power < learned_power) {
                                move_id.set(learned);
                                break :pokemon_moves_loop;
                            }
                        }
                    }
                },
            }
        }

        fn totalStats(pokemon: &const BasePokemon) u16 {
            return
                u16(pokemon.hp)        +
                u16(pokemon.attack)    +
                u16(pokemon.defense)   +
                u16(pokemon.speed)     +
                u16(pokemon.sp_attack) +
                u16(pokemon.sp_defense);
        }

        fn randomType(randomizer: &Self) Type {
            const choice = randomizer.random.range(u8, 0, @memberCount(Type));
            comptime var i = 0;
            inline while (i < @memberCount(Type)) : (i += 1) {
                if (i == choice) return @field(Type, @memberName(Type, i));
            }

            unreachable;
        }

        fn randomMoveId(randomizer: &Self) u16 {
            const moves = Gen.moves(randomizer.game);
            while (true) {
                const move_id = randomizer.random.range(u16, 0, u16(moves.length()));

                // We assume, that if the id is between 0..len, then we'll never get null from this function.
                const move = moves.at(move_id) catch unreachable;

                // A move with 0 pp is useless, so we will assume it's a dummy move.
                if (move.pp == 0) continue;
                return move_id;
            }
        }

        /// Caller owns memory returned
        fn movesLearned(randomizer: &const Self, species: u16) ![]u16 {
            const game = randomizer.game;
            const pokemons = Gen.pokemons(game);
            const pokemon = try pokemons.at(species);
            const levelup_learnset = pokemon.levelUpMoves();
            const tm_learnset = pokemon.tmLearnset();
            const hm_learnset = pokemon.hmLearnset();
            const tms = Gen.tms(game);
            const hms = Gen.hms(game);

            var res = std.ArrayList(u16).init(randomizer.allocator);
            try res.ensureCapacity(levelup_learnset.length());

            var lvl_it = levelup_learnset.iterator();
            while (lvl_it.next()) |item| {
                // HACK: TODO: Remove this when https://github.com/zig-lang/zig/issues/649 is a thing
                try res.append(toInt(item.value.move_id));
            }

            var tm_learnset_it = tm_learnset.iterator();
            while (tm_learnset_it.next()) |item| {
                if (item.value) {
                    const move_id = try tms.at(item.index);
                    try res.append(move_id.get());
                }
            }

            var hm_learnset_it = hm_learnset.iterator();
            while (hm_learnset_it.next()) |item| {
                if (item.value) {
                    const move_id = try hms.at(item.index);
                    try res.append(move_id.get());
                }
            }

            return res.toOwnedSlice();
        }

        fn speciesByType(randomizer: &Self) !&SpeciesByType {
            if (randomizer.species_by_type) |*species_by_type| return species_by_type;

            var species_by_type = SpeciesByType.init(randomizer.allocator);
            errdefer freeSpeciesByType(&species_by_type);

            comptime var i = 0;
            inline while (i < @memberCount(Type)) : (i += 1) {
                const t = @field(Type, @memberName(Type, i));
                const should_be_null = try species_by_type.put(t, std.ArrayList(u16).init(randomizer.allocator));
                // This loop should only insert unique keys. If this is not the case, we have a bug somewhere.
                if (should_be_null) |_| unreachable;
            }

            const pokemons = Gen.pokemons(randomizer.game);
            var it = pokemons.iterator();
            while (it.next()) |item| {
                const pokemon = item.value;
                const species = item.index;

                // Asume that Pokémons with 0 hp are dummy Pokémon
                if (pokemon.base.hp == 0) continue;

                for (pokemon.base.types) |t| {
                    const entry = species_by_type.get(t) ?? continue;
                    try entry.value.append(u16(species));
                }
            }

            randomizer.species_by_type = species_by_type;
            return &??randomizer.species_by_type;
        }

        fn freeSpeciesByType(by_type: &SpeciesByType) void {
            var it = by_type.iterator();
            while (it.next()) |entry|
                entry.value.deinit();

            by_type.deinit();
        }
    };
}

fn Value(comptime T: type) type {
    if (@typeId(T) == builtin.TypeId.Pointer) {
        return T.Child;
    } else {
        return T;
    }
}

const builtin = @import("builtin");
fn toInt(value: var) @IntType(false, @sizeOf(Value(@typeOf(value))) * 8) {
    const T = Value(@typeOf(value));
    if (@typeId(T) == builtin.TypeId.Int) {
        return value;
    } else if (Little(T.Base) == T) {
        return value.get();
    }

    comptime unreachable;
}

fn toLittle(comptime T: type, int: var) T {
    if (@typeId(T) == builtin.TypeId.Int) {
        return T(int);
    } else if (Little(T.Base) == T) {
        return Little(T.Base).init(int);
    }

    comptime unreachable;
}
