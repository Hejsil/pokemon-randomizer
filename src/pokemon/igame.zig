const gen3  = @import("gen3.zig");
const utils = @import("../utils.zig");

pub const Trainer = struct {

};

pub const TrainerPokemon = struct {

};

pub const IGame = struct {
    getTrainerFn:        fn(&const IGame, usize) -> ?Trainer,
    setTrainerFn:        fn(&IGame, usize, &const Trainer) -> %void,

    getTrainerPokemonFn: fn(&const IGame, usize, usize) -> ?TrainerPokemon,
    setTrainerPokemonFn: fn(&IGame, usize, usize, &const TrainerPokemon) -> %void,
}

pub const Gen3GameAdapter = struct {
    base: IGame,
    game: &gen3.Game,

    pub fn init(game: &gen3.Game) -> Gen3GameAdapter {
        return Gen3GameAdapter {
            .base = IGame {
                .getTrainerFn =
                .setTrainerFn =
                .getTrainerPokemonFn =
                .setTrainerPokemonFn =
            },
            .game = game,
        };
    }

    fn getTrainer(base: &const IGame, index: usize) -> ?Trainer {
        const game = @fieldParentPtr(Gen3GameAdapter, "base", base).game;
        const trainer = utils.itemAt(Trainer, game.trainers, index);
    }
};