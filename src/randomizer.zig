const std     = @import("std");
const common  = @import("pokemon/common.zig");
const wrapper = @import("pokemon/wrapper.zig");

const math  = std.math;
const mem   = std.mem;
const rand  = std.rand;
const debug = std.debug;

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

        /// The the way trainers Pokémons should be randomized.
        pokemon: Pokemon,

        /// Trainer Pokémons will be replaced by once of simular strength (base on
        /// Pokémon's base stats).
        same_total_stats: bool,

        /// Which held items each trainer Pokémon will be given.
        held_items: HeldItems,

        /// Trainer Pokémons will have their level increased by x%.
        level_modifier: f64,

        /// When possible, trainer Pokémons will be given max IV.
        max_iv: bool,

        /// When possible, trainer Pokémons will be given max EV.
        max_ev: bool,

        /// When possible, trainers will be given the best AI.
        hard_ai: bool,

        /// When possible, give trainers Pokémon the strongest moves they are
        /// able to learn at their level.
        best_learned_moves: bool,

        pub fn default() -> Trainer {
            return Trainer {
                .pokemon = Pokemon.Same,
                .same_total_stats = false,
                .held_items = HeldItems.Same,
                .level_modifier = 1.0,
                .max_iv = false,
                .max_ev = false,
                .hard_ai = false,
                .best_learned_moves = false,
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
                    const new_pokemon = getRandomTrainerPokemon(game, curr_pokemon, options.same_total_stats, pokemons, random);
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
                    const new_pokemon = getRandomTrainerPokemon(game, curr_pokemon, options.same_total_stats, pokemons, random);
                    trainer_pokemon.species.set(new_pokemon);
                },
                Options.Trainer.Pokemon.TypeThemed => {
                    debug.assert(trainer_theme != common.Type.Unknown);
                    const pokemons = pokemons_by_type[u8(trainer_theme)].toSliceConst();
                    const new_pokemon = getRandomTrainerPokemon(game, curr_pokemon, options.same_total_stats, pokemons, random);
                    trainer_pokemon.species.set(new_pokemon);
                },
            }

            switch (options.held_items) {
                Options.Trainer.HeldItems.None => {
                    // TODO:
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

            const new_level = blk: {
                var res = f64(trainer_pokemon.level.get()) * options.level_modifier;
                res = math.min(res, f64(100));
                res = math.max(res, f64(1));
                break :blk u8(math.round(res));
            };
            trainer_pokemon.level.set(new_level);

            if (options.max_iv)
                trainer_pokemon.iv.set(@maxValue(u16));
            if (options.max_ev) {
                // TODO:
            }
            if (options.best_learned_moves) {
                // TODO:
            }
        }

        if (options.hard_ai)
            trainer.ai.set(@maxValue(u32));
    }
}

fn getRandomTrainerPokemon(game: var, curr_pokemom: var, same_total_stats: bool, pokemons: []const u16, random: &rand.Rand, ) -> u16 {
    if (same_total_stats) {
        var min_total = totalStats(curr_pokemom);
        var max_total = min_total;
        var tries : usize = 0;

        while (tries < 100) : (tries += 1) loop: {
            min_total = math.sub(u16, min_total, 10) catch min_total;
            max_total = math.add(u16, max_total, 10) catch max_total;

            var pokemons_with_stats : usize = 0;
            for (pokemons) |pokemon_id| {
                const pokemon = game.getBasePokemon(pokemon_id) ?? unreachable; // TODO: FIX
                const total = totalStats(pokemon);
                if (min_total <= total and total <= max_total)
                    pokemons_with_stats += 1;
            }

            if (pokemons_with_stats < 10) continue;

            const final = random.range(usize, 0, pokemons_with_stats);
            var index : usize = 0;
            for (pokemons) |pokemon_id| {
                const pokemon = game.getBasePokemon(pokemon_id) ?? unreachable; // TODO: FIX
                const total = totalStats(pokemon);

                if (min_total <= total and total <= max_total) {
                    if (index == final) {
                        return pokemon_id;
                    } else {
                        index += 1;
                    }
                }
            } else {
                unreachable; // TODO: FIX
            }
        }
    } else {
        return pokemons[random.range(usize, 0, pokemons.len)];
    }

    unreachable; // TODO: FIX
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

fn randomType(comptime TGame: type, random: &rand.Rand) -> common.Type {
    const type_count = switch (TGame) {
        wrapper.Gen3 => 17,
        else => unreachable,
    };

    const table = random_type_table[0..type_count];
    return table[random.range(u8, 0, type_count)];
}