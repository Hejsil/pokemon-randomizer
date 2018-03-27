const std     = @import("std");
const gba     = @import("gba");
const utils   = @import("utils");
const little  = @import("little");
const pokemon = @import("pokemon");

const os     = std.os;
const debug  = std.debug;
const mem    = std.mem;
const math   = std.math;
const io     = std.io;
const gen3   = pokemon.gen3;
const common = pokemon.common;

const Little = little.Little;
const toLittle = little.toLittle;

const Version = enum {
    Ruby, Shappire, Emerald, FireRed, LeafGreen,
};

const Offset = struct {
    start: usize,
    end: usize,
};

const Offsets = struct {
    header:                     gba.Header,
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

pub fn main() !void {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var stdout_handle = try io.getStdOut();
    var stdout_file_stream = io.FileOutStream.init(&stdout_handle);
    var stdout = &stdout_file_stream.stream;

    // NOTE: Do we want to use another allocator for arguments? Does it matter? Idk.
    const args = try os.argsAlloc(&direct_allocator.allocator);
    defer os.argsFree(&direct_allocator.allocator, args);

    if (args.len < 2) {
        debug.warn("No file was provided.\n");
        return error.NoFileInArguments;
    }

    for (args[1..]) |arg| {
        var arena = std.heap.ArenaAllocator.init(&direct_allocator.allocator);
        defer arena.deinit();

        const allocator = &arena.allocator;

        var file = os.File.openRead(allocator, arg) catch |err| {
            debug.warn("Couldn't open {}.\n", arg);
            return err;
        };
        defer file.close();

        if (findOffsetsInFile(&file, allocator)) |offsets| {
            // TODO: Write start offset and length in items insead of start and end. This is to avoid "slice widening size mismatch"
            try stdout.print("game_title: {}\n", offsets.header.game_title);
            try stdout.print("gamecode: {}\n", offsets.header.gamecode);
            try stdout.print(".trainers                   = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", offsets.trainers.start,                   offsets.trainers.end);
            try stdout.print(".moves                      = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", offsets.moves.start,                      offsets.moves.end);
            try stdout.print(".tm_hm_learnset             = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", offsets.tm_hm_learnset.start,             offsets.tm_hm_learnset.end);
            try stdout.print(".base_stats                 = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", offsets.base_stats.start,                 offsets.base_stats.end);
            try stdout.print(".evolution_table            = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", offsets.evolution_table.start,            offsets.evolution_table.end);
            try stdout.print(".level_up_learnset_pointers = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", offsets.level_up_learnset_pointers.start, offsets.level_up_learnset_pointers.end);
            try stdout.print(".hms                        = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", offsets.hms.start,                        offsets.hms.end);
            try stdout.print(".tms                        = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", offsets.tms.start,                        offsets.tms.end);
            try stdout.print(".items                      = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", offsets.items.start,                      offsets.items.end);
        } else |err| {
            // TODO: This is the starting point for error messages. They should probably be better, but at least
            //       all errors from "findOffsetsInFile" are handled in this switch.
            switch (err) {
                error.UnknownPokemonVersion             => debug.warn("Unknown generation 3 game.\n"),
                error.UnableToFindTrainerOffset         => debug.warn("Unable to find trainers offset.\n"),
                error.UnableToFindMoveOffset            => debug.warn("Unable to find moves offset.\n"),
                error.UnableToFindTmHmLearnsetOffset    => debug.warn("Unable to find tm_hm_learnset offset.\n"),
                error.UnableToFindBaseStatsOffset       => debug.warn("Unable to find base_stats offset.\n"),
                error.UnableToFindEvolutionTableOffset  => debug.warn("Unable to find evolution_table offset.\n"),
                error.UnableToFindLevelUpLearnsetOffset => debug.warn("Unable to find levelup learnset offset.\n"),
                error.UnableToFindHmOffset              => debug.warn("Unable to find hms offset.\n"),
                error.UnableToFindTmOffset              => debug.warn("Unable to find tms offset.\n"),
                error.UnableToFindItemsOffset           => debug.warn("Unable to find items offset.\n"),
                error.Io                                => debug.warn("Io.\n"),
                error.OutOfMemory                       => debug.warn("Ran out of memory.\n"),
                error.BadFd                             => debug.warn("BadFd.\n"),
                error.Unexpected                        => debug.warn("An unexpected error occured.\n"),
                error.StreamTooLong                     => debug.warn("StreamTooLong.\n"),
                error.Unseekable                        => debug.warn("Unseekable.\n"),
                error.Overflow                          => debug.warn("Overflow.\n"),
                error.EndOfStream                       => debug.warn("EndOfStream.\n"),
            }

            return err;
        }

    }
}

fn findOffsetsInFile(file: &os.File, allocator: &mem.Allocator) !Offsets {
    var file_stream = io.FileInStream.init(file);
    var stream = &file_stream.stream;
    var header : gba.Header = undefined;
    try stream.readNoEof(([]u8)((&header)[0..1]));
    try file.seekTo(0);

    const version = if (mem.eql(u8, header.game_title, "POKEMON EMER")) blk: {
        break :blk Version.Emerald;
    } else if (mem.eql(u8, header.game_title, "POKEMON RUBY")) blk: {
        break :blk Version.Ruby;
    } else if (mem.eql(u8, header.game_title, "POKEMON SAPP")) blk: {
        break :blk Version.Shappire;
    } else if (mem.eql(u8, header.game_title, "POKEMON FIRE")) blk: {
        break :blk Version.FireRed;
    } else if (mem.eql(u8, header.game_title, "POKEMON LEAF")) blk: {
        break :blk Version.LeafGreen;
    } else blk: {
        return error.UnknownPokemonVersion;
    };

    const data = try stream.readAllAlloc(allocator, @maxValue(usize));
    defer allocator.free(data);

    const ignored_trainer_fields = [][]const u8 { "party_offset", "name" };
    const trainers = switch (version) {
        Version.Emerald => findOffsetOfStructArray(gen3.Trainer, ignored_trainer_fields, data,
            []gen3.Trainer {
                gen3.Trainer {
                    .party_type = gen3.PartyType.Standard,
                    .class = 0,
                    .encounter_music = 0,
                    .trainer_picture = 0,
                    .name = undefined,
                    .items = []Little(u16) { toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)) },
                    .is_double = toLittle(u32(0)),
                    .ai = toLittle(u32(0)),
                    .party_size = toLittle(u32(0)),
                    .party_offset = undefined,
                },
                gen3.Trainer {
                    .party_type = gen3.PartyType.Standard,
                    .class = 0x02,
                    .encounter_music = 0x0b,
                    .trainer_picture = 0,
                    .name = undefined,
                    .items = []Little(u16) { toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)) },
                    .is_double = toLittle(u32(0)),
                    .ai = toLittle(u32(7)),
                    .party_size = toLittle(u32(1)),
                    .party_offset = undefined,
                },
            },
            []gen3.Trainer {
                gen3.Trainer {
                    .party_type = gen3.PartyType.Standard,
                    .class = 0x41,
                    .encounter_music = 0x80,
                    .trainer_picture = 0x5c,
                    .name = undefined,
                    .items = []Little(u16) { toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)) },
                    .is_double = toLittle(u32(0)),
                    .ai = toLittle(u32(0)),
                    .party_size = toLittle(u32(1)),
                    .party_offset = undefined,
                },
            }),
        Version.Ruby, Version.Shappire => findOffsetOfStructArray(gen3.Trainer, ignored_trainer_fields, data,
            []gen3.Trainer {
                gen3.Trainer {
                    .party_type = gen3.PartyType.Standard,
                    .class = 0,
                    .encounter_music = 0,
                    .trainer_picture = 0,
                    .name = undefined,
                    .items = []Little(u16) { toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)) },
                    .is_double = toLittle(u32(0)),
                    .ai = toLittle(u32(0)),
                    .party_size = toLittle(u32(0)),
                    .party_offset = undefined,
                },
                gen3.Trainer {
                    .party_type = gen3.PartyType.Standard,
                    .class = 0x02,
                    .encounter_music = 0x06,
                    .trainer_picture = 0x46,
                    .name = undefined,
                    .items = []Little(u16) { toLittle(u16(0x16)), toLittle(u16(0x16)), toLittle(u16(0)), toLittle(u16(0)) },
                    .is_double = toLittle(u32(0)),
                    .ai = toLittle(u32(7)),
                    .party_size = toLittle(u32(2)),
                    .party_offset = undefined,
                },
            },
            []gen3.Trainer {
                gen3.Trainer {
                    .party_type = gen3.PartyType.Standard,
                    .class = 0x21,
                    .encounter_music = 0x0B,
                    .trainer_picture = 0x06,
                    .name = undefined,
                    .items = []Little(u16) { toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)) },
                    .is_double = toLittle(u32(0)),
                    .ai = toLittle(u32(1)),
                    .party_size = toLittle(u32(4)),
                    .party_offset = undefined,
                },
            }),
        Version.FireRed, Version.LeafGreen => findOffsetOfStructArray(gen3.Trainer, ignored_trainer_fields, data,
            []gen3.Trainer {
                gen3.Trainer {
                    .party_type = gen3.PartyType.Standard,
                    .class = 0,
                    .encounter_music = 0,
                    .trainer_picture = 0,
                    .name = undefined,
                    .items = []Little(u16) { toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)), },
                    .is_double = toLittle(u32(0)),
                    .ai = toLittle(u32(0)),
                    .party_size = toLittle(u32(0)),
                    .party_offset = undefined,
                },
                gen3.Trainer {
                    .party_type = gen3.PartyType.Standard,
                    .class = 2,
                    .encounter_music = 6,
                    .trainer_picture = 0,
                    .name = undefined,
                    .items = []Little(u16) { toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)), toLittle(u16(0)), },
                    .is_double = toLittle(u32(0)),
                    .ai = toLittle(u32(1)),
                    .party_size = toLittle(u32(1)),
                    .party_offset = undefined,
                },
            },
            []gen3.Trainer {
                gen3.Trainer {
                    .party_type = gen3.PartyType.WithBoth,
                    .class = 90,
                    .encounter_music = 0,
                    .trainer_picture = 125,
                    .name = undefined,
                    .items = []Little(u16) { toLittle(u16(19)), toLittle(u16(19)), toLittle(u16(19)), toLittle(u16(19)), },
                    .is_double = toLittle(u32(0)),
                    .ai = toLittle(u32(7)),
                    .party_size = toLittle(u32(6)),
                    .party_offset = undefined,
                },
            }),
        else => null,
    } ?? {
        return error.UnableToFindTrainerOffset;
    };

    const moves = findOffsetOfStructArray(gen3.Move, [][]const u8 { }, data,
        []gen3.Move {
            // Dummy
            gen3.Move {
                .effect = 0,
                .power = 0,
                .@"type" = common.Type.Normal,
                .accuracy = 0,
                .pp = 0,
                .side_effect_chance = 0,
                .target = 0,
                .priority = 0,
                .flags = toLittle(u32(0)),
            },
            // Pound
            gen3.Move {
                .effect = 0,
                .power = 40,
                .@"type" = common.Type.Normal,
                .accuracy = 100,
                .pp = 35,
                .side_effect_chance = 0,
                .target = 0,
                .priority = 0,
                .flags = toLittle(u32(0x33)),
            },
        },
        // Psycho Boost
        []gen3.Move {
            gen3.Move {
                .effect = 204,
                .power = 140,
                .@"type" = common.Type.Psychic,
                .accuracy = 90,
                .pp = 5,
                .side_effect_chance = 100,
                .target = 0,
                .priority = 0,
                .flags = toLittle(u32(0x32)),
            },
        }) ?? {
        return error.UnableToFindMoveOffset;
    };

    const tm_hm_learnset = findOffset(u8, data,
        []u8 {
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Dummy Pokémon
            0x20, 0x07, 0x35, 0x84, 0x08, 0x1e, 0xe4, 0x00, // Bulbasaur
            0x20, 0x07, 0x35, 0x84, 0x08, 0x1e, 0xe4, 0x00, // Ivysaur
            0x30, 0x47, 0x35, 0x86, 0x08, 0x1e, 0xe4, 0x00, // Venusaur
        },
        []u8 {
            0x3e, 0xd6, 0xbb, 0xb7, 0x93, 0x5e, 0x5c, 0x03, // Latios
            0x2c, 0xc6, 0x9b, 0xb5, 0x93, 0x8e, 0x40, 0x00, // Jirachi
            0x2d, 0xde, 0xbb, 0xf5, 0xc3, 0x8f, 0xe5, 0x00, // Deoxys
            0x28, 0x8e, 0x1b, 0xb4, 0x03, 0x9f, 0x41, 0x00, // Chimecho
        }) ?? {
        return error.UnableToFindTmHmLearnsetOffset;
    };

    const base_stats = findOffsetOfStructArray(gen3.BasePokemon, [][]const u8 { "padding", "egg_group1_pad", "egg_group2_pad" }, data,
        []gen3.BasePokemon {
            // Dummy
            gen3.BasePokemon {
                .hp         = 0,
                .attack     = 0,
                .defense    = 0,
                .speed      = 0,
                .sp_attack  = 0,
                .sp_defense = 0,

                .types = []common.Type { common.Type.Normal, common.Type.Normal },

                .catch_rate     = 0,
                .base_exp_yield = 0,

                .ev_yield = common.EvYield {
                    .hp         = 0,
                    .attack     = 0,
                    .defense    = 0,
                    .speed      = 0,
                    .sp_attack  = 0,
                    .sp_defense = 0,
                    .padding    = 0,
                },

                .items = []Little(u16) { toLittle(u16(0)), toLittle(u16(0)) },

                .gender_ratio    = 0,
                .egg_cycles      = 0,
                .base_friendship = 0,

                .growth_rate = common.GrowthRate.MediumFast,

                .egg_group1 = common.EggGroup.Invalid,
                .egg_group1_pad = undefined,
                .egg_group2 = common.EggGroup.Invalid,
                .egg_group2_pad = undefined,

                .abilities = []u8 { 0, 0 },
                .safari_zone_rate = 0,

                .color = common.Color.Red,
                .flip = false,

                .padding = undefined
            },
            // Bulbasaur
            gen3.BasePokemon {
                .hp         = 45,
                .attack     = 49,
                .defense    = 49,
                .speed      = 45,
                .sp_attack  = 65,
                .sp_defense = 65,

                .types = []common.Type { common.Type.Grass, common.Type.Poison },

                .catch_rate     = 45,
                .base_exp_yield = 64,

                .ev_yield = common.EvYield {
                    .hp         = 0,
                    .attack     = 0,
                    .defense    = 0,
                    .speed      = 0,
                    .sp_attack  = 1,
                    .sp_defense = 0,
                    .padding    = 0,
                },

                .items = []Little(u16) { toLittle(u16(0)), toLittle(u16(0)) },

                .gender_ratio    = comptime percentFemale(12.5),
                .egg_cycles      = 20,
                .base_friendship = 70,

                .growth_rate = common.GrowthRate.MediumSlow,

                .egg_group1 = common.EggGroup.Monster,
                .egg_group1_pad = undefined,
                .egg_group2 = common.EggGroup.Grass,
                .egg_group2_pad = undefined,

                .abilities = []u8 { 65, 0 },
                .safari_zone_rate = 0,

                .color = common.Color.Green,
                .flip = false,

                .padding = undefined
            },
        },
        []gen3.BasePokemon {
            // Chimecho
            gen3.BasePokemon {
                .hp         = 65,
                .attack     = 50,
                .defense    = 70,
                .speed      = 65,
                .sp_attack  = 95,
                .sp_defense = 80,

                .types = []common.Type { common.Type.Psychic, common.Type.Psychic },

                .catch_rate     = 45,
                .base_exp_yield = 147,

                .ev_yield = common.EvYield {
                    .hp         = 0,
                    .attack     = 0,
                    .defense    = 0,
                    .speed      = 0,
                    .sp_attack  = 1,
                    .sp_defense = 1,
                    .padding    = 0,
                },

                .items = []Little(u16) { toLittle(u16(0)), toLittle(u16(0)) },

                .gender_ratio    = comptime percentFemale(50),
                .egg_cycles      = 25,
                .base_friendship = 70,

                .growth_rate = common.GrowthRate.Fast,

                .egg_group1 = common.EggGroup.Amorphous,
                .egg_group1_pad = undefined,
                .egg_group2 = common.EggGroup.Amorphous,
                .egg_group2_pad = undefined,

                .abilities = []u8 { 26, 0 },
                .safari_zone_rate = 0,

                .color = common.Color.Blue,
                .flip = false,

                .padding = undefined
            },
        }) ?? {
        return error.UnableToFindBaseStatsOffset;
    };

    const unused_evo = gen3.Evolution {
        .@"type" = gen3.EvolutionType.Unused,
        .param = toLittle(u16(0)),
        .target = toLittle(u16(0)),
        .padding = undefined,
    };
    const evolution_table = findOffsetOfStructArray(gen3.Evolution, [][]const u8 { "padding" }, data,
        []gen3.Evolution {
            // Dummy
            unused_evo, unused_evo, unused_evo, unused_evo, unused_evo,

            // Bulbasaur
            gen3.Evolution {
                .@"type" = gen3.EvolutionType.LevelUp,
                .param = toLittle(u16(16)),
                .target = toLittle(u16(2)),
                .padding = undefined,
            },
            unused_evo, unused_evo, unused_evo, unused_evo,

            // Ivysaur
            gen3.Evolution {
                .@"type" = gen3.EvolutionType.LevelUp,
                .param = toLittle(u16(32)),
                .target = toLittle(u16(3)),
                .padding = undefined,
            },
            unused_evo, unused_evo, unused_evo, unused_evo,
        },
        []gen3.Evolution {
            // Beldum
            gen3.Evolution {
                .@"type" = gen3.EvolutionType.LevelUp,
                .param = toLittle(u16(20)),
                .target = toLittle(u16(399)),
                .padding = undefined,
            },
            unused_evo, unused_evo, unused_evo, unused_evo,

            // Metang
            gen3.Evolution {
                .@"type" = gen3.EvolutionType.LevelUp,
                .param = toLittle(u16(45)),
                .target = toLittle(u16(400)),
                .padding = undefined,
            },
            unused_evo, unused_evo, unused_evo, unused_evo,

            // Metagross, Regirock, Regice, Registeel, Kyogre, Groudon, Rayquaza
            // Latias, Latios, Jirachi, Deoxys, Chimecho
            unused_evo, unused_evo, unused_evo, unused_evo, unused_evo,
            unused_evo, unused_evo, unused_evo, unused_evo, unused_evo,
            unused_evo, unused_evo, unused_evo, unused_evo, unused_evo,
            unused_evo, unused_evo, unused_evo, unused_evo, unused_evo,
            unused_evo, unused_evo, unused_evo, unused_evo, unused_evo,
            unused_evo, unused_evo, unused_evo, unused_evo, unused_evo,
            unused_evo, unused_evo, unused_evo, unused_evo, unused_evo,
            unused_evo, unused_evo, unused_evo, unused_evo, unused_evo,
            unused_evo, unused_evo, unused_evo, unused_evo, unused_evo,
            unused_evo, unused_evo, unused_evo, unused_evo, unused_evo,
            unused_evo, unused_evo, unused_evo, unused_evo, unused_evo,
            unused_evo, unused_evo, unused_evo, unused_evo, unused_evo,
        }) ?? {
        return error.UnableToFindEvolutionTableOffset;
    };

    const level_up_learnset_pointers = blk: {
        const bulbasaur_bytes = []u8 {
                0x21, 0x02, 0x2D, 0x08, 0x49, 0x0E, 0x16, 0x14, 0x4D, 0x1E, 0x4F, 0x1E,
                0x4B, 0x28, 0xE6, 0x32, 0x4A, 0x40, 0xEB, 0x4E, 0x4C, 0x5C, 0xFF, 0xFF,
        };
        const bulbasaur_levelup = mem.indexOf(u8, data, bulbasaur_bytes) ?? return error.UnableToFindLevelUpLearnsetOffset;

        const ivysaur_bytes = []u8 {
                0x21, 0x02, 0x2D, 0x02, 0x49, 0x02, 0x2D, 0x08, 0x49, 0x0E, 0x16, 0x14,
                0x4D, 0x1E, 0x4F, 0x1E, 0x4B, 0x2C, 0xE6, 0x3A, 0x4A, 0x4C, 0xEB, 0x5E,
                0x4C, 0x70, 0xFF, 0xFF,
        };
        const ivysaur_levelup = mem.indexOf(u8, data, ivysaur_bytes) ?? return error.UnableToFindLevelUpLearnsetOffset;

        const venusaur_bytes = []u8 {
                0x21, 0x02, 0x2D, 0x02, 0x49, 0x02, 0x16, 0x02, 0x2D, 0x08, 0x49, 0x0E,
                0x16, 0x14, 0x4D, 0x1E, 0x4F, 0x1E, 0x4B, 0x2C, 0xE6, 0x3A, 0x4A, 0x52,
                0xEB, 0x6A, 0x4C, 0x82, 0xFF, 0xFF,
        };
        const venusaur_levelup = mem.indexOf(u8, data, venusaur_bytes) ?? return error.UnableToFindLevelUpLearnsetOffset;

        const latios_bytes = []u8 {
            0x95, 0x02, 0x06, 0x0B, 0x0E, 0x15, 0xDB, 0x1E, 0xE1, 0x28, 0xB6, 0x32, 0x1F,
            0x3D, 0x27, 0x47, 0x5E, 0x50, 0x69, 0x5A, 0x5D, 0x65, 0xFF, 0xFF,
        };
        const latios_levelup = mem.indexOf(u8, data, latios_bytes) ?? return error.UnableToFindLevelUpLearnsetOffset;

        const jirachi_bytes = []u8 {
            0x11, 0x03, 0x5D, 0x02, 0x9C, 0x0A, 0x81, 0x14, 0x0E, 0x1F, 0x5E, 0x28, 0x1F,
            0x33, 0x9C, 0x3C, 0x26, 0x46, 0xF8, 0x50, 0x42, 0x5B, 0x61, 0x65, 0xFF, 0xFF,
        };
        const jirachi_levelup = mem.indexOf(u8, data, jirachi_bytes) ?? return error.UnableToFindLevelUpLearnsetOffset;

        const chimecho_bytes = []u8 {
            0x23, 0x02, 0x2D, 0x0C, 0x36, 0x13, 0x5D, 0x1C, 0x24, 0x22, 0xFD, 0x2C, 0x19,
            0x33, 0x95, 0x3C, 0x26, 0x42, 0xD7, 0x4C, 0xDB, 0x52, 0x5E, 0x5C, 0xFF, 0xFF,
        };
        const chimecho_levelup = mem.indexOf(u8, data, chimecho_bytes) ?? return error.UnableToFindLevelUpLearnsetOffset;

        // Store all offsets as LE offsets (This is how they are stored on the rom,
        // and we wont to work on BE platforms too).
        const bulbasaur_pattern = utils.toBytes(u32, mem.readIntLE(u32, utils.toBytes(u32, u32(bulbasaur_levelup + 0x8000000))));
        const ivysaur_pattern   = utils.toBytes(u32, mem.readIntLE(u32, utils.toBytes(u32, u32(ivysaur_levelup   + 0x8000000))));
        const venusaur_pattern  = utils.toBytes(u32, mem.readIntLE(u32, utils.toBytes(u32, u32(venusaur_levelup  + 0x8000000))));

        const latios_pattern   = utils.toBytes(u32, mem.readIntLE(u32, utils.toBytes(u32, u32(latios_levelup   + 0x8000000))));
        const jirachi_pattern  = utils.toBytes(u32, mem.readIntLE(u32, utils.toBytes(u32, u32(jirachi_levelup  + 0x8000000))));
        const chimecho_pattern = utils.toBytes(u32, mem.readIntLE(u32, utils.toBytes(u32, u32(chimecho_levelup + 0x8000000))));

        const level_up_start = []?u8 {
            // Dummy mon has the same levelup moveset as bulbasaur
            bulbasaur_pattern[0], bulbasaur_pattern[1], bulbasaur_pattern[2], bulbasaur_pattern[3],
            bulbasaur_pattern[0], bulbasaur_pattern[1], bulbasaur_pattern[2], bulbasaur_pattern[3],
            ivysaur_pattern[0],   ivysaur_pattern[1],   ivysaur_pattern[2],   ivysaur_pattern[3],
            venusaur_pattern[0],  venusaur_pattern[1],  venusaur_pattern[2],  venusaur_pattern[3],
        };

        const level_up_end = []?u8 {
            latios_pattern[0],   latios_pattern[1],   latios_pattern[2],   latios_pattern[3],
            jirachi_pattern[0],  jirachi_pattern[1],  jirachi_pattern[2],  jirachi_pattern[3],
            // Deoxys have different moves between FRLG, RUSA and EM
            null,                null,                null,                null,
            chimecho_pattern[0], chimecho_pattern[1], chimecho_pattern[2], chimecho_pattern[3],
        };

        break :blk findOffsetUsingPattern(u8, data, level_up_start, level_up_end) ?? return error.UnableToFindLevelUpLearnsetOffset;
    };

    const hms = []u8 { 0x0f, 0x00, 0x13, 0x00, 0x39, 0x00, 0x46, 0x00, 0x94, 0x00, 0xf9, 0x00, 0x7f, 0x00, 0x23, 0x01, 0xff, 0xff, };
    const hms_start = mem.indexOf(u8, data, hms) ?? return error.UnableToFindHmOffset;
    const hms_offsets = Offset { .start = hms_start, .end = hms_start + hms.len };

    // TODO: Pokémon Emerald have 2 tm tables. I'll figure out some hack for that
    //       if it turns out that both tables are actually used. For now, I'll
    //       assume that the first table is the only one used.
    const tms = []u8 {
        0x08, 0x01, 0x51, 0x01, 0x60, 0x01, 0x5b, 0x01, 0x2e, 0x00, 0x5c, 0x00, 0x02, 0x01, 0x53, 0x01,
        0x4b, 0x01, 0xed, 0x00, 0xf1, 0x00, 0x0d, 0x01, 0x3a, 0x00, 0x3b, 0x00, 0x3f, 0x00, 0x71, 0x00,
        0xb6, 0x00, 0xf0, 0x00, 0xca, 0x00, 0xdb, 0x00, 0xda, 0x00, 0x4c, 0x00, 0xe7, 0x00, 0x55, 0x00,
        0x57, 0x00, 0x59, 0x00, 0xd8, 0x00, 0x5b, 0x00, 0x5e, 0x00, 0xf7, 0x00, 0x18, 0x01, 0x68, 0x00,
        0x73, 0x00, 0x5f, 0x01, 0x35, 0x00, 0xbc, 0x00, 0xc9, 0x00, 0x7e, 0x00, 0x3d, 0x01, 0x4c, 0x01,
        0x03, 0x01, 0x07, 0x01, 0x22, 0x01, 0x9c, 0x00, 0xd5, 0x00, 0xa8, 0x00, 0xd3, 0x00, 0x1d, 0x01,
        0x21, 0x01, 0x3b, 0x01, 0x0f, 0x00, 0x13, 0x00, 0x39, 0x00, 0x46, 0x00, 0x94, 0x00, 0xf9, 0x00,
        0x7f, 0x00, 0x23, 0x01,
    };
    const tms_start = mem.indexOf(u8, data, tms) ?? return error.UnableToFindTmOffset;
    const tms_offsets = Offset { .start = tms_start, .end = tms_start + tms.len };

    const ignored_item_fields = [][]const u8 { "name", "description_offset", "field_use_func", "battle_use_func" };
    const items = switch (version) {
        Version.Emerald => findOffsetOfStructArray(gen3.Item, ignored_item_fields, data,
        []gen3.Item {
            // ????????
            gen3.Item {
                .name               = undefined,
                .id                 = toLittle(u16(0)),
                .price              = toLittle(u16(0)),
                .hold_effect        = 0,
                .hold_effect_param  = 0,
                .description_offset = undefined,
                .importance         = 0,
                .unknown            = 0,
                .pocked             = 1,
                .@"type"            = 4,
                .field_use_func     = undefined,
                .battle_usage       = toLittle(u32(0)),
                .battle_use_func    = undefined,
                .secondary_id       = toLittle(u32(0)),
            },
            // MASTER BALL
            gen3.Item {
                .name               = undefined,
                .id                 = toLittle(u16(1)),
                .price              = toLittle(u16(0)),
                .hold_effect        = 0,
                .hold_effect_param  = 0,
                .description_offset = undefined,
                .importance         = 0,
                .unknown            = 0,
                .pocked             = 2,
                .@"type"            = 0,
                .field_use_func     = undefined,
                .battle_usage       = toLittle(u32(2)),
                .battle_use_func    = undefined,
                .secondary_id       = toLittle(u32(0)),
            },
        },
        []gen3.Item {
            // MAGMA EMBLEM
            gen3.Item {
                .name               = undefined,
                .id                 = toLittle(u16(0x177)),
                .price              = toLittle(u16(0)),
                .hold_effect        = 0,
                .hold_effect_param  = 0,
                .description_offset = undefined,
                .importance         = 1,
                .unknown            = 1,
                .pocked             = 5,
                .@"type"            = 4,
                .field_use_func     = undefined,
                .battle_usage       = toLittle(u32(0)),
                .battle_use_func    = undefined,
                .secondary_id       = toLittle(u32(0)),
            },
            // OLD SEA MAP
            gen3.Item {
                .name               = undefined,
                .id                 = toLittle(u16(0x178)),
                .price              = toLittle(u16(0)),
                .hold_effect        = 0,
                .hold_effect_param  = 0,
                .description_offset = undefined,
                .importance         = 1,
                .unknown            = 1,
                .pocked             = 5,
                .@"type"            = 4,
                .field_use_func     = undefined,
                .battle_usage       = toLittle(u32(0)),
                .battle_use_func    = undefined,
                .secondary_id       = toLittle(u32(0)),
            },
        }),
        Version.Ruby, Version.Shappire => findOffsetOfStructArray(gen3.Item, ignored_item_fields, data,
        []gen3.Item {
            // ????????
            gen3.Item {
                .name               = undefined,
                .id                 = toLittle(u16(0)),
                .price              = toLittle(u16(0)),
                .hold_effect        = 0,
                .hold_effect_param  = 0,
                .description_offset = undefined,
                .importance         = 0,
                .unknown            = 0,
                .pocked             = 1,
                .@"type"            = 4,
                .field_use_func     = undefined,
                .battle_usage       = toLittle(u32(0)),
                .battle_use_func    = undefined,
                .secondary_id       = toLittle(u32(0)),
            },
            // MASTER BALL
            gen3.Item {
                .name               = undefined,
                .id                 = toLittle(u16(1)),
                .price              = toLittle(u16(0)),
                .hold_effect        = 0,
                .hold_effect_param  = 0,
                .description_offset = undefined,
                .importance         = 0,
                .unknown            = 0,
                .pocked             = 2,
                .@"type"            = 0,
                .field_use_func     = undefined,
                .battle_usage       = toLittle(u32(2)),
                .battle_use_func    = undefined,
                .secondary_id       = toLittle(u32(0)),
            },
        },
        []gen3.Item {
            // HM08
            gen3.Item {
                .name               = undefined,
                .id                 = toLittle(u16(0x15A)),
                .price              = toLittle(u16(0)),
                .hold_effect        = 0,
                .hold_effect_param  = 0,
                .description_offset = undefined,
                .importance         = 1,
                .unknown            = 0,
                .pocked             = 3,
                .@"type"            = 1,
                .field_use_func     = undefined,
                .battle_usage       = toLittle(u32(0)),
                .battle_use_func    = undefined,
                .secondary_id       = toLittle(u32(0)),
            },
            // ????????
            gen3.Item {
                .name               = undefined,
                .id                 = toLittle(u16(0)),
                .price              = toLittle(u16(0)),
                .hold_effect        = 0,
                .hold_effect_param  = 0,
                .description_offset = undefined,
                .importance         = 0,
                .unknown            = 0,
                .pocked             = 1,
                .@"type"            = 4,
                .field_use_func     = undefined,
                .battle_usage       = toLittle(u32(0)),
                .battle_use_func    = undefined,
                .secondary_id       = toLittle(u32(0)),
            },
            // ????????
            gen3.Item {
                .name               = undefined,
                .id                 = toLittle(u16(0)),
                .price              = toLittle(u16(0)),
                .hold_effect        = 0,
                .hold_effect_param  = 0,
                .description_offset = undefined,
                .importance         = 0,
                .unknown            = 0,
                .pocked             = 1,
                .@"type"            = 4,
                .field_use_func     = undefined,
                .battle_usage       = toLittle(u32(0)),
                .battle_use_func    = undefined,
                .secondary_id       = toLittle(u32(0)),
            },
        }),
        Version.FireRed, Version.LeafGreen => findOffsetOfStructArray(gen3.Item, ignored_item_fields, data,
        []gen3.Item {
            gen3.Item {
                .name               = undefined,
                .id                 = toLittle(u16(0)),
                .price              = toLittle(u16(0)),
                .hold_effect        = 0,
                .hold_effect_param  = 0,
                .description_offset = undefined,
                .importance         = 0,
                .unknown            = 0,
                .pocked             = 1,
                .@"type"            = 4,
                .field_use_func     = undefined,
                .battle_usage       = toLittle(u32(0)),
                .battle_use_func    = undefined,
                .secondary_id       = toLittle(u32(0)),
            },
            gen3.Item {
                .name               = undefined,
                .id                 = toLittle(u16(1)),
                .price              = toLittle(u16(0)),
                .hold_effect        = 0,
                .hold_effect_param  = 0,
                .description_offset = undefined,
                .importance         = 0,
                .unknown            = 0,
                .pocked             = 3,
                .@"type"            = 0,
                .field_use_func     = undefined,
                .battle_usage       = toLittle(u32(2)),
                .battle_use_func    = undefined,
                .secondary_id       = toLittle(u32(0)),
            },
        },
        []gen3.Item {
            gen3.Item {
                .name               = undefined,
                .id                 = toLittle(u16(372)),
                .price              = toLittle(u16(0)),
                .hold_effect        = 0,
                .hold_effect_param  = 0,
                .description_offset = undefined,
                .importance         = 1,
                .unknown            = 1,
                .pocked             = 2,
                .@"type"            = 4,
                .field_use_func     = undefined,
                .battle_usage       = toLittle(u32(0)),
                .battle_use_func    = undefined,
                .secondary_id       = toLittle(u32(0)),
            },
            gen3.Item {
                .name               = undefined,
                .id                 = toLittle(u16(373)),
                .price              = toLittle(u16(0)),
                .hold_effect        = 0,
                .hold_effect_param  = 0,
                .description_offset = undefined,
                .importance         = 1,
                .unknown            = 1,
                .pocked             = 2,
                .@"type"            = 4,
                .field_use_func     = undefined,
                .battle_usage       = toLittle(u32(0)),
                .battle_use_func    = undefined,
                .secondary_id       = toLittle(u32(0)),
            },
        }),
        else => null,
    } ?? {
        return error.UnableToFindItemsOffset;
    };

    return Offsets {
        .header                     = header,
        .trainers                   = trainers,
        .moves                      = moves,
        .tm_hm_learnset             = tm_hm_learnset,
        .base_stats                 = base_stats,
        .evolution_table            = evolution_table,
        .level_up_learnset_pointers = level_up_learnset_pointers,
        .hms                        = hms_offsets,
        .tms                        = tms_offsets,
        .items                      = items,
    };
}

