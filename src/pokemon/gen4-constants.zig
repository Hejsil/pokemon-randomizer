pub const Files = struct {
    hm_tm_prefix: []const u8,

    base_stats: []const u8,
    level_up_moves: []const u8,
    moves: []const u8,
    trainer_data: []const u8,
    trainer_pokemons: []const u8,
    evolutions: []const u8,
};

const ss_files = hg_files;
const hg_files = Files {
    .hm_tm_prefix = "\x1E\x00\x32\x00",

    .base_stats = "/a/0/0/2",
    .level_up_moves = "/a/0/3/3",
    .moves = "/a/0/1/1",
    .trainer_data = "/a/0/5/5",
    .trainer_pokemons = "/a/0/5/6",
    .evolutions = "/a/0/3/4",
};

const diamond_files = Files {
    .hm_tm_prefix = "\xD1\x00\xD2\x00\xD3\x00\xD4\x00",

    .base_stats = "/poketool/personal/personal.narc",
    .level_up_moves = "/poketool/personal/wotbl.narc",
    .moves = "/poketool/waza/waza_tbl.narc",
    .trainer_data = "/poketool/trainer/trdata.narc",
    .trainer_pokemons = "/poketool/trainer/trpoke.narc",
    .evolutions = "/poketool/personal/evo.narc",
};

const pearl_files = comptime blk: {
    var res = diamond_files;
    res.base_stats = "/poketool/personal_pearl/personal.narc";
    break :blk res;
};

const platinum_files = pearl_files;

pub const tm_count = 92;
pub const hm_count = 8;
