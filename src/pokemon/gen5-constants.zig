const pokemon = @import("index.zig");

pub const Info = struct {
    game_title: [12]u8,
    gamecode: [4]u8,
    version: pokemon.Version,

    base_stats: []const u8,
    level_up_moves: []const u8,
    moves: []const u8,
    trainers: []const u8,
    parties: []const u8,
};

pub const infos = []Info{
    black2_info,
    white2_info,
    black_info,
    white_info,
};

// TODO: Fill out game_titles
const black2_info = Info{
    .game_title = "POKEMON B2\x00\x00",
    .gamecode = "IREO",
    .version = pokemon.Version.Black2,

    .base_stats = "a/0/1/6",
    .level_up_moves = "a/0/1/8",
    .moves = "a/0/2/1",
    .trainers = "a/0/9/1",
    .parties = "a/0/9/2",
};

const white2_info = blk: {
    var res = black2_info;
    res.game_title = "POKEMON W2\x00\x00";
    res.gamecode = "IRDO";
    res.version = pokemon.Version.White2;

    break :blk res;
};

const black_info = blk: {
    var res = black2_info;
    res.game_title = "POKEMON B\x00\x00\x00";
    res.gamecode = "IRBO";
    res.version = pokemon.Version.Black;
    res.trainers = "a/0/9/2";
    res.parties = "a/0/9/3";

    break :blk res;
};

const white_info = blk: {
    var res = black_info;
    res.game_title = "POKEMON W\x00\x00\x00";
    res.gamecode = "IRAO";
    res.version = pokemon.Version.Black;

    break :blk res;
};

pub const tm_count = 95;
pub const hm_count = 6;
pub const hm_tm_prefix = "\x87\x03\x88\x03";
