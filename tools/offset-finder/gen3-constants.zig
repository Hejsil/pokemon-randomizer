const pokemon = @import("pokemon");
const little = @import("little");
const std = @import("std");

const math = std.math;

const gen3 = pokemon.gen3;
const common = pokemon.common;

const Little = little.Little;
const toLittle = little.toLittle;

pub const em_first_trainers = []gen3.Trainer{
    gen3.Trainer{
        .party_type = gen3.PartyType.Standard,
        .class = 0,
        .encounter_music = 0,
        .trainer_picture = 0,
        .name = undefined,
        .items = []Little(u16){ toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)) },
        .is_double = toLittle(u32(0)),
        .ai = toLittle(u32(0)),
        .party_size = toLittle(u32(0)),
        .party_offset = undefined,
    },
    gen3.Trainer{
        .party_type = gen3.PartyType.Standard,
        .class = 0x02,
        .encounter_music = 0x0b,
        .trainer_picture = 0,
        .name = undefined,
        .items = []Little(u16){ toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)) },
        .is_double = toLittle(u32(0)),
        .ai = toLittle(u32(7)),
        .party_size = toLittle(u32(1)),
        .party_offset = undefined,
    },
};

pub const em_last_trainers = []gen3.Trainer{
    gen3.Trainer{
        .party_type = gen3.PartyType.Standard,
        .class = 0x41,
        .encounter_music = 0x80,
        .trainer_picture = 0x5c,
        .name = undefined,
        .items = []Little(u16){ toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)) },
        .is_double = toLittle(u32(0)),
        .ai = toLittle(u32(0)),
        .party_size = toLittle(u32(1)),
        .party_offset = undefined,
    },
};

pub const rs_first_trainers = []gen3.Trainer{
    gen3.Trainer{
        .party_type = gen3.PartyType.Standard,
        .class = 0,
        .encounter_music = 0,
        .trainer_picture = 0,
        .name = undefined,
        .items = []Little(u16){ toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)) },
        .is_double = toLittle(u32(0)),
        .ai = toLittle(u32(0)),
        .party_size = toLittle(u32(0)),
        .party_offset = undefined,
    },
    gen3.Trainer{
        .party_type = gen3.PartyType.Standard,
        .class = 0x02,
        .encounter_music = 0x06,
        .trainer_picture = 0x46,
        .name = undefined,
        .items = []Little(u16){ toLittle(u16(0x16)), toLittle(u16(0x16)), toLittle(u16(0)), toLittle(u16(0)) },
        .is_double = toLittle(u32(0)),
        .ai = toLittle(u32(7)),
        .party_size = toLittle(u32(2)),
        .party_offset = undefined,
    },
};

pub const rs_last_trainers = []gen3.Trainer{
    gen3.Trainer{
        .party_type = gen3.PartyType.Standard,
        .class = 0x21,
        .encounter_music = 0x0B,
        .trainer_picture = 0x06,
        .name = undefined,
        .items = []Little(u16){ toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)) },
        .is_double = toLittle(u32(0)),
        .ai = toLittle(u32(1)),
        .party_size = toLittle(u32(4)),
        .party_offset = undefined,
    },
};

pub const frls_first_trainers = []gen3.Trainer{
    gen3.Trainer{
        .party_type = gen3.PartyType.Standard,
        .class = 0,
        .encounter_music = 0,
        .trainer_picture = 0,
        .name = undefined,
        .items = []Little(u16){
            toLittle(u16(0)),
            toLittle(u16(0)),
            toLittle(u16(0)),
            toLittle(u16(0)),
        },
        .is_double = toLittle(u32(0)),
        .ai = toLittle(u32(0)),
        .party_size = toLittle(u32(0)),
        .party_offset = undefined,
    },
    gen3.Trainer{
        .party_type = gen3.PartyType.Standard,
        .class = 2,
        .encounter_music = 6,
        .trainer_picture = 0,
        .name = undefined,
        .items = []Little(u16){
            toLittle(u16(0)),
            toLittle(u16(0)),
            toLittle(u16(0)),
            toLittle(u16(0)),
        },
        .is_double = toLittle(u32(0)),
        .ai = toLittle(u32(1)),
        .party_size = toLittle(u32(1)),
        .party_offset = undefined,
    },
};

