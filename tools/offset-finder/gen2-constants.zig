const std = @import("std");
const pokemon = @import("pokemon");
const math = std.math;
const gen2 = pokemon.gen2;
const common = pokemon.common;

pub const Trainer = struct {
    name: []const u8,
    kind: u8,
    party: []const gen2.Party.Member.WithBoth,
};

pub const first_trainers = []Trainer{
// FalknerGroup
Trainer{
// "FALKNER@"
    .name = "\x85\x80\x8B\x8A\x8D\x84\x91\x50",
    .kind = gen2.Party.has_moves,
    .party = []gen2.Party.Member.WithBoth{
        gen2.Party.Member.WithBoth{
            .base = gen2.Party.Member{
                .level = 7,
                .species = 0x10, // Pidgey
            },
            .item = undefined,
            .moves = [4]u8{
                0x21, // Tackle
                0xBD, // Mud Slap
                0x00,
                0x00,
            },
        },
        gen2.Party.Member.WithBoth{
            .base = gen2.Party.Member{
                .level = 9,
                .species = 0x11, // Pidgey
            },
            .item = undefined,
            .moves = [4]u8{
                0x21, // Tackle
                0xBD, // Mud Slap
                0x10, // Gust
                0x00,
            },
        },
    },
}};

pub const last_trainers = []Trainer{
// MysticalmanGroup
Trainer{
// "EUSINE@"
    .name = "\x84\x94\x92\x88\x8D\x84\x50",
    .kind = gen2.Party.has_moves,
    .party = []gen2.Party.Member.WithBoth{
        gen2.Party.Member.WithBoth{
            .base = gen2.Party.Member{
                .level = 23,
                .species = 0x60, // Drowzee
            },
            .item = undefined,
            .moves = [4]u8{
                0x8A, // Dream Eater
                0x5F, // Hypnosis
                0x32, // Disable
                0x5D, // Confusion
            },
        },
        gen2.Party.Member.WithBoth{
            .base = gen2.Party.Member{
                .level = 23,
                .species = 0x5D, // Haunter
            },
            .item = undefined,
            .moves = [4]u8{
                0x7A, // Lick
                0x5F, // Hypnosis
                0xD4, // Mean Look
                0xAE, // Curse
            },
        },
        gen2.Party.Member.WithBoth{
            .base = gen2.Party.Member{
                .level = 25,
                .species = 0x65, // Electrode
            },
            .item = undefined,
            .moves = [4]u8{
                0x67, // Screech
                0x31, // Sonicboom
                0x57, // Thunder
                0xCD, // Rollout
            },
        },
    },
}};

pub const first_base_stats = []gen2.BasePokemon{
// Bulbasaur
gen2.BasePokemon{
    .pokedex_number = 1,
    .stats = common.Stats{
        .hp = 45,
        .attack = 49,
        .defense = 49,
        .speed = 45,
        .sp_attack = 65,
        .sp_defense = 65,
    },

    .types = [2]gen2.Type{ gen2.Type.Grass, gen2.Type.Poison },

    .catch_rate = 45,
    .base_exp_yield = 64,
    .items = [2]u8{ 0, 0 },
    .gender_ratio = undefined,

    .unknown1 = 100,
    .egg_cycles = 20,
    .unknown2 = 5,

    .dimension_of_front_sprite = undefined,

    .blank = undefined,

    .growth_rate = common.GrowthRate.MediumSlow,
    .egg_group1 = common.EggGroup.Grass,
    .egg_group2 = common.EggGroup.Monster,

    .machine_learnset = undefined,
}};

pub const last_base_stats = []gen2.BasePokemon{
// Celebi
gen2.BasePokemon{
    .pokedex_number = 251,
    .stats = common.Stats{
        .hp = 100,
        .attack = 100,
        .defense = 100,
        .speed = 100,
        .sp_attack = 100,
        .sp_defense = 100,
    },

    .types = [2]gen2.Type{ gen2.Type.Psychic, gen2.Type.Grass },

    .catch_rate = 45,
    .base_exp_yield = 64,
    .items = [2]u8{ 0, 0x6D },
    .gender_ratio = undefined,

    .unknown1 = 100,
    .egg_cycles = 120,
    .unknown2 = 5,

    .dimension_of_front_sprite = undefined,

    .blank = undefined,

    .growth_rate = common.GrowthRate.MediumSlow,
    .egg_group1 = common.EggGroup.Undiscovered,
    .egg_group2 = common.EggGroup.Undiscovered,

    .machine_learnset = undefined,
}};
