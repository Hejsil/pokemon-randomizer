const common = @import("common.zig");

pub const Info = struct {
    version: common.Version,
    base_stats: []const u8,
    level_up_moves: []const u8,
    moves: []const u8,
    trainer_data: []const u8,
    trainer_pokemons: []const u8,
};

pub const black2_info = Info{
    .version = common.Version.Black2,
    .base_stats = "a/0/1/6",
    .level_up_moves = "a/0/1/8",
    .moves = "a/0/2/1",
    .trainer_data = "a/0/9/1",
    .trainer_pokemons = "a/0/9/2",
};

pub const white2_info = blk: {
    var res = black2_info;
    res.version = common.Version.White2;

    break :blk res;
};

pub const black_info = blk: {
    var res = black2_info;
    res.version = common.Version.Black;
    res.trainer_data = "a/0/9/2";
    res.trainer_pokemons = "a/0/9/3";

    break :blk res;
};

pub const white_info = blk: {
    var res = black_info;
    res.version = common.Version.Black;

    break :blk res;
};

pub const tm_count = 95;
pub const hm_count = 6;
pub const hm_tm_prefix = "\x87\x03\x88\x03";