pub const frls_last_trainers = []gen3.Trainer{
    gen3.Trainer{
        .party_type = gen3.PartyType.WithBoth,
        .class = 90,
        .encounter_music = 0,
        .trainer_picture = 125,
        .name = undefined,
        .items = []Little(u16){
            toLittle(u16(19)),
            toLittle(u16(19)),
            toLittle(u16(19)),
            toLittle(u16(19)),
        },
        .is_double = toLittle(u32(0)),
        .ai = toLittle(u32(7)),
        .party_size = toLittle(u32(6)),
        .party_offset = undefined,
    },
};

pub const first_moves = []gen3.Move{
    // Dummy
    gen3.Move{
        .effect = 0,
        .power = 0,
        .@"type" = gen3.Type.Normal,
        .accuracy = 0,
        .pp = 0,
        .side_effect_chance = 0,
        .target = 0,
        .priority = 0,
        .flags = toLittle(u32(0)),
    },
    // Pound
    gen3.Move{
        .effect = 0,
        .power = 40,
        .@"type" = gen3.Type.Normal,
        .accuracy = 100,
        .pp = 35,
        .side_effect_chance = 0,
        .target = 0,
        .priority = 0,
        .flags = toLittle(u32(0x33)),
    },
};

pub const last_moves = []gen3.Move{
    // Psycho Boost
    gen3.Move{
        .effect = 204,
        .power = 140,
        .@"type" = gen3.Type.Psychic,
        .accuracy = 90,
        .pp = 5,
        .side_effect_chance = 100,
        .target = 0,
        .priority = 0,
        .flags = toLittle(u32(0x32)),
    },
};

// TODO: Fix format
pub const first_tm_hm_learnsets = []Little(u64){
    Little(u64){ .bytes = []u8{
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
    } }, // Dummy Pokémon
    Little(u64){ .bytes = []u8{
        0x20,
        0x07,
        0x35,
        0x84,
        0x08,
        0x1e,
        0xe4,
        0x00,
    } }, // Bulbasaur
    Little(u64){ .bytes = []u8{
        0x20,
        0x07,
        0x35,
        0x84,
        0x08,
        0x1e,
        0xe4,
        0x00,
    } }, // Ivysaur
    Little(u64){ .bytes = []u8{
        0x30,
        0x47,
        0x35,
        0x86,
        0x08,
        0x1e,
        0xe4,
        0x00,
    } }, // Venusaur
};

pub const last_tm_hm_learnsets = []Little(u64){
    Little(u64){ .bytes = []u8{
        0x3e,
        0xd6,
        0xbb,
        0xb7,
        0x93,
        0x5e,
        0x5c,
        0x03,
    } }, // Latios
    Little(u64){ .bytes = []u8{
        0x2c,
        0xc6,
        0x9b,
        0xb5,
        0x93,
        0x8e,
        0x40,
        0x00,
    } }, // Jirachi
    Little(u64){ .bytes = []u8{
        0x2d,
        0xde,
        0xbb,
        0xf5,
        0xc3,
        0x8f,
        0xe5,
        0x00,
    } }, // Deoxys
    Little(u64){ .bytes = []u8{
        0x28,
        0x8e,
        0x1b,
        0xb4,
        0x03,
        0x9f,
        0x41,
        0x00,
    } }, // Chimecho
};

