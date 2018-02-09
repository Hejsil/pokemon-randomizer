const nds = @import("../nds/index.zig");



pub const Game = struct {

    base_stats: &nds.fs.File,

    pub fn fromRom(rom: &nds.Rom) !Game {
        const root = &rom.root;

        return Game {
            .base_stats = root.getFile("a/0/1/6") ?? return error.Err,
        };
    }

    pub fn getBasePokemon(game: &const Game, index: usize) ?&BasePokemon {
        unreachable;
    }

    pub fn getTrainer(game: &const Game, index: usize) ?&Trainer {
        unreachable;
    }

    pub fn getTrainerPokemon(game: &const Game, trainer: &const Trainer, index: usize) ?&PartyMemberBase {
        unreachable;
    }

    fn getBasePartyMember(comptime TMember: type, data: []u8, index: usize, offset: usize, size: usize) ?&PartyMemberBase {
        unreachable;
    }

    pub fn getMove(game: &const Game, index: usize) ?&Move {
        unreachable;
    }

    pub fn getMoveCount(game: &const Game) usize {
        unreachable;
     }

    pub fn getLevelupMoves(game: &const Game, species: usize) ?[]LevelUpMove {
        unreachable;
    }

    pub fn getTms(game: &const Game) []Little(u16) {
        unreachable;
    }

    pub fn getHms(game: &const Game) []Little(u16) {
        unreachable;
    }

    pub fn getTmHmLearnset(game: &const Game, species: usize) ?&Little(u64) {
        unreachable;
    }
};