const common = @import("common.zig");
const std = @import("std");
const fun = @import("fun");
const mem = std.mem;
const generic = fun.generic;

pub const Offset = struct {
    start: usize,
    len: usize,

    fn getSlice(offset: &const Offset, comptime Item: type, data: []u8) []Item {
        return generic.widenTrim(data[offset.start..], Item)[0..offset.len];
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

    .trainers                   = Offset { .start = 0x0310030, .len = 855, },
    .moves                      = Offset { .start = 0x031C898, .len = 355, },
    .tm_hm_learnset             = Offset { .start = 0x031E898, .len = 412, },
    .base_stats                 = Offset { .start = 0x03203CC, .len = 412, },
    .evolution_table            = Offset { .start = 0x032531C, .len = 412, },
    .level_up_learnset_pointers = Offset { .start = 0x032937C, .len = 412, },
    .hms                        = Offset { .start = 0x0329EEA, .len = 008, },
    .tms                        = Offset { .start = 0x0615B94, .len = 050, },
    .items                      = Offset { .start = 0x05839A0, .len = 377, },
};

// game_title: POKEMON RUBY
// gamecode: AXVE
pub const ruby_us_info = Info {
    .version = common.Version.Ruby,

    .trainers                   = Offset { .start = 0x01F0514, .len = 339, },
    .moves                      = Offset { .start = 0x01FB144, .len = 355, },
    .tm_hm_learnset             = Offset { .start = 0x01FD108, .len = 412, },
    .base_stats                 = Offset { .start = 0x01FEC30, .len = 412, },
    .evolution_table            = Offset { .start = 0x0203B80, .len = 412, },
    .level_up_learnset_pointers = Offset { .start = 0x0207BE0, .len = 412, },
    .hms                        = Offset { .start = 0x0208332, .len = 008, },
    .tms                        = Offset { .start = 0x037651C, .len = 050, },
    .items                      = Offset { .start = 0x03C5580, .len = 349, },
};

// game_title: POKEMON SAPP
// gamecode: AXPE
pub const sapphire_us_info = Info {
    .version = common.Version.Sapphire,

    .trainers                   = Offset { .start = 0x01F04A4, .len = 339, },
    .moves                      = Offset { .start = 0x01FB0D4, .len = 355, },
    .tm_hm_learnset             = Offset { .start = 0x01FD098, .len = 412, },
    .base_stats                 = Offset { .start = 0x01FEBC0, .len = 412, },
    .evolution_table            = Offset { .start = 0x0203B10, .len = 412, },
    .level_up_learnset_pointers = Offset { .start = 0x0207B70, .len = 412, },
    .hms                        = Offset { .start = 0x02082C2, .len = 008, },
    .tms                        = Offset { .start = 0x03764AC, .len = 050, },
    .items                      = Offset { .start = 0x03C55DC, .len = 349, },
};

// game_title: POKEMON FIRE
// gamecode: BPRE
pub const fire_us_info = Info {
    .version = common.Version.FireRed,

    .trainers                   = Offset { .start = 0x023EB38, .len = 439, },
    .moves                      = Offset { .start = 0x0250C74, .len = 355, },
    .tm_hm_learnset             = Offset { .start = 0x0252C38, .len = 412, },
    .base_stats                 = Offset { .start = 0x02547F4, .len = 412, },
    .evolution_table            = Offset { .start = 0x02597C4, .len = 412, },
    .level_up_learnset_pointers = Offset { .start = 0x025D824, .len = 412, },
    .hms                        = Offset { .start = 0x025E084, .len = 008, },
    .tms                        = Offset { .start = 0x045A604, .len = 050, },
    .items                      = Offset { .start = 0x03DB098, .len = 374, },
};

// game_title: POKEMON LEAF
// gamecode: BPGE
pub const leaf_us_info = Info {
    .version = common.Version.LeafGreen,

    .trainers                   = Offset { .start = 0x023EB14, .len = 439, },
    .moves                      = Offset { .start = 0x0250C50, .len = 355, },
    .tm_hm_learnset             = Offset { .start = 0x0252C14, .len = 412, },
    .base_stats                 = Offset { .start = 0x02547D0, .len = 412, },
    .evolution_table            = Offset { .start = 0x02597A4, .len = 412, },
    .level_up_learnset_pointers = Offset { .start = 0x025D804, .len = 412, },
    .hms                        = Offset { .start = 0x025E064, .len = 008, },
    .tms                        = Offset { .start = 0x045A034, .len = 050, },
    .items                      = Offset { .start = 0x03DAED4, .len = 374, },
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