pub const first_base_stats = []gen3.BasePokemon{
    // Dummy
    gen3.BasePokemon{
        .hp = 0,
        .attack = 0,
        .defense = 0,
        .speed = 0,
        .sp_attack = 0,
        .sp_defense = 0,

        .types = []gen3.Type{ gen3.Type.Normal, gen3.Type.Normal },

        .catch_rate = 0,
        .base_exp_yield = 0,

        .ev_yield = common.EvYield{
            .hp = 0,
            .attack = 0,
            .defense = 0,
            .speed = 0,
            .sp_attack = 0,
            .sp_defense = 0,
            .padding = 0,
        },

        .items = []Little(u16){ toLittle(u16(0)), toLittle(u16(0)) },

        .gender_ratio = 0,
        .egg_cycles = 0,
        .base_friendship = 0,

        .growth_rate = common.GrowthRate.MediumFast,

        .egg_group1 = common.EggGroup.Invalid,
        .egg_group1_pad = undefined,
        .egg_group2 = common.EggGroup.Invalid,
        .egg_group2_pad = undefined,

        .abilities = []u8{ 0, 0 },
        .safari_zone_rate = 0,

        .color = common.Color.Red,
        .flip = false,

        .padding = undefined,
    },
    // Bulbasaur
    gen3.BasePokemon{
        .hp = 45,
        .attack = 49,
        .defense = 49,
        .speed = 45,
        .sp_attack = 65,
        .sp_defense = 65,

        .types = []gen3.Type{ gen3.Type.Grass, gen3.Type.Poison },

        .catch_rate = 45,
        .base_exp_yield = 64,

        .ev_yield = common.EvYield{
            .hp = 0,
            .attack = 0,
            .defense = 0,
            .speed = 0,
            .sp_attack = 1,
            .sp_defense = 0,
            .padding = 0,
        },

        .items = []Little(u16){ toLittle(u16(0)), toLittle(u16(0)) },

        .gender_ratio = comptime percentFemale(12.5),
        .egg_cycles = 20,
        .base_friendship = 70,

        .growth_rate = common.GrowthRate.MediumSlow,

        .egg_group1 = common.EggGroup.Monster,
        .egg_group1_pad = undefined,
        .egg_group2 = common.EggGroup.Grass,
        .egg_group2_pad = undefined,

        .abilities = []u8{ 65, 0 },
        .safari_zone_rate = 0,

        .color = common.Color.Green,
        .flip = false,

        .padding = undefined,
    },
};

pub const last_base_stats = []gen3.BasePokemon{
    // Chimecho
    gen3.BasePokemon{
        .hp = 65,
        .attack = 50,
        .defense = 70,
        .speed = 65,
        .sp_attack = 95,
        .sp_defense = 80,

        .types = []gen3.Type{ gen3.Type.Psychic, gen3.Type.Psychic },

        .catch_rate = 45,
        .base_exp_yield = 147,

        .ev_yield = common.EvYield{
            .hp = 0,
            .attack = 0,
            .defense = 0,
            .speed = 0,
            .sp_attack = 1,
            .sp_defense = 1,
            .padding = 0,
        },

        .items = []Little(u16){ toLittle(u16(0)), toLittle(u16(0)) },

        .gender_ratio = comptime percentFemale(50),
        .egg_cycles = 25,
        .base_friendship = 70,

        .growth_rate = common.GrowthRate.Fast,

        .egg_group1 = common.EggGroup.Amorphous,
        .egg_group1_pad = undefined,
        .egg_group2 = common.EggGroup.Amorphous,
        .egg_group2_pad = undefined,

        .abilities = []u8{ 26, 0 },
        .safari_zone_rate = 0,

        .color = common.Color.Blue,
        .flip = false,

        .padding = undefined,
    },
};

fn percentFemale(percent: f64) u8 {
    return u8(math.min(f64(254), (percent * 255) / 100));
}

const unused_evo = common.Evolution{
    .method = common.Evolution.Method.Unused,
    .param = toLittle(u16(0)),
    .target = toLittle(u16(0)),
    .padding = undefined,
};
const unused_evo5 = []common.Evolution{unused_evo} ** 5;

pub const first_evolutions = [][5]common.Evolution{
    // Dummy
    unused_evo5,

    // Bulbasaur
    []common.Evolution{
        common.Evolution{
            .method = common.Evolution.Method.LevelUp,
            .param = toLittle(u16(16)),
            .target = toLittle(u16(2)),
            .padding = undefined,
        },
        unused_evo,
        unused_evo,
        unused_evo,
        unused_evo,
    },

    // Ivysaur
    []common.Evolution{
        common.Evolution{
            .method = common.Evolution.Method.LevelUp,
            .param = toLittle(u16(32)),
            .target = toLittle(u16(3)),
            .padding = undefined,
        },
        unused_evo,
        unused_evo,
        unused_evo,
        unused_evo,
    },
};

