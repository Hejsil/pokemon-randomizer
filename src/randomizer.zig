const std    = @import("std");
const common = @import("pokemon/common.zig");

const rand = std.rand;

pub fn randomizeStats(game: &common.IGame, random: &rand.Rand) -> %void {
    var i : usize = 0;
    while (game.getPokemon(i)) |*pokemon| : (i += 1) {
        pokemon.hp         = random.scalar(u8);
        pokemon.attack     = random.scalar(u8);
        pokemon.defense    = random.scalar(u8);
        pokemon.speed      = random.scalar(u8);
        pokemon.sp_attack  = random.scalar(u8);
        pokemon.sp_defense = random.scalar(u8);

        %return game.setPokemon(i, pokemon);
    }
}