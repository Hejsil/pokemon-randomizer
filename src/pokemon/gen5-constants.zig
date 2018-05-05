pub const Files = struct {
    base_stats: []const u8,
    level_up_moves: []const u8,
    moves: []const u8,
    trainer_data: []const u8,
    trainer_pokemons: []const u8,
};

pub const white2_files = black2_files;
pub const black2_files = Files {
    .base_stats       = "a/0/1/6",
    .level_up_moves   = "a/0/1/8",
    .moves            = "a/0/2/1",
    .trainer_data     = "a/0/9/1",
    .trainer_pokemons = "a/0/9/2",
};

pub const white_files = black_files;
pub const black_files = comptime blk: {
    var res = black2_files;
    res.trainer_data = "a/0/9/2";
    res.trainer_pokemons = "a/0/9/3";
    break :blk res;
};

pub const tm_count = 95;
pub const hm_count = 6;
pub const hm_tm_prefix = "\x87\x03\x88\x03";
