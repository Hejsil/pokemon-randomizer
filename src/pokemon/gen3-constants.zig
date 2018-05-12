const common = @import("common.zig");
const std = @import("std");
const mem = std.mem;

pub const GameId = struct {
    game_title: []const u8,
    gamecode: []const u8,

    fn hash(id: &const GameId) u32 {
        const hash1 = mem.hash_slice_u8(id.game_title);
        const hash2 = mem.hash_slice_u8(id.gamecode);

        return (hash1 ^ hash2) *% 16777619;
    }

    fn equal(a: &const GameId, b: &const GameId) bool {
        return mem.eql(u8, a.game_title, b.game_title) and
                mem.eql(u8, a.gamecode, b.gamecode);
    }
};

pub const Offset = struct {
    start: usize,
    end: usize,

    fn getSlice(offset: &const Offset, comptime ElementType: type, data: []u8) []ElementType {
        return ([]ElementType)(data[offset.start..offset.end]);
    }
};

pub const Info = struct {
    version: common.Version,

    trainers:                   Offset,
    moves:                      Offset,
    tm_hm_learnset:             Offset,
    base_stats:                 Offset,
    evolution_table:            Offset,
    level_up_learnset_pointers: Offset,
    hms:                        Offset,
    tms:                        Offset,
    items:                      Offset,
};

// TODO: When we are able to allocate at comptime, construct a HashMap
//       that maps struct { game_title: []const u8, gamecode: []const u8, } -> Info
// game_title: POKEMON EMER
// gamecode: BPEE
pub const emerald_us_info = Info {
    .version = common.Version.Emerald,

    .trainers                   = Offset { .start = 0x0310030, .end = 0x03185C8, },
    .moves                      = Offset { .start = 0x031C898, .end = 0x031D93C, },
    .tm_hm_learnset             = Offset { .start = 0x031E898, .end = 0x031F578, },
    .base_stats                 = Offset { .start = 0x03203CC, .end = 0x03230DC, },
    .evolution_table            = Offset { .start = 0x032531C, .end = 0x032937C, },
    .level_up_learnset_pointers = Offset { .start = 0x032937C, .end = 0x03299EC, },
    .hms                        = Offset { .start = 0x0329EEA, .end = 0x0329EFA, },
    .tms                        = Offset { .start = 0x0615B94, .end = 0x0615BF8, },
    .items                      = Offset { .start = 0x05839A0, .end = 0x0587A6C, },
};

// game_title: POKEMON RUBY
// gamecode: AXVE
pub const ruby_us_info = Info {
    .version = common.Version.Ruby,

    .trainers                   = Offset { .start = 0x01F0514, .end = 0x01F3A0C, },
    .moves                      = Offset { .start = 0x01FB144, .end = 0x01FC1E8, },
    .tm_hm_learnset             = Offset { .start = 0x01FD108, .end = 0x01FDDE8, },
    .base_stats                 = Offset { .start = 0x01FEC30, .end = 0x0201940, },
    .evolution_table            = Offset { .start = 0x0203B80, .end = 0x0207BE0, },
    .level_up_learnset_pointers = Offset { .start = 0x0207BE0, .end = 0x0208250, },
    .hms                        = Offset { .start = 0x0208332, .end = 0x0208342, },
    .tms                        = Offset { .start = 0x037651C, .end = 0x0376580, },
    .items                      = Offset { .start = 0x03C5580, .end = 0x03C917C, },
};

// game_title: POKEMON SAPP
// gamecode: AXPE
pub const sapphire_us_info = Info {
    .version = common.Version.Sapphire,

    .trainers                   = Offset { .start = 0x01F04A4, .end = 0x01F399C, },
    .moves                      = Offset { .start = 0x01FB0D4, .end = 0x01FC178, },
    .tm_hm_learnset             = Offset { .start = 0x01FD098, .end = 0x01FDD78, },
    .base_stats                 = Offset { .start = 0x01FEBC0, .end = 0x02018D0, },
    .evolution_table            = Offset { .start = 0x0203B10, .end = 0x0207B70, },
    .level_up_learnset_pointers = Offset { .start = 0x0207B70, .end = 0x02081E0, },
    .hms                        = Offset { .start = 0x02082C2, .end = 0x02082D2, },
    .tms                        = Offset { .start = 0x03764AC, .end = 0x0376510, },
    .items                      = Offset { .start = 0x03C55DC, .end = 0x03C91D8, },
};

// game_title: POKEMON FIRE
// gamecode: BPRE
pub const fire_us_info = Info {
    .version = common.Version.FireRed,

    .trainers                   = Offset { .start = 0x023EB38, .end = 0x0242FD0, },
    .moves                      = Offset { .start = 0x0250C74, .end = 0x0251D18, },
    .tm_hm_learnset             = Offset { .start = 0x0252C38, .end = 0x0253918, },
    .base_stats                 = Offset { .start = 0x02547F4, .end = 0x0257504, },
    .evolution_table            = Offset { .start = 0x02597C4, .end = 0x025D824, },
    .level_up_learnset_pointers = Offset { .start = 0x025D824, .end = 0x025DE94, },
    .hms                        = Offset { .start = 0x025E084, .end = 0x025E094, },
    .tms                        = Offset { .start = 0x045A604, .end = 0x045A668, },
    .items                      = Offset { .start = 0x03DB098, .end = 0x03DF0E0, },
};

// game_title: POKEMON LEAF
// gamecode: BPGE
pub const leaf_us_info = Info {
    .version = common.Version.LeafGreen,

    .trainers                   = Offset { .start = 0x023EB14, .end = 0x0242FAC, },
    .moves                      = Offset { .start = 0x0250C50, .end = 0x0251CF4, },
    .tm_hm_learnset             = Offset { .start = 0x0252C14, .end = 0x02538F4, },
    .base_stats                 = Offset { .start = 0x02547D0, .end = 0x02574E0, },
    .evolution_table            = Offset { .start = 0x02597A4, .end = 0x025D804, },
    .level_up_learnset_pointers = Offset { .start = 0x025D804, .end = 0x025DE74, },
    .hms                        = Offset { .start = 0x025E064, .end = 0x025E074, },
    .tms                        = Offset { .start = 0x045A034, .end = 0x045A098, },
    .items                      = Offset { .start = 0x03DAED4, .end = 0x03DEF1C, },
};

// TODO: We should look up species dex id, and use the dex ids here instead.
pub const legendaries = []u16 {
    0x090, 0x091, 0x092, // Articuno, Zapdos, Moltres
    0x096, 0x097,        // Mewtwo, Mew
    0x0F3, 0x0F4, 0x0F5, // Raikou, Entei, Suicune
    0x0F9, 0x0FA, 0x0FB, // Lugia, Ho-Oh, Celebi
    0x191, 0x192, 0x193, // Regirock, Regice, Registeel
    0x194, 0x195, 0x196, // Kyogre, Groudon, Rayquaza
    0x197, 0x198,        // Latias, Latios
    0x199, 0x19A,        // Jirachi, Deoxys
};
