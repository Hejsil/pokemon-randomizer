const pokemon = @import("index.zig");

pub const Info = struct {
    game_title: [12]u8,
    gamecode: [4]u8,
    version: pokemon.Version,

    hm_tm_prefix: []const u8,
    base_stats: []const u8,
    level_up_moves: []const u8,
    moves: []const u8,
    trainers: []const u8,
    parties: []const u8,
    evolutions: []const u8,
};

pub const infos = []Info{
    hg_info,
    ss_info,
    diamond_info,
    pearl_info,
    platinum_info,
};

// TODO: Fill out game_titles
const hg_info = Info{
    .game_title = "POKEMON HG\x00\x00",
    .gamecode = "IPKE",
    .version = pokemon.Version.HeartGold,

    .hm_tm_prefix = "\x1E\x00\x32\x00",
    .base_stats = "/a/0/0/2",
    .level_up_moves = "/a/0/3/3",
    .moves = "/a/0/1/1",
    .trainers = "/a/0/5/5",
    .parties = "/a/0/5/6",
    .evolutions = "/a/0/3/4",
};

const ss_info = blk: {
    var res = hg_info;
    res.game_title = "POKEMON SS\x00\x00";
    res.gamecode = "IPGE";
    res.version = pokemon.Version.SoulSilver;

    break :blk res;
};

const diamond_info = Info{
    .game_title = "POKEMON D\x00\x00\x00",
    .gamecode = "ADAE",
    .version = pokemon.Version.Diamond,
    .hm_tm_prefix = "\xD1\x00\xD2\x00\xD3\x00\xD4\x00",

    .base_stats = "/poketool/personal/personal.narc",
    .level_up_moves = "/poketool/personal/wotbl.narc",
    .moves = "/poketool/waza/waza_tbl.narc",
    .trainers = "/poketool/trainer/trdata.narc",
    .parties = "/poketool/trainer/trpoke.narc",
    .evolutions = "/poketool/personal/evo.narc",
};

const pearl_info = blk: {
    var res = diamond_info;
    res.game_title = "POKEMON P\x00\x00\x00";
    res.gamecode = "APAE";
    res.version = pokemon.Version.Pearl;
    res.base_stats = "/poketool/personal_pearl/personal.narc";
    break :blk res;
};

const platinum_info = blk: {
    var res = diamond_info;
    res.game_title = "POKEMON PL\x00\x00";
    res.gamecode = "CPUE";
    res.version = pokemon.Version.Platinum;
    res.base_stats = "/poketool/personal/pl_personal.narc";
    res.moves = "/poketool/waza/pl_waza_tbl.narc";
    break :blk res;
};

pub const tm_count = 92;
pub const hm_count = 8;
