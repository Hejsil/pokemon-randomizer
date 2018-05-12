const common = @import("common.zig");

pub const Info = struct {
    version: common.Version,
    hm_tm_prefix: []const u8,

    base_stats: []const u8,
    level_up_moves: []const u8,
    moves: []const u8,
    trainer_data: []const u8,
    trainer_pokemons: []const u8,
    evolutions: []const u8,
};

pub const hg_info = Info {
    .version = common.Version.HeartGold,
    .hm_tm_prefix = "\x1E\x00\x32\x00",

    .base_stats = "/a/0/0/2",
    .level_up_moves = "/a/0/3/3",
    .moves = "/a/0/1/1",
    .trainer_data = "/a/0/5/5",
    .trainer_pokemons = "/a/0/5/6",
    .evolutions = "/a/0/3/4",
};

pub const ss_info = blk: {
    var res = hg_info;
    res.version = common.Version.SoulSilver;

    break :blk res;
};

pub const diamond_info = Info {
    .version = common.Version.Diamond,
    .hm_tm_prefix = "\xD1\x00\xD2\x00\xD3\x00\xD4\x00",

    .base_stats = "/poketool/personal/personal.narc",
    .level_up_moves = "/poketool/personal/wotbl.narc",
    .moves = "/poketool/waza/waza_tbl.narc",
    .trainer_data = "/poketool/trainer/trdata.narc",
    .trainer_pokemons = "/poketool/trainer/trpoke.narc",
    .evolutions = "/poketool/personal/evo.narc",
};

pub const pearl_info = blk: {
    var res = diamond_info;
    res.version = common.Version.Pearl;
    res.base_stats = "/poketool/personal_pearl/personal.narc";
    break :blk res;
};

pub const platinum_info = blk: {
    var res = diamond_info;
    res.version = common.Version.Platinum;
    res.base_stats = "/poketool/personal/pl_personal.narc";
    res.moves = "/poketool/waza/pl_waza_tbl.narc";
    break :blk res;
};

pub const tm_count = 92;
pub const hm_count = 8;