fn percentFemale(percent: f64) u8 {
    return u8(math.min(f64(254), (percent * 255) / 100));
}

fn findOffsetOfStructArray(comptime Struct: type, comptime ignored_fields: []const []const u8, data: []const u8, start: []const Struct, end: []const Struct) ?Offset {
    const start_index = indexOfStructsInBytes(Struct, ignored_fields, data, 0, start) ?? return null;
    const end_index = indexOfStructsInBytes(Struct, ignored_fields, data, start_index, end) ?? return null;

    return Offset {
        .start = start_index,
        .end = end_index + end.len * @sizeOf(Struct),
    };
}

fn indexOfStructsInBytes(comptime Struct: type, comptime ignored_fields: []const []const u8, data: []const u8, start_index: usize, structs: []const Struct) ?usize {
    const structs_len_in_bytes = structs.len * @sizeOf(Struct);
    if (data.len < structs_len_in_bytes) return null;

    var i : usize = start_index;
    var end = data.len - structs_len_in_bytes;
    while (i <= end) : (i += 1) {
        if (structsMatchesBytes(Struct, ignored_fields, data[i..i + structs_len_in_bytes], structs)) {
            return i;
        }
    }

    return null;
}

fn structsMatchesBytes(comptime Struct: type, comptime ignored_fields: []const []const u8, data: []const u8, structs: []const Struct) bool {
    const structs_len_in_bytes = structs.len * @sizeOf(Struct);
    if (data.len != structs_len_in_bytes) return false;

    for (structs) |s, s_i| {
        const data_bytes = data[s_i * @sizeOf(Struct)..];
        const s_bytes = utils.toBytes(Struct, s);

        comptime var i = 0;
        comptime var byte_offset = 0;
        inline while (i < @memberCount(Struct)) : (i += 1) {
            const member_name = @memberName(Struct, i)[0..];
            if (comptime contains([]const u8, ignored_fields, member_name, strEql)) continue;

            const member_start = @offsetOf(Struct, member_name);
            const member_end = @sizeOf(@memberType(Struct, i)) + member_start;
            if (!mem.eql(u8, data_bytes[member_start..member_end], s_bytes[member_start..member_end])) return false;
        }
    }

    return true;
}

