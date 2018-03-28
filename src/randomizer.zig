const std     = @import("std");
const common  = @import("pokemon/common.zig");
const gen3    = @import("pokemon/gen3.zig");
const bits    = @import("bits.zig");

const math  = std.math;
const mem   = std.mem;
const rand  = std.rand;
const debug = std.debug;

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

pub fn randomize(game: var, options: &const Options, random: &rand.Rand, allocator: &mem.Allocator) !void {
    var pokemons_by_type : [@memberCount(common.Type)]std.ArrayList(u16) = undefined;

    for (pokemons_by_type) |*list| {
        *list = std.ArrayList(u16).init(allocator);
    }
    defer {
        for (pokemons_by_type) |*list| {
            list.deinit();
        }
    }

    var species : u16 = 0;
    while (game.getBasePokemon(species)) |pokemon| : (species += 1) {
        for (pokemon.types) |t| {
            try pokemons_by_type[u8(t)].append(species);
        }
    }

    try randomizeTrainers(game, pokemons_by_type[0..], options.trainer, random, allocator);
}

fn randomizeTrainers(game: var, pokemons_by_type: []std.ArrayList(u16), options: &const Options.Trainer, random: &rand.Rand, allocator: &mem.Allocator) !void {
    var trainer_id : usize = 0;
    while (game.getTrainer(trainer_id)) |trainer| : (trainer_id += 1) {
        const trainer_theme = switch (options.pokemon) {
            Options.Trainer.Pokemon.TypeThemed => randomType(@typeOf(*game), random),
            else => common.Type.Unknown,
        };

        var species : usize = 0;
        while (game.getTrainerPokemon(trainer_id, species)) |trainer_pokemon| : (species += 1) {
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
                        // TODO: Rewrite to work with Pokémons that can have N types
                        if (curr_pokemon.types[0] == common.Type.Unknown) {
                            if (curr_pokemon.types[1] == common.Type.Unknown) {
                                break :blk randomType(@typeOf(*game), random);
                            } else {
                                break :blk curr_pokemon.types[1];
                            }
                        }
                        if (curr_pokemon.types[1] == common.Type.Unknown)
                            break :blk randomType(@typeOf(*game), random);

                        const roll = random.float(f32);
                        break :blk if (roll < 0.80) curr_pokemon.types[0] else curr_pokemon.types[1];
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
                Options.Trainer.Pokemon.Legendaries => {
                    const new_pokemon = try getRandomTrainerPokemon(game, curr_pokemon, options.same_total_stats, @typeOf(*game).legendaries, random, allocator);
                    trainer_pokemon.species.set(new_pokemon);
                }
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
                            try randomizeTrainerPokemonMoves(game, member, options, random, allocator);
                        },
                        gen3.PartyType.WithBoth => {
                            const member = @fieldParentPtr(gen3.PartyMemberWithBoth, "base", trainer_pokemon);
                            randomizeTrainerPokemonHeldItem(game, member, options.held_items, random);
                            try randomizeTrainerPokemonMoves(game, member, options, random, allocator);
                        },
                        else => {}
                    }
                },
                else => unreachable,
            }

            switch (options.iv) {
                GenericOption.Same => {},
                GenericOption.Random => trainer_pokemon.iv.set(random.range(u16, 0, @maxValue(u16))),
                GenericOption.Best => trainer_pokemon.iv.set(@maxValue(u16)),
            }

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

fn getRandomTrainerPokemon(game: var, curr_pokemom: var, same_total_stats: bool, pokemons: []const u16, random: &rand.Rand, allocator: &mem.Allocator) !u16 {
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

            for (pokemons) |species| {
                const pokemon = game.getBasePokemon(species) ?? unreachable; // TODO: FIX
                const total = totalStats(pokemon);
                if (min_total <= total and total <= max_total)
                    try matches.append(species);
            }
        }

        return matches.toSlice()[random.range(usize, 0, matches.len)];
    } else {
        return pokemons[random.range(usize, 0, pokemons.len)];
    }
}

