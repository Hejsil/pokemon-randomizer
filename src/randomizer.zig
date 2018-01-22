const std    = @import("std");
const common = @import("pokemon/common.zig");

const mem  = std.mem;
const rand = std.rand;

pub const Options = struct {
    pub const Trainer = struct {
        pub const TypeTheme = enum {
            /// Trainers will have Pokémons of random types.
            None,

            /// Each Pokémon in the trainers party will be replaced by one of the same
            /// type.
            Same,

            /// Each trainer will have a type theme, and all their Pokémons will
            /// have that type.
            Random,
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

        /// The theme that will be applied to the randomization of each trainer's
        /// party.
        type_theme: TypeTheme,

        /// Which held items each trainer Pokémon will be given.
        held_items: HeldItems,

        /// Trainer Pokémons will have their level increased by x%.
        level_modifier: f32,

        /// Trainer Pokémons will be replaced by once of simular strength (base on
        /// Pokémon's base stats).
        same_strength: bool,

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

pub fn randomize(comptime TGame: type, game: &const TGame, options: &const Options, &random: rand.Rand, allocator: &mem.Allocator) -> %void {

}

pub fn randomizeTrainers(comptime TGame, type, game: &const TGame, options: &const Options.Trainer, random: &rand.Rand, allocator: &mem.Allocator) -> %void {

    for (game.trainers) |*trainer| {
        var party = game.getTra
    }
}