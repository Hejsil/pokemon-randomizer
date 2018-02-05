const nds = @import("../nds.zig");

pub const Game = struct {
    pub fn fromNds(rom: &nds.Rom, allocator: &mem.Allocator) %&Game {
        unreachable;
    }

    pub fn destroy(game: &const Game, allocator: &mem.Allocator) void {
        unreachable;
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