pub const last_evolutions = [][5]common.Evolution{
    // Beldum
    []common.Evolution{
        common.Evolution{
            .method = common.Evolution.Method.LevelUp,
            .param = toLittle(u16(20)),
            .target = toLittle(u16(399)),
            .padding = undefined,
        },
        unused_evo,
        unused_evo,
        unused_evo,
        unused_evo,
    },

    // Metang
    []common.Evolution{
        common.Evolution{
            .method = common.Evolution.Method.LevelUp,
            .param = toLittle(u16(45)),
            .target = toLittle(u16(400)),
            .padding = undefined,
        },
        unused_evo,
        unused_evo,
        unused_evo,
        unused_evo,
    },

    // Metagross, Regirock, Regice, Registeel, Kyogre, Groudon, Rayquaza
    // Latias, Latios, Jirachi, Deoxys, Chimecho
    unused_evo5,
    unused_evo5,
    unused_evo5,
    unused_evo5,
    unused_evo5,
    unused_evo5,
    unused_evo5,
    unused_evo5,
    unused_evo5,
    unused_evo5,
    unused_evo5,
    unused_evo5,
};

pub const first_levelup_learnsets = []?[]const u8{
    // Dummy mon have same moves as Bulbasaur
    []u8{
        0x21, 0x02, 0x2D, 0x08, 0x49, 0x0E, 0x16, 0x14, 0x4D, 0x1E, 0x4F, 0x1E,
        0x4B, 0x28, 0xE6, 0x32, 0x4A, 0x40, 0xEB, 0x4E, 0x4C, 0x5C, 0xFF, 0xFF,
    },
    // Bulbasaur
    []u8{
        0x21, 0x02, 0x2D, 0x08, 0x49, 0x0E, 0x16, 0x14, 0x4D, 0x1E, 0x4F, 0x1E,
        0x4B, 0x28, 0xE6, 0x32, 0x4A, 0x40, 0xEB, 0x4E, 0x4C, 0x5C, 0xFF, 0xFF,
    },
    // Ivysaur
    []u8{
        0x21, 0x02, 0x2D, 0x02, 0x49, 0x02, 0x2D, 0x08, 0x49, 0x0E, 0x16, 0x14,
        0x4D, 0x1E, 0x4F, 0x1E, 0x4B, 0x2C, 0xE6, 0x3A, 0x4A, 0x4C, 0xEB, 0x5E,
        0x4C, 0x70, 0xFF, 0xFF,
    },
    // Venusaur
    []u8{
        0x21, 0x02, 0x2D, 0x02, 0x49, 0x02, 0x16, 0x02, 0x2D, 0x08, 0x49, 0x0E,
        0x16, 0x14, 0x4D, 0x1E, 0x4F, 0x1E, 0x4B, 0x2C, 0xE6, 0x3A, 0x4A, 0x52,
        0xEB, 0x6A, 0x4C, 0x82, 0xFF, 0xFF,
    },
};

pub const last_levelup_learnsets = []?[]const u8{
    // Latios
    []u8{
        0x95, 0x02, 0x06, 0x0B, 0x0E, 0x15, 0xDB, 0x1E, 0xE1, 0x28, 0xB6, 0x32, 0x1F,
        0x3D, 0x27, 0x47, 0x5E, 0x50, 0x69, 0x5A, 0x5D, 0x65, 0xFF, 0xFF,
    },
    // Jirachi
    []u8{
        0x11, 0x03, 0x5D, 0x02, 0x9C, 0x0A, 0x81, 0x14, 0x0E, 0x1F, 0x5E, 0x28, 0x1F,
        0x33, 0x9C, 0x3C, 0x26, 0x46, 0xF8, 0x50, 0x42, 0x5B, 0x61, 0x65, 0xFF, 0xFF,
    },
    // Deoxys have different moves between FRLG, RUSA and EM
    null,
    // Chimecho
    []u8{
        0x23, 0x02, 0x2D, 0x0C, 0x36, 0x13, 0x5D, 0x1C, 0x24, 0x22, 0xFD, 0x2C, 0x19,
        0x33, 0x95, 0x3C, 0x26, 0x42, 0xD7, 0x4C, 0xDB, 0x52, 0x5E, 0x5C, 0xFF, 0xFF,
    },
};

pub const hms = []u8{
    0x0f, 0x00, 0x13, 0x00, 0x39, 0x00, 0x46, 0x00, 0x94, 0x00, 0xf9, 0x00, 0x7f, 0x00, 0x23, 0x01,
};

