const pokemon = @import("index.zig");

pub const Info = struct {
    version: pokemon.Version,
    hm_tm_prefix: []const u8,

    base_stats: []const u8,
    level_up_moves: []const u8,
    moves: []const u8,
    trainers: []const u8,
    parties: []const u8,
    evolutions: []const u8,
};

pub const hg_info = Info{
    .version = pokemon.Version.HeartGold,
    .hm_tm_prefix = "\x1E\x00\x32\x00",

    .base_stats = "/a/0/0/2",
    .level_up_moves = "/a/0/3/3",
    .moves = "/a/0/1/1",
    .trainers = "/a/0/5/5",
    .parties = "/a/0/5/6",
    .evolutions = "/a/0/3/4",
};

pub const ss_info = blk: {
    var res = hg_info;
    res.version = pokemon.Version.SoulSilver;

    break :blk res;
};

pub const diamond_info = Info{
    .version = pokemon.Version.Diamond,
    .hm_tm_prefix = "\xD1\x00\xD2\x00\xD3\x00\xD4\x00",

    .base_stats = "/poketool/personal/personal.narc",
    .level_up_moves = "/poketool/personal/wotbl.narc",
    .moves = "/poketool/waza/waza_tbl.narc",
    .trainers = "/poketool/trainer/trdata.narc",
    .parties = "/poketool/trainer/trpoke.narc",
    .evolutions = "/poketool/personal/evo.narc",
};

pub const pearl_info = blk: {
    var res = diamond_info;
    res.version = pokemon.Version.Pearl;
    res.base_stats = "/poketool/personal_pearl/personal.narc";
    break :blk res;
};

pub const platinum_info = blk: {
    var res = diamond_info;
    res.version = pokemon.Version.Platinum;
    res.base_stats = "/poketool/personal/pl_personal.narc";
    res.moves = "/poketool/waza/pl_waza_tbl.narc";
    break :blk res;
};

pub const tm_count = 92;
pub const hm_count = 8;
