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
        same_strength: bool,

        /// Which held items each trainer Pokémon will be given.
        held_items: HeldItems,

        /// Trainer Pokémons will have their level increased by x%.
        level_modifier: f32,

        /// When possible, trainer Pokémons will be given max IV.
        max_iv: bool,

        /// When possible, trainer Pokémons will be given max EV.
        max_ev: bool,

        /// When possible, trainers will be given the best AI.
        hard_ai: bool,

        /// When possible, give trainers Pokémon the strongest moves they are
        /// able to learn at their level.
        best_learned_moves: bool,
    };

    trainer: Trainer,
};

pub fn randomize(game: var, options: &const Options, random: &rand.Rand, allocator: &mem.Allocator) -> %void {
    // HACK: This is the easiest way of getting the type of the Pokémons
    //       in the game we are randomizing.
    const Pokemon = @typeOf(*(game.getBasePokemon(0) ?? unreachable));

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

    var i : u16 = 0;
    while (game.getBasePokemon(i)) |pokemon| : (i += 1) {
        try pokemons_by_type[u8(pokemon.type1)].append(i);
        try pokemons_by_type[u8(pokemon.type2)].append(i);
    }

    try randomizeTrainers(game, pokemons_by_type, options.trainer, random, allocator);
}

fn randomizeTrainers(game: var, pokemons_by_type: var, options: &const Options.Trainer, random: &rand.Rand, allocator: &mem.Allocator) -> %void {
    var trainer_id : usize = 0;
    while (game.getTrainer(trainer_id)) |trainer| : (trainer_id += 1) {
        const trainer_theme = switch (options.pokemon) {
            Options.Trainer.Pokemon.TypeThemed => randomType(game, random),
            else => common.Type.Unknown,
        };

        var pokemon_index : usize = 0;
        while (try game.getTrainerPokemon(trainer, pokemon_index)) |trainer_pokemon| : (pokemon_index += 1) {
            // TODO: Handle when a trainers Pokémon does not point on a valid species.
            //                                                                         VVVVVVVVVVV
            const curr_pokemon = game.getBasePokemon(trainer_pokemon.species.get()) ?? unreachable;
            switch (options.pokemon) {
                Options.Trainer.Pokemon.Same => {},
                Options.Trainer.Pokemon.Random => {

                },
                Options.Trainer.Pokemon.SameType => {

                },
                Options.Trainer.Pokemon.TypeThemed => {
                    debug.assert(trainer_theme != common.Type.Unknown);
                    const pokemons = (*pokemons_by_type)[u8(trainer_theme)];

                    if (options.same_strength) {
                        var min_total = totalStats(curr_pokemon);
                        var max_total = min_total;
                        var tries : usize = 0;

                        while (tries < 100) : (tries += 1) loop: {
                            min_total = math.sub(u16, min_total, 10) catch min_total;
                            max_total = math.add(u16, max_total, 10) catch max_total;

                            var pokemons_with_stats : usize = 0;
                            for (pokemons.toSliceConst()) |pokemon_id| {
                                const pokemon = game.getBasePokemon(pokemon_id) ?? unreachable;
                                const total = totalStats(pokemon);
                                if (min_total <= total and total <= max_total)
                                    pokemons_with_stats += 1;
                            }

                            if (pokemons_with_stats < 10) continue;

                            const final = random.range(usize, 0, pokemons_with_stats);
                            var index : usize = 0;
                            for (pokemons.toSliceConst()) |pokemon_id| {
                                const pokemon = game.getBasePokemon(pokemon_id) ?? unreachable;
                                const total = totalStats(pokemon);

                                if (min_total <= total and total <= max_total) {
                                    if (index == final) {
                                        trainer_pokemon.species.set(pokemon_id);
                                        break :loop;
                                    } else {
                                        index += 1;
                                    }
                                }
                            } else {
                                unreachable;
                            }
                        }
                    } else {
                        trainer_pokemon.species.set(pokemons.items[random.range(usize, 0, pokemons.len)]);
                    }
                },
            }
        }
    }
}

fn totalStats(pokemon: var) -> u16 {
    return
        pokemon.hp +
        pokemon.attack +
        pokemon.defense +
        pokemon.speed +
        pokemon.sp_attack +
        pokemon.sp_defense;
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

fn randomType(game: var, random: &rand.Rand) -> common.Type {
    const type_count = switch (@typeOf(game)) {
        wrapper.Gen3 => 17,
        else => unreachable,
    };

    const table = random_type_table[0..type_count];
    return table[random.range(u8, 0, type_count)];
}