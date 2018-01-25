const std     = @import("std");
const common  = @import("pokemon/common.zig");
const gen3    = @import("pokemon/gen3.zig");

const math  = std.math;
const mem   = std.mem;
const rand  = std.rand;
const debug = std.debug;

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
        };

        pub const HeldItems = enum {
            /// Trainer Pokémons will have no held items.
            None,

            /// Trainer Pokémon held items will not change.
            Same,

            /// Trainer Pokémons will have random held items.
            Random,

            /// Trainer Pokémons will have random, but useful, held items.
            RandomUseful,

            /// Trainer Pokémons will hold the best held items in the game.
            RandomBest,
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

        /// How the trainer AI should be randomized.
        ai: GenericOption,

        /// How the trainer Pokémon ivs should be randomized.
        iv: GenericOption,

        /// How the trainer Pokémon evs should be randomized.
        ev: GenericOption,

        /// Trainer Pokémons will have their level increased by x%.
        level_modifier: f64,

        pub fn default() -> Trainer {
            return Trainer {
                .pokemon = Pokemon.Same,
                .same_total_stats = false,
                .held_items = HeldItems.Same,
                .moves = Moves.Same,
                .ai = GenericOption.Same,
                .iv = GenericOption.Same,
                .ev = GenericOption.Same,
                .level_modifier = 1.0,
            };
        }
    };

    trainer: Trainer,

    pub fn default() -> Options {
        return Options {
            .trainer = Trainer.default(),
        };
    }
};

pub fn randomize(game: var, options: &const Options, random: &rand.Rand, allocator: &mem.Allocator) -> %void {
    // TODO: When we can get the max value of enums, fix this code:
    //                     VVVVVVVVVVVVVVVVVVVVV
    var pokemons_by_type = [u8(common.Type.Fairy) + 1]std.ArrayList(u16) {
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
        std.ArrayList(u16).init(allocator),
    };
    defer {
        for (pokemons_by_type) |*list| {
            list.deinit();
        }
    }

    var pokemon_count : u16 = 0;
    while (game.getBasePokemon(pokemon_count)) |pokemon| : (pokemon_count += 1) {
        try pokemons_by_type[u8(pokemon.type1)].append(pokemon_count);
        try pokemons_by_type[u8(pokemon.type2)].append(pokemon_count);
    }

    try randomizeTrainers(game, pokemons_by_type[0..], options.trainer, random, allocator);
}

fn randomizeTrainers(game: var, pokemons_by_type: []std.ArrayList(u16), options: &const Options.Trainer, random: &rand.Rand, allocator: &mem.Allocator) -> %void {
    var trainer_id : usize = 0;
    while (game.getTrainer(trainer_id)) |trainer| : (trainer_id += 1) {
        const trainer_theme = switch (options.pokemon) {
            Options.Trainer.Pokemon.TypeThemed => randomType(@typeOf(*game), random),
            else => common.Type.Unknown,
        };

        var pokemon_index : usize = 0;
        while (game.getTrainerPokemon(trainer, pokemon_index)) |trainer_pokemon| : (pokemon_index += 1) {
            // TODO: Handle when a trainers Pokémon does not point on a valid species.
            //                                                                         VVVVVVVVVVV
            const curr_pokemon = game.getBasePokemon(trainer_pokemon.species.get()) ?? unreachable;
            switch (options.pokemon) {
                Options.Trainer.Pokemon.Same => {},
                Options.Trainer.Pokemon.Random => {
                    // TODO: Types probably shouldn't be weighted equally, as
                    //       there is a different number of Pokémons per type.
                    // TODO: If a Pokémon is dual type, it has a higher chance of
                    //       being chosen. I think?
                    const pokemon_type = randomType(@typeOf(*game), random);
                    const pokemons = pokemons_by_type[u8(pokemon_type)].toSliceConst();
                    const new_pokemon = try getRandomTrainerPokemon(game, curr_pokemon, options.same_total_stats, pokemons, random, allocator);
                    trainer_pokemon.species.set(new_pokemon);
                },
                Options.Trainer.Pokemon.SameType => {
                    const pokemon_type = blk: {
                        if (curr_pokemon.type1 == common.Type.Unknown) {
                            if (curr_pokemon.type2 == common.Type.Unknown) {
                                break :blk randomType(@typeOf(*game), random);
                            } else {
                                break :blk curr_pokemon.type2;
                            }
                        }
                        if (curr_pokemon.type2 == common.Type.Unknown)
                            break :blk randomType(@typeOf(*game), random);

                        const roll = random.float(f32);
                        break :blk if (roll < 0.80) curr_pokemon.type1 else curr_pokemon.type2;
                    };

                    const pokemons = pokemons_by_type[u8(pokemon_type)].toSliceConst();
                    const new_pokemon = try getRandomTrainerPokemon(game, curr_pokemon, options.same_total_stats, pokemons, random, allocator);
                    trainer_pokemon.species.set(new_pokemon);
                },
                Options.Trainer.Pokemon.TypeThemed => {
                    debug.assert(trainer_theme != common.Type.Unknown);
                    const pokemons = pokemons_by_type[u8(trainer_theme)].toSliceConst();
                    const new_pokemon = try getRandomTrainerPokemon(game, curr_pokemon, options.same_total_stats, pokemons, random, allocator);
                    trainer_pokemon.species.set(new_pokemon);
                },
            }

            switch (@typeOf(*game)) {
                gen3.Game => {
                    switch (trainer.party_type) {
                        gen3.PartyType.WithHeld => {
                            const member = @fieldParentPtr(gen3.PartyMemberWithHeld, "base", trainer_pokemon);
                            randomizeTrainerPokemonHeldItem(game, member, options.held_items, random);
                        },
                        gen3.PartyType.WithMoves => {
                            const member = @fieldParentPtr(gen3.PartyMemberWithMoves, "base", trainer_pokemon);
                            randomizeTrainerPokemonMoves(game, member, options, random);
                        },
                        gen3.PartyType.WithBoth => {
                            const member = @fieldParentPtr(gen3.PartyMemberWithBoth, "base", trainer_pokemon);
                            randomizeTrainerPokemonHeldItem(game, member, options.held_items, random);
                            randomizeTrainerPokemonMoves(game, member, options, random);
                        },
                        else => {}
                    }
                },
                else => unreachable,
            }

            // TODO: Figure out how we avoid the randomized Pokémons having moves they can't learn (Roxanne's Pokémons had
            //       rock tomb, after they where randomized)
            // TODO: 
            //moves: MoveSet,
            //ai: GenericOption,
            //iv: GenericOption,
            //ev: GenericOption,

            const new_level = blk: {
                var res = f64(trainer_pokemon.level.get()) * options.level_modifier;
                res = math.min(res, f64(100));
                res = math.max(res, f64(1));
                break :blk u8(math.round(res));
            };
            trainer_pokemon.level.set(new_level);
        }
    }
}

