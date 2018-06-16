const std = @import("std");
const bits = @import("bits.zig");
const little = @import("little.zig");
const libpoke = @import("pokemon/index.zig");

const math = std.math;
const mem = std.mem;
const rand = std.rand;
const debug = std.debug;

const Little = little.Little;

const assert = debug.assert;

/// A generic enum for different randomization options.
pub const GenericOption = enum {
    Same,
    Random,
    Best,
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
            // Trainer Pokémons will have random held items.
            //Random,

            // Trainer Pokémons will have random, but useful, held items.
            //RandomUseful,

            // Trainer Pokémons will hold the best held items in the game.
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

        /// Trainer Pokémons will have their level increased by x%.
        level_modifier: f64,

        pub fn default() Trainer {
            return Trainer{
                .pokemon = Pokemon.Same,
                .same_total_stats = false,
                .held_items = HeldItems.Same,
                .moves = Moves.Same,
                .level_modifier = 1.0,
            };
        }
    };

    trainer: Trainer,

    pub fn default() Options {
        return Options{ .trainer = Trainer.default() };
    }
};

pub const Randomizer = struct {
    fn hash_type(t: u8) u32 {
        return t;
    }
    fn type_eql(t1: u8, t2: u8) bool {
        return t1 == t2;
    }
    const SpeciesByType = std.HashMap(u8, std.ArrayList(u16), hash_type, type_eql);

    game: *const libpoke.Game,
    random: *rand.Random,
    allocator: *mem.Allocator,
    species_by_type: ?SpeciesByType,

    pub fn init(game: *const libpoke.Game, random: *rand.Random, allocator: *mem.Allocator) Randomizer {
        return Randomizer{
            .game = game,
            .allocator = allocator,
            .random = random,
            .species_by_type = null,
        };
    }

    pub fn deinit(randomizer: *Randomizer) void {
        if (randomizer.species_by_type) |*by_type| {
            freeSpeciesByType(by_type);
        }
    }

    pub fn randomize(randomizer: *Randomizer, options: *const Options) !void {
        try randomizer.randomizeTrainers(options.trainer);
    }

    pub fn randomizeTrainers(randomizer: *Randomizer, options: *const Options.Trainer) !void {
        const game = randomizer.game;
        var by_type = try randomizer.speciesByType();

        const pokemons = game.pokemons();
        const trainers = game.trainers();

        var trainer_it = trainers.iterator();
        while (trainer_it.nextValid()) |trainer_item| {
            const trainer = trainer_item.value;
            const party = trainer.party();

            var party_it = party.iterator();
            while (party_it.next()) |party_item| {
                const member = party_item.value;
                const member_pokemon = try pokemons.at(member.species());
                switch (options.pokemon) {
                    Options.Trainer.Pokemon.Same => {},
                    Options.Trainer.Pokemon.Random => {
                        // TODO: Types probably shouldn't be weighted equally, as
                        //       there is a different number of Pokémons per type.
                        // TODO: If a Pokémon is dual type, it has a higher chance of
                        //       being chosen. I think?
                        const pokemon_type = try randomizer.randomType();
                        const pick_from = (??by_type.get(pokemon_type)).value.toSliceConst();
                        const new_pokemon = try randomizer.randomTrainerPokemon(member_pokemon, options.same_total_stats, pick_from);
                        member.setSpecies(new_pokemon);
                    },
                    Options.Trainer.Pokemon.SameType => {
                        const pokemon_type = blk: {
                            const member_types = member_pokemon.types();
                            const roll = randomizer.random.float(f32);
                            break :blk if (roll < 0.80) member_types[0] else member_types[1];
                        };

                        const pick_from = (??by_type.get(pokemon_type)).value.toSliceConst();
                        const new_pokemon = try randomizer.randomTrainerPokemon(member_pokemon, options.same_total_stats, pick_from);
                        member.setSpecies(new_pokemon);
                    },
                    Options.Trainer.Pokemon.TypeThemed => {
                        const trainer_theme = try randomizer.randomType();
                        const pick_from = (??by_type.get(trainer_theme)).value.toSliceConst();
                        const new_pokemon = try randomizer.randomTrainerPokemon(member_pokemon, options.same_total_stats, pick_from);
                        member.setSpecies(new_pokemon);
                    },
                    Options.Trainer.Pokemon.Legendaries => {
                        const new_pokemon = try randomizer.randomTrainerPokemon(member_pokemon, options.same_total_stats, game.base.version.legendaries());
                        member.setSpecies(new_pokemon);
                    },
                }

                randomizer.randomizeTrainerPokemonHeldItem(member, options.held_items);
                try randomizer.randomizeTrainerPokemonMoves(member, options);

                const lvl = member.level();
                const new_level = blk: {
                    var res = f64(lvl) * options.level_modifier;
                    res = math.min(res, f64(100));
                    res = math.max(res, f64(1));
                    break :blk u8(math.round(res));
                };
                member.setLevel(new_level);
            }
        }
    }

    fn randomTrainerPokemon(randomizer: *Randomizer, curr_pokemom: *const libpoke.Pokemon, same_total_stats: bool, pick_from: []const u16) !u16 {
        const game = randomizer.game;
        const pokemons = game.pokemons();

        if (same_total_stats) {
            var min_total = curr_pokemom.totalStats();
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
                    const total = pokemon.totalStats();
                    if (min_total <= total and total <= max_total)
                        try matches.append(species);
                }
            }

            return matches.toSlice()[randomizer.random.range(usize, 0, matches.len)];
        } else {
            return pick_from[randomizer.random.range(usize, 0, pick_from.len)];
        }
    }

    fn randomizeTrainerPokemonHeldItem(randomizer: *const Randomizer, member: *const libpoke.PartyMember, option: Options.Trainer.HeldItems) void {
        const game = randomizer.game;
        switch (option) {
            Options.Trainer.HeldItems.None => {
                member.setItem(0) catch return;
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

    fn randomizeTrainerPokemonMoves(randomizer: *Randomizer, member: *const libpoke.PartyMember, option: *const Options.Trainer) !void {
        const pokemons = randomizer.game.pokemons();
        const member_moves = member.moves() ?? return;

        switch (option.moves) {
            Options.Trainer.Moves.Same => {
                // If trainer Pokémons where randomized, then keeping the same moves makes no sense.
                // We therefore reset them to something sensible.
                if (option.pokemon != Options.Trainer.Pokemon.Same) {
                    const MoveLevelPair = struct {
                        level: u8,
                        move_id: u16,
                    };
                    const new_moves = blk: {
                        const pokemon = try pokemons.at(member.species());
                        const level_up_moves = pokemon.levelUpMoves();
                        var moves = []MoveLevelPair{MoveLevelPair{
                            .level = 0,
                            .move_id = 0,
                        }} ** 4;

                        var it = level_up_moves.iterator();
                        while (it.next()) |item| {
                            const level_up_move = item.value;
                            for (moves) |*move| {
                                const move_lvl = level_up_move.level();
                                const trainer_pkm_level = member.level();
                                if (move.level < move_lvl and move_lvl < trainer_pkm_level) {
                                    move.level = move_lvl;
                                    move.move_id = level_up_move.moveId();
                                    break;
                                }
                            }
                        }

                        break :blk moves;
                    };

                    debug.assert(member_moves.len() == new_moves.len);
                    for (new_moves) |new_move, i| {
                        member_moves.atSet(i, new_move.move_id);
                    }
                }
            },
            Options.Trainer.Moves.Random => {
                var i: usize = 0;
                while (i < member_moves.len()) : (i += 1) {
                    member_moves.atSet(i, randomizer.randomMoveId());
                }
            },
            Options.Trainer.Moves.RandomWithinLearnset => {
                const learned_moves = try randomizer.movesLearned(member.species());
                defer randomizer.allocator.free(learned_moves);

                var i: usize = 0;
                while (i < member_moves.len()) : (i += 1) {
                    const pick = learned_moves[randomizer.random.range(usize, 0, learned_moves.len)];
                    member_moves.atSet(i, pick);
                }
            },
            Options.Trainer.Moves.Best => {
                const moves = randomizer.game.moves();
                const pokemon = try pokemons.at(member.species());
                const learned_moves = try randomizer.movesLearned(member.species());
                defer randomizer.allocator.free(learned_moves);

                {
                    var i: usize = 0;
                    while (i < member_moves.len()) : (i += 1)
                        member_moves.atSet(i, 0);
                }

                for (learned_moves) |learned| {
                    const learned_move = moves.at(learned);

                    var i: usize = 0;
                    while (i < member_moves.len()) : (i += 1) {
                        const move_id = member_moves.at(i);
                        const move = moves.at(move_id);

                        const p_t1 = pokemon.types()[0];
                        const p_t2 = pokemon.types()[1];
                        const m_t = move.types()[0];
                        const l_t = learned_move.types()[0];

                        // TODO: Rewrite to work with Pokémons that can have N types
                        const move_stab = if (m_t == p_t1 or m_t == p_t2) f32(1.5) else f32(1.0);
                        const learned_stab = if (l_t == p_t1 or l_t == p_t2) f32(1.5) else f32(1.0);
                        const move_power = f32(move.power().*) * move_stab;
                        const learned_power = f32(learned_move.power().*) * learned_stab;

                        // TODO: We probably also want Pokémons to have varied types
                        //       of moves, so it has good coverage.
                        // TODO: We probably want to pick attack vs sp_attack moves
                        //       depending on the Pokémons stats.
                        if (move_power < learned_power) {
                            member_moves.atSet(i, learned);
                            break;
                        }
                    }
                }
            },
        }
    }

    fn randomType(randomizer: *Randomizer) !u8 {
        const species_by_type = try randomizer.speciesByType();
        const choice = randomizer.random.range(usize, 0, species_by_type.size);
        var it = species_by_type.iterator();
        var i: usize = 0;
        while (i < species_by_type.size) : (i += 1) {
            var n = ??it.next();
            if (i == choice)
                return n.key;
        }

        unreachable;
    }

    fn randomMoveId(randomizer: *Randomizer) u16 {
        const game = randomizer.game;
        const moves = game.moves();
        while (true) {
            const move_id = randomizer.random.range(u16, 0, u16(moves.len()));
            const move = moves.at(move_id);

            // A move with 0 pp is useless, so we will assume it's a dummy move.
            if (move.pp().* == 0) continue;
            return move_id;
        }
    }

    /// Caller owns memory returned
    fn movesLearned(randomizer: *const Randomizer, species: u16) ![]u16 {
        const game = randomizer.game;
        const pokemons = game.pokemons();
        const pokemon = try pokemons.at(species);
        const levelup_learnset = pokemon.levelUpMoves();
        const tm_learnset = pokemon.tmLearnset();
        const hm_learnset = pokemon.hmLearnset();
        const tms = game.tms();
        const hms = game.hms();

        var res = std.ArrayList(u16).init(randomizer.allocator);
        try res.ensureCapacity(levelup_learnset.len());

        var lvl_it = levelup_learnset.iterator();
        while (lvl_it.next()) |item| {
            // HACK: TODO: Remove this when https://github.com/zig-lang/zig/issues/649 is a thing
            try res.append(item.value.moveId());
        }

        var tm_learnset_it = tm_learnset.iterator();
        while (tm_learnset_it.next()) |item| {
            if (item.value) {
                const move_id = tms.at(item.index);
                try res.append(move_id);
            }
        }

        var hm_learnset_it = hm_learnset.iterator();
        while (hm_learnset_it.next()) |item| {
            if (item.value) {
                const move_id = hms.at(item.index);
                try res.append(move_id);
            }
        }

        return res.toOwnedSlice();
    }

    fn speciesByType(randomizer: *Randomizer) !*SpeciesByType {
        const game = randomizer.game;
        if (randomizer.species_by_type) |*species_by_type| return species_by_type;

        var species_by_type = SpeciesByType.init(randomizer.allocator);
        errdefer freeSpeciesByType(&species_by_type);

        comptime var i = 0;
        inline while (i < @memberCount(libpoke.Type)) : (i += 1) {
            const t = @field(libpoke.Type, @memberName(libpoke.Type, i));
        }

        const pokemons = game.pokemons();
        var it = pokemons.iterator();
        while (it.nextValid()) |item| {
            const pokemon = item.value;
            const species = item.index;

            // Asume that Pokémons with 0 hp are dummy Pokémon
            if (pokemon.hp().* == 0) continue;

            for (pokemon.types().*) |t| {
                const entry = species_by_type.get(t) ?? blk: {
                    _ = try species_by_type.put(t, std.ArrayList(u16).init(randomizer.allocator));
                    break :blk ??species_by_type.get(t);
                };
                try entry.value.append(u16(species));
            }
        }

        randomizer.species_by_type = species_by_type;
        return &??randomizer.species_by_type;
    }

    fn freeSpeciesByType(by_type: *SpeciesByType) void {
        var it = by_type.iterator();
        while (it.next()) |entry|
            entry.value.deinit();

        by_type.deinit();
    }
};