pub const tms = []u8{
    0x08, 0x01, 0x51, 0x01, 0x60, 0x01, 0x5b, 0x01, 0x2e, 0x00, 0x5c, 0x00, 0x02, 0x01, 0x53, 0x01,
    0x4b, 0x01, 0xed, 0x00, 0xf1, 0x00, 0x0d, 0x01, 0x3a, 0x00, 0x3b, 0x00, 0x3f, 0x00, 0x71, 0x00,
    0xb6, 0x00, 0xf0, 0x00, 0xca, 0x00, 0xdb, 0x00, 0xda, 0x00, 0x4c, 0x00, 0xe7, 0x00, 0x55, 0x00,
    0x57, 0x00, 0x59, 0x00, 0xd8, 0x00, 0x5b, 0x00, 0x5e, 0x00, 0xf7, 0x00, 0x18, 0x01, 0x68, 0x00,
    0x73, 0x00, 0x5f, 0x01, 0x35, 0x00, 0xbc, 0x00, 0xc9, 0x00, 0x7e, 0x00, 0x3d, 0x01, 0x4c, 0x01,
    0x03, 0x01, 0x07, 0x01, 0x22, 0x01, 0x9c, 0x00, 0xd5, 0x00, 0xa8, 0x00, 0xd3, 0x00, 0x1d, 0x01,
    0x21, 0x01, 0x3b, 0x01,
};

pub const em_first_items = []gen3.Item{
    // ????????
    gen3.Item{
        .name = undefined,
        .id = toLittle(u16(0)),
        .price = toLittle(u16(0)),
        .hold_effect = 0,
        .hold_effect_param = 0,
        .description_offset = undefined,
        .importance = 0,
        .unknown = 0,
        .pocked = 1,
        .@"type" = 4,
        .field_use_func = undefined,
        .battle_usage = toLittle(u32(0)),
        .battle_use_func = undefined,
        .secondary_id = toLittle(u32(0)),
    },
    // MASTER BALL
    gen3.Item{
        .name = undefined,
        .id = toLittle(u16(1)),
        .price = toLittle(u16(0)),
        .hold_effect = 0,
        .hold_effect_param = 0,
        .description_offset = undefined,
        .importance = 0,
        .unknown = 0,
        .pocked = 2,
        .@"type" = 0,
        .field_use_func = undefined,
        .battle_usage = toLittle(u32(2)),
        .battle_use_func = undefined,
        .secondary_id = toLittle(u32(0)),
    },
};

pub const em_last_items = []gen3.Item{
    // MAGMA EMBLEM
    gen3.Item{
        .name = undefined,
        .id = toLittle(u16(0x177)),
        .price = toLittle(u16(0)),
        .hold_effect = 0,
        .hold_effect_param = 0,
        .description_offset = undefined,
        .importance = 1,
        .unknown = 1,
        .pocked = 5,
        .@"type" = 4,
        .field_use_func = undefined,
        .battle_usage = toLittle(u32(0)),
        .battle_use_func = undefined,
        .secondary_id = toLittle(u32(0)),
    },
    // OLD SEA MAP
    gen3.Item{
        .name = undefined,
        .id = toLittle(u16(0x178)),
        .price = toLittle(u16(0)),
        .hold_effect = 0,
        .hold_effect_param = 0,
        .description_offset = undefined,
        .importance = 1,
        .unknown = 1,
        .pocked = 5,
        .@"type" = 4,
        .field_use_func = undefined,
        .battle_usage = toLittle(u32(0)),
        .battle_use_func = undefined,
        .secondary_id = toLittle(u32(0)),
    },
};

pub const rs_first_items = []gen3.Item{
    // ????????
    gen3.Item{
        .name = undefined,
        .id = toLittle(u16(0)),
        .price = toLittle(u16(0)),
        .hold_effect = 0,
        .hold_effect_param = 0,
        .description_offset = undefined,
        .importance = 0,
        .unknown = 0,
        .pocked = 1,
        .@"type" = 4,
        .field_use_func = undefined,
        .battle_usage = toLittle(u32(0)),
        .battle_use_func = undefined,
        .secondary_id = toLittle(u32(0)),
    },
    // MASTER BALL
    gen3.Item{
        .name = undefined,
        .id = toLittle(u16(1)),
        .price = toLittle(u16(0)),
        .hold_effect = 0,
        .hold_effect_param = 0,
        .description_offset = undefined,
        .importance = 0,
        .unknown = 0,
        .pocked = 2,
        .@"type" = 0,
        .field_use_func = undefined,
        .battle_usage = toLittle(u32(2)),
        .battle_use_func = undefined,
        .secondary_id = toLittle(u32(0)),
    },
};