fn getRandomTrainerPokemon(game: var, curr_pokemom: var, same_total_stats: bool, pokemons: []const u16, random: &rand.Rand, allocator: &mem.Allocator) -> %u16 {
    if (same_total_stats) {
        var min_total = totalStats(curr_pokemom);
        var max_total = min_total;
        var matches = std.ArrayList(u16).init(allocator);
        defer matches.deinit();

        // If we dont get 25 matches on the first try, we just loop again. This means matches
        // will end up collecting some duplicates. This is fine, as this makes it soo that
        // Pokémon that are a better match, have a higher chance of being picked.
        while (matches.len < 25) {
            min_total = math.sub(u16, min_total, 5) catch min_total;
            max_total = math.add(u16, max_total, 5) catch max_total;

            for (pokemons) |pokemon_id| {
                const pokemon = game.getBasePokemon(pokemon_id) ?? unreachable; // TODO: FIX
                const total = totalStats(pokemon);
                if (min_total <= total and total <= max_total)
                    try matches.append(pokemon_id);
            }
        }

        return matches.toSlice()[random.range(usize, 0, matches.len)];
    } else {
        return pokemons[random.range(usize, 0, pokemons.len)];
    }
}

fn randomizeTrainerPokemonHeldItem(game: var, pokemon: var, option: Options.Trainer.HeldItems, random: &rand.Rand) -> void {
    switch (option) {
        Options.Trainer.HeldItems.None => {
            pokemon.held_item.set(0);
        },
        Options.Trainer.HeldItems.Same => {},
        Options.Trainer.HeldItems.Random => {
            // TODO:
        },
        Options.Trainer.HeldItems.RandomUseful => {
            // TODO:
        },
        Options.Trainer.HeldItems.RandomBest => {
            // TODO:
        },
    }
}

fn randomizeTrainerPokemonMoves(game: var, pokemon: var, option: &const Options.Trainer, random: &rand.Rand) -> void {
    switch (option.moves) {
        Options.Trainer.Moves.Same => {
            // If trainer Pokémons where randomized, then keeping the same moves
            // makes no sense. We therefor reset them to something sensible.
            if (option.pokemon != Options.Trainer.Pokemon.Same) {
                // TODO:
            }
        },
        Options.Trainer.Moves.Random => {
            for (pokemon.moves) |*move| {
                move.set(randomMoveId(game, random));
            }
        },
        Options.Trainer.Moves.RandomWithinLearnset => {
            // TODO:
        },
        Options.Trainer.Moves.Best => {
            // TODO:
        },
    }
}

fn totalStats(pokemon: var) -> u16 {
    return
        u16(pokemon.hp)        +
        u16(pokemon.attack)    +
        u16(pokemon.defense)   +
        u16(pokemon.speed)     +
        u16(pokemon.sp_attack) +
        u16(pokemon.sp_defense);
}

fn randomType(comptime TGame: type, random: &rand.Rand) -> common.Type {
    const random_type_table = []common.Type {
        common.Type.Normal,
        common.Type.Fighting,
        common.Type.Flying,
        common.Type.Poison,
        common.Type.Ground,
        common.Type.Rock,
        common.Type.Bug,
        common.Type.Ghost,
        common.Type.Fire,
        common.Type.Water,
        common.Type.Grass,
        common.Type.Electric,
        common.Type.Psychic,
        common.Type.Ice,
        common.Type.Dragon,
        common.Type.Steel,
        common.Type.Dark,
        common.Type.Fairy,
    };

    const type_count = switch (TGame) {
        gen3.Game => 17,
        else => unreachable,
    };

    const table = random_type_table[0..type_count];
    return table[random.range(u8, 0, type_count)];
}

fn randomMoveId(game: var, random: &rand.Rand) -> u16 {
    while (true) {
        const move_id = random.range(u16, 0, u16(game.getMoveCount()));

        // TODO: We assume, that if the id is between 0..len, then we'll never get null from this function.
        const move = game.getMove(move_id) ?? unreachable;

        // A move with 0 pp is useless, so we will assume it's a dummy move.
        if (move.pp == 0) continue;
        return move_id;
    }
}