fn strEql(a: &const []const u8, b: &const []const u8) bool {
    return mem.eql(u8, *a, *b);
}

fn contains(comptime T: type, items: []const T, value: &const T, eql: fn(&const T, &const T) bool) bool {
    for (items) |item| {
        if (eql(item, value)) return true;
    }

    return false;
}

/// Finds the start and end index based on a start and end pattern.
fn findOffsetUsingPattern(comptime T: type, data: []const T, start: []const ?T, end: []const ?T) ?Offset {
    const start_index = indexOfPattern(T, data, 0, start) ?? return null;
    const end_index = indexOfPattern(T, data, start_index, end) ?? return null;

    return Offset {
        .start = start_index,
        .end = end_index + end.len,
    };
}

/// Finds the start and end index based on a start and end.
fn findOffset(comptime T: type, data: []const T, start: []const T, end: []const T) ?Offset {
    const start_index = mem.indexOf(T, data, start) ?? return null;
    const end_index = mem.indexOfPos(T, data, start_index, end) ?? return null;

    return Offset {
        .start = start_index,
        .end = end_index + end.len,
    };
}

fn indexOfPattern(comptime T: type, data: []const T, start_index: usize, pattern: []const ?T) ?usize {
    if (data.len < pattern.len) return null;

    var i : usize = start_index;
    var end = data.len - pattern.len;
    while (i <= end) : (i += 1) {
        if (matchesPattern(T, data[i..i + pattern.len], pattern)) {
            return i;
        }
    }

    return null;
}

/// Given data and a "pattern", returns if the data matches the pattern.
/// For now, a pattern is just data that might contain wild card values, aka
/// values that always match.
fn matchesPattern(comptime T: type, data: []const T, pattern: []const ?T) bool {
    if (data.len != pattern.len) return false;

    for (pattern) |pat, i| {
        if (pat) |value| {
            if (data[i] != value) return false;
        }
    }

    return true;
}