fn randomizeTrainerPokemonHeldItem(game: var, pokemon: var, option: Options.Trainer.HeldItems, random: &rand.Rand) void {
    switch (option) {
        Options.Trainer.HeldItems.None => {
            pokemon.held_item.set(0);
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

fn randomizeTrainerPokemonMoves(game: var, trainer_pokemon: var, option: &const Options.Trainer, random: &rand.Rand, allocator: &mem.Allocator) !void {
    switch (option.moves) {
        Options.Trainer.Moves.Same => {
            // If trainer Pokémons where randomized, then keeping the same moves
            // makes no sense. We therefor reset them to something sensible.
            if (option.pokemon != Options.Trainer.Pokemon.Same) {
                const MoveLevelPair = struct { level: u8, move_id: u16 };
                const new_moves = blk: {
                    // TODO: Handle not getting any level up moves.
                    const level_up_moves = game.getLevelupMoves(trainer_pokemon.base.species.get()) ?? return;
                    var moves = []MoveLevelPair { MoveLevelPair { .level = 0, .move_id = 0, } } ** 4;

                    for (level_up_moves) |level_up_move| {
                        for (moves) |*move| {
                            if (move.level < level_up_move.level and level_up_move.level < trainer_pokemon.base.level.get()) {
                                move.level = level_up_move.level;
                                move.move_id = level_up_move.move_id;
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
                move.set(randomMoveId(game, random));
            }
        },
        Options.Trainer.Moves.RandomWithinLearnset => {
            const learned_moves = try getMovesLearned(game, trainer_pokemon.base.species.get(), allocator);
            defer allocator.free(learned_moves);

            for (trainer_pokemon.moves) |*move| {
                const pick = learned_moves[random.range(usize, 0, learned_moves.len)];
                move.set(pick);
            }
        },
        Options.Trainer.Moves.Best => {
            // TODO: How do we handle, if trainer Pokémon does not have a valid species?
            const pokemon = game.getBasePokemon(trainer_pokemon.base.species.get()) ?? return;
            const learned_moves = try getMovesLearned(game, trainer_pokemon.base.species.get(), allocator);
            defer allocator.free(learned_moves);

            for (trainer_pokemon.moves) |*move|
                move.set(0);

            for (learned_moves) |learned| {
                const learned_move = game.getMove(learned) ?? continue;

                pokemon_moves_loop:
                for (trainer_pokemon.moves) |*move_id| {
                    // If, for some reason, the Pokémon has a move we can't get
                    // the information for, then we replace that move, with the
                    // learned move.
                    const move = game.getMove(move_id.get()) ?? {
                        move_id.set(learned);
                        break :pokemon_moves_loop;
                    };

                    // TODO: Rewrite to work with Pokémons that can have N types
                    const move_stab    = if (move.@"type"         == pokemon.types[0] or move.@"type"         == pokemon.types[1]) f32(1.5) else f32(1.0);
                    const learned_stab = if (learned_move.@"type" == pokemon.types[0] or learned_move.@"type" == pokemon.types[1]) f32(1.5) else f32(1.0);
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

fn totalStats(pokemon: var) u16 {
    return
        u16(pokemon.hp)        +
        u16(pokemon.attack)    +
        u16(pokemon.defense)   +
        u16(pokemon.speed)     +
        u16(pokemon.sp_attack) +
        u16(pokemon.sp_defense);
}

fn randomType(comptime TGame: type, random: &rand.Rand) common.Type {
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

fn randomMoveId(game: var, random: &rand.Rand) u16 {
    while (true) {
        const move_id = random.range(u16, 0, u16(game.getMoveCount()));

        // We assume, that if the id is between 0..len, then we'll never get null from this function.
        const move = game.getMove(move_id) ?? unreachable;

        // A move with 0 pp is useless, so we will assume it's a dummy move.
        if (move.pp == 0) continue;
        return move_id;
    }
}

/// Caller owns memory returned
fn getMovesLearned(game: var, species: usize, allocator: &mem.Allocator) ![]u16 {
    const levelup_learnset = game.getLevelupMoves(species) ?? unreachable;
    var res = std.ArrayList(u16).init(allocator);
    try res.ensureCapacity(levelup_learnset.len);

    for (levelup_learnset) |level_up_move| {
        try res.append(u16(level_up_move.move_id));
    }

    var tm = usize(0);
    while (game.getTmMove(tm)) |move| : (tm += 1) {
        if (game.learnsTm(species, tm) ?? unreachable)
            try res.append(move.get());
    }

    var hm = usize(0);
    while (game.getHmMove(hm)) |move| : (hm += 1) {
        if (game.learnsHm(species, hm) ?? unreachable)
            try res.append(move.get());
    }

    return res.toOwnedSlice();
}



    pub fn getTmMove(game: &const Game, tm: usize) ?&Little(u16) { return utils.slice.ptrAtOrNull(game.tms, tm); }
    pub fn getHmMove(game: &const Game, hm: usize) ?&Little(u16) { return utils.slice.ptrAtOrNull(game.hms, hm); }

    pub fn learnsTm(game: &const Game, species: usize, tm: usize) ?bool {
        if (tm >= game.tms.len)                 return null;
        if (species >= game.tm_hm_learnset.len) return null;

        return bits.get(u64, game.tm_hm_learnset[species].get(), u6(tm));
    }

    pub fn learnsHm(game: &const Game, species: usize, hm: usize) ?bool {
        if (hm >= game.hms.len)                 return null;
        if (species >= game.tm_hm_learnset.len) return null;

        return bits.get(u64, game.tm_hm_learnset[species].get(), u6(hm + game.tms.len));
    }
