const std = @import("std");
const gba = @import("gba");

const os    = std.os;
const debug = std.debug;
const mem   = std.mem;
const io    = std.io;





pub fn main() !void {
    // TODO: Use Zig's own general purpose allocator... When it has one.
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();
    const allocator = &direct_allocator.allocator;

    var stdout = try io.getStdOut();
    var stdout_file_stream = io.FileOutStream.init(&stdout);
    var stdout_stream = &stdout_file_stream.stream;

    const args = try os.argsAlloc(allocator);
    defer os.argsFree(allocator, args);

    if (args.len != 2) {
        try stdout_stream.print("No file was provided.\n");
        return error.NoFileInArguments;
    }

    var file = os.File.openRead(allocator, args[1]) catch |err| {
        try stdout_stream.print("Couldn't open {}.\n", args[1]);
        return err;
    };
    defer file.close();

    var file_stream = io.FileInStream.init(&file);
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
    } else {
        return error.UnknownPokemonVersion;
    };

    const data = try stream.readAllAlloc(allocator, @maxValue(usize));
    defer allocator.free(data);

    const trainers = switch (version) {
        // https://github.com/pret/pokeemerald/blob/master/data/trainers.inc
        Version.Emerald => findOffsetUsingPattern(u8, data,
            []?u8 {
                // Dummy trainer bytes
                0x00, 0x00, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, null, null, null,
                null, // The 4 last bytes of trainers are an offset to their party. This is
                      // not at all the same across games, so we wildcard it.

                // SAWYER_1 trainer bytes
                0x00, 0x02, 0x0b, 0x00, 0xcd, 0xbb, 0xd1, 0xd3, 0xbf, 0xcc, 0xff, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x07, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, null, null, null,
                null,
            },
            []?u8 {
                // MAY_16 trainer bytes
                0x00, 0x41, 0x80, 0x5c, 0xc7, 0xbb, 0xd3, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, null, null, null,
                null,
            }),
        // https://github.com/pret/pokeruby/blob/master/data/trainers.inc
        Version.Ruby, Version.Shappire => findOffsetUsingPattern(u8, data,
            []?u8 {
                // Dummy trainer bytes
                0x00, 0x00, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, null, null, null,
                null,

                // ARCHIE_1 trainer bytes
                0x00, 0x02, 0x06, 0x46, 0xbb, 0xcc, 0xbd, 0xc2, 0xc3, 0xbf, 0xff, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x16, 0x00, 0x16, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x07, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, null, null, null,
                null,
            },
            []?u8 {
                // EUGENE trainer bytes
                0x00, 0x21, 0x0B, 0x06, 0xbd, 0xc6, 0xbb, 0xcf, 0xbe, 0xbf, 0xff, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, null, null, null,
                null,
            }),
        else => unreachable,
    } ?? {
        try stdout_stream.print("Unable to find trainers offset.\n");
        return error.UnableToFindOffset;
    };

    // https://github.com/pret/pokeemerald/blob/master/data/battle_moves.inc
    const moves = findOffset(u8, data,
        []u8 {
            // Dummy bytes
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,

            // Pound bytes
            0x00, 0x28, 0x00, 0x64, 0x23, 0x00, 0x00, 0x00, 0x33, 0x00, 0x00, 0x00,
        },
        []u8 {
            // Psycho Boost bytes
            0xcc, 0x8c, 0x0e, 0x5a, 0x05, 0x64, 0x00, 0x00, 0x32, 0x00, 0x00, 0x00,
        }) ?? {
        try stdout_stream.print("Unable to find moves offset.\n");
        return error.UnableToFindOffset;
    };

    // https://github.com/pret/pokeemerald/blob/master/data/tm_hm_learnsets.inc
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
        try stdout_stream.print("Unable to find tm_hm_learnset offset.\n");
        return error.UnableToFindOffset;
    };

    const base_stats = findOffset(u8, data,
        []u8 {
            // Dummy mon bytes
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,

            // Bulbasaur bytes
            0x2D, 0x31, 0x31, 0x2D, 0x41, 0x41, 0x0C, 0x03, 0x2D, 0x40, 0x00, 0x01, 0x00, 0x00,
            0x00, 0x00, 0x1F, 0x14, 0x46, 0x03, 0x01, 0x07, 0x41, 0x00, 0x00, 0x03, 0x00, 0x00,
        },
        []u8 {
            // Chimecho bytes
            0x41, 0x32, 0x46, 0x41, 0x5f, 0x50, 0x0e, 0x0e, 0x2d, 0x93, 0x00, 0x05, 0x00, 0x00,
            0x00, 0x00, 0x7f, 0x19, 0x46, 0x04, 0x0b, 0x0b, 0x1a, 0x00, 0x00, 0x01, 0x00, 0x00,
        }) ?? {
        try stdout_stream.print("Unable to find base_stats offset.\n");
        return error.UnableToFindOffset;
    };

    const zero_evo = []u8 { 0x00 } ** 8;
    const zero_evo_table = zero_evo ** 5;
    const evolution_table = findOffset(u8, data,
        // Dummy mon
        zero_evo_table ++

        // Bulbasaur
        []u8 { 0x04, 0x00, 0x10, 0x00, 0x02, 0x00, 0x00, 0x00, } ++
        zero_evo ** 4 ++

        // Ivysaur
        []u8 { 0x04, 0x00, 0x20, 0x00, 0x03, 0x00, 0x00, 0x00, } ++
        zero_evo ** 4,
        // ---------------------------------------------------------------------
        // Beldum
        []u8 { 0x04, 0x00, 0x14, 0x00, 0x8F, 0x01, 0x00, 0x00, } ++
        zero_evo ** 4 ++

        // Metang
        []u8 { 0x04, 0x00, 0x2D, 0x00, 0x90, 0x01, 0x00, 0x00, } ++
        zero_evo ** 4 ++

        // Metagross, Regirock, Regice, Registeel, Kyogre, Groudon, Rayquaza
        // Latias, Latios, Jirachi, Deoxys, Chimecho
        zero_evo_table ** 12) ?? {
        try stdout_stream.print("Unable to find evolution_table offset.\n");
        return error.UnableToFindOffset;
    };

    const level_up_learnset_pointers = blk: {
        const bulbasaur_levelup = mem.indexOf(u8, data, []u8 {
                0x21, 0x02, 0x2D, 0x08, 0x49, 0x0E, 0x16, 0x14, 0x4D, 0x1E, 0x4F, 0x1E, 0x4B, 0x28, 0xE6, 0x32, 0x4A, 0x40, 0xEB, 0x4E, 0x4C, 0x5C, 0xFF, 0xFF,
            }) ?? {
            try stdout_stream.print("Unable to find Bulbasaur levelup learnset.\n");
            return error.UnableToFindOffset;
        };

        const ivysaur_levelup = mem.indexOf(u8, data, []u8 {
                0x21, 0x02, 0x2D, 0x02, 0x49, 0x02, 0x2D, 0x08, 0x49, 0x0E, 0x16, 0x14, 0x4D, 0x1E, 0x4F, 0x1E, 0x4B, 0x2C, 0xE6, 0x3A, 0x4A, 0x4C, 0xEB, 0x5E, 0x4C, 0x70, 0xFF, 0xFF,
            }) ?? {
            try stdout_stream.print("Unable to find Ivysaur levelup learnset.\n");
            return error.UnableToFindOffset;
        };

        const venusaur_levelup = mem.indexOf(u8, data, []u8 {
                0x21, 0x02, 0x2D, 0x02, 0x49, 0x02, 0x16, 0x02, 0x2D, 0x08, 0x49, 0x0E, 0x16, 0x14, 0x4D, 0x1E, 0x4F, 0x1E, 0x4B, 0x2C, 0xE6, 0x3A, 0x4A, 0x52, 0xEB, 0x6A, 0x4C, 0x82, 0xFF, 0xFF,
            }) ?? {
            try stdout_stream.print("Unable to find Venusaur levelup learnset.\n");
            return error.UnableToFindOffset;
        };

        const latios_levelup = mem.indexOf(u8, data, []u8 {
            0x95, 0x02, 0x06, 0x0B, 0x0E, 0x15, 0xDB, 0x1E, 0xE1, 0x28, 0xB6, 0x32, 0x1F, 0x3D, 0x27, 0x47, 0x5E, 0x50, 0x69, 0x5A, 0x5D, 0x65, 0xFF, 0xFF,
            }) ?? {
            try stdout_stream.print("Unable to find Latios levelup learnset.\n");
            return error.UnableToFindOffset;
        };

        const jirachi_levelup = mem.indexOf(u8, data, []u8 {
                0x11, 0x03, 0x5D, 0x02, 0x9C, 0x0A, 0x81, 0x14, 0x0E, 0x1F, 0x5E, 0x28, 0x1F, 0x33, 0x9C, 0x3C, 0x26, 0x46, 0xF8, 0x50, 0x42, 0x5B, 0x61, 0x65, 0xFF, 0xFF,
            }) ?? {
            try stdout_stream.print("Unable to find Jirachi levelup learnset.\n");
            return error.UnableToFindOffset;
        };

        const chimecho_levelup = mem.indexOf(u8, data, []u8 {
                0x23, 0x02, 0x2D, 0x0C, 0x36, 0x13, 0x5D, 0x1C, 0x24, 0x22, 0xFD, 0x2C, 0x19, 0x33, 0x95, 0x3C, 0x26, 0x42, 0xD7, 0x4C, 0xDB, 0x52, 0x5E, 0x5C, 0xFF, 0xFF,
            }) ?? {
            try stdout_stream.print("Unable to find Chimecho levelup learnset.\n");
            return error.UnableToFindOffset;
        };

        // Store all offsets as LE offsets (This is how they are stored on the rom,
        // and we wont to work on BE platforms too).
        const bulbasaur_pattern = asConstBytes(u32, mem.readIntLE(u32, asConstBytes(u32, u32(bulbasaur_levelup + 0x8000000))));
        const ivysaur_pattern   = asConstBytes(u32, mem.readIntLE(u32, asConstBytes(u32, u32(ivysaur_levelup   + 0x8000000))));
        const venusaur_pattern  = asConstBytes(u32, mem.readIntLE(u32, asConstBytes(u32, u32(venusaur_levelup  + 0x8000000))));

        const latios_pattern   = asConstBytes(u32, mem.readIntLE(u32, asConstBytes(u32, u32(latios_levelup   + 0x8000000))));
        const jirachi_pattern  = asConstBytes(u32, mem.readIntLE(u32, asConstBytes(u32, u32(jirachi_levelup  + 0x8000000))));
        const chimecho_pattern = asConstBytes(u32, mem.readIntLE(u32, asConstBytes(u32, u32(chimecho_levelup + 0x8000000))));

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

        break :blk findOffsetUsingPattern(u8, data, level_up_start, level_up_end) ?? {
            try stdout_stream.print("Unable to find level_up_learnset_pointers offset.\n");
            return error.UnableToFindOffset;
        };
    };

    const hms = []u8 { 0x0f, 0x00, 0x13, 0x00, 0x39, 0x00, 0x46, 0x00, 0x94, 0x00, 0xf9, 0x00, 0x7f, 0x00, 0x23, 0x01, 0xff, 0xff, };
    const hms_start = mem.indexOf(u8, data, hms) ?? {
        try stdout_stream.print("Unable to find hms offset.\n");
        return error.UnableToFindOffset;
    };
    const hms_offsets = Offset { .start = hms_start, .end = hms_start + hms.len };
    // TODO:
    // tms

    const items = switch (version) {
        Version.Emerald => findOffsetUsingPattern(u8, data,
        []?u8 {
            // ????????
            null, null, null, null, null, null, null, null, null, null, null, null, null, null, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, null, null, null, null, 0x00, 0x00, 0x01, 0x04, null, null, null, null,
            0x00, 0x00, 0x00, 0x00, null, null, null, null, 0x00, 0x00, 0x00, 0x00,
            // MASTER BALL
            null, null, null, null, null, null, null, null, null, null, null, null, null, null, 0x01, 0x00,
            0x00, 0x00, 0x00, 0x00, null, null, null, null, 0x00, 0x00, 0x02, 0x00, null, null, null, null,
            0x02, 0x00, 0x00, 0x00, null, null, null, null, 0x00, 0x00, 0x00, 0x00,
        },
        []?u8 {
            // MAGMA EMBLEM
            null, null, null, null, null, null, null, null, null, null, null, null, null, null, 0x77, 0x01,
            0x00, 0x00, 0x00, 0x00, null, null, null, null, 0x01, 0x01, 0x05, 0x04, null, null, null, null,
            0x00, 0x00, 0x00, 0x00, null, null, null, null, 0x00, 0x00, 0x00, 0x00,
            // OLD SEA MAP
            null, null, null, null, null, null, null, null, null, null, null, null, null, null, 0x78, 0x01,
            0x00, 0x00, 0x00, 0x00, null, null, null, null, 0x01, 0x01, 0x05, 0x04, null, null, null, null,
            0x00, 0x00, 0x00, 0x00, null, null, null, null, 0x00, 0x00, 0x00, 0x00,
        }),
        Version.Ruby, Version.Shappire => findOffsetUsingPattern(u8, data,
        []?u8 {
            // ????????
            null, null, null, null, null, null, null, null, null, null, null, null, null, null, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, null, null, null, null, 0x00, 0x00, 0x01, 0x04, null, null, null, null,
            0x00, 0x00, 0x00, 0x00, null, null, null, null, 0x00, 0x00, 0x00, 0x00,
            // MASTER BALL
            null, null, null, null, null, null, null, null, null, null, null, null, null, null, 0x01, 0x00,
            0x00, 0x00, 0x00, 0x00, null, null, null, null, 0x00, 0x00, 0x02, 0x00, null, null, null, null,
            0x02, 0x00, 0x00, 0x00, null, null, null, null, 0x00, 0x00, 0x00, 0x00,
        },
        []?u8 {
            // HM08
            null, null, null, null, null, null, null, null, null, null, null, null, null, null, 0x5A, 0x01,
            0x00, 0x00, 0x00, 0x00, null, null, null, null, 0x01, 0x00, 0x03, 0x01, null, null, null, null,
            0x00, 0x00, 0x00, 0x00, null, null, null, null, 0x00, 0x00, 0x00, 0x00,
            // ????????
            null, null, null, null, null, null, null, null, null, null, null, null, null, null, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, null, null, null, null, 0x00, 0x00, 0x01, 0x04, null, null, null, null,
            0x00, 0x00, 0x00, 0x00, null, null, null, null, 0x00, 0x00, 0x00, 0x00,
            // ????????
            null, null, null, null, null, null, null, null, null, null, null, null, null, null, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, null, null, null, null, 0x00, 0x00, 0x01, 0x04, null, null, null, null,
            0x00, 0x00, 0x00, 0x00, null, null, null, null, 0x00, 0x00, 0x00, 0x00,
        }),
        else => unreachable,
    } ?? {
        try stdout_stream.print("Unable to find items offset.\n");
        return error.UnableToFindOffset;
    };

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
    const tms_start = mem.indexOf(u8, data, tms) ?? {
        try stdout_stream.print("Unable to find tms offset.\n");
        return error.UnableToFindOffset;
    };
    const tms_offsets = Offset { .start = tms_start, .end = tms_start + tms.len };

    try stdout_stream.print("game_title: {}\n", header.game_title);
    try stdout_stream.print("gamecode: {}\n", header.gamecode);
    try stdout_stream.print(".trainers                   = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", trainers.start, trainers.end);
    try stdout_stream.print(".moves                      = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", moves.start, moves.end);
    try stdout_stream.print(".tm_hm_learnset             = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", tm_hm_learnset.start, tm_hm_learnset.end);
    try stdout_stream.print(".base_stats                 = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", base_stats.start, base_stats.end);
    try stdout_stream.print(".evolution_table            = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", evolution_table.start, evolution_table.end);
    try stdout_stream.print(".level_up_learnset_pointers = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", level_up_learnset_pointers.start, level_up_learnset_pointers.end);
    try stdout_stream.print(".hms                        = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", hms_offsets.start, hms_offsets.end);
    try stdout_stream.print(".items                      = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", items.start, items.end);
    try stdout_stream.print(".tms                        = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", tms_offsets.start, tms_offsets.end);
}

fn asConstBytes(comptime T: type, value: &const T) []const u8 {
    return ([]const u8)(value[0..1]);
}

const Version = enum {
    Ruby, Shappire, Emerald, FireRed, LeafGreen,
};

const Offset = struct {
    start: usize,
    end: usize,
};

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