pub const rs_last_items = []gen3.Item{
    // HM08
    gen3.Item{
        .name = undefined,
        .id = toLittle(u16(0x15A)),
        .price = toLittle(u16(0)),
        .hold_effect = 0,
        .hold_effect_param = 0,
        .description_offset = undefined,
        .importance = 1,
        .unknown = 0,
        .pocked = 3,
        .@"type" = 1,
        .field_use_func = undefined,
        .battle_usage = toLittle(u32(0)),
        .battle_use_func = undefined,
        .secondary_id = toLittle(u32(0)),
    },
    // ????????
    gen3.Item{
        .name = undefined,
        .id = toLittle(u16(0)),
        .price = toLittle(u16(0)),
        .hold_effect = 0,
        .hold_effect_param = 0,
        .description_offset = undefined,
        .importance = 0,
        .unknown = 0,
        .pocked = 1,
        .@"type" = 4,
        .field_use_func = undefined,
        .battle_usage = toLittle(u32(0)),
        .battle_use_func = undefined,
        .secondary_id = toLittle(u32(0)),
    },
    // ????????
    gen3.Item{
        .name = undefined,
        .id = toLittle(u16(0)),
        .price = toLittle(u16(0)),
        .hold_effect = 0,
        .hold_effect_param = 0,
        .description_offset = undefined,
        .importance = 0,
        .unknown = 0,
        .pocked = 1,
        .@"type" = 4,
        .field_use_func = undefined,
        .battle_usage = toLittle(u32(0)),
        .battle_use_func = undefined,
        .secondary_id = toLittle(u32(0)),
    },
};

pub const frlg_first_items = []gen3.Item{
    gen3.Item{
        .name = undefined,
        .id = toLittle(u16(0)),
        .price = toLittle(u16(0)),
        .hold_effect = 0,
        .hold_effect_param = 0,
        .description_offset = undefined,
        .importance = 0,
        .unknown = 0,
        .pocked = 1,
        .@"type" = 4,
        .field_use_func = undefined,
        .battle_usage = toLittle(u32(0)),
        .battle_use_func = undefined,
        .secondary_id = toLittle(u32(0)),
    },
    gen3.Item{
        .name = undefined,
        .id = toLittle(u16(1)),
        .price = toLittle(u16(0)),
        .hold_effect = 0,
        .hold_effect_param = 0,
        .description_offset = undefined,
        .importance = 0,
        .unknown = 0,
        .pocked = 3,
        .@"type" = 0,
        .field_use_func = undefined,
        .battle_usage = toLittle(u32(2)),
        .battle_use_func = undefined,
        .secondary_id = toLittle(u32(0)),
    },
};

pub const frlg_last_items = []gen3.Item{
    gen3.Item{
        .name = undefined,
        .id = toLittle(u16(372)),
        .price = toLittle(u16(0)),
        .hold_effect = 0,
        .hold_effect_param = 0,
        .description_offset = undefined,
        .importance = 1,
        .unknown = 1,
        .pocked = 2,
        .@"type" = 4,
        .field_use_func = undefined,
        .battle_usage = toLittle(u32(0)),
        .battle_use_func = undefined,
        .secondary_id = toLittle(u32(0)),
    },
    gen3.Item{
        .name = undefined,
        .id = toLittle(u16(373)),
        .price = toLittle(u16(0)),
        .hold_effect = 0,
        .hold_effect_param = 0,
        .description_offset = undefined,
        .importance = 1,
        .unknown = 1,
        .pocked = 2,
        .@"type" = 4,
        .field_use_func = undefined,
        .battle_usage = toLittle(u32(0)),
        .battle_use_func = undefined,
        .secondary_id = toLittle(u32(0)),
    },
};
