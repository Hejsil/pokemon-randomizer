const std = @import("std");
const gba = @import("gba");

const os    = std.os;
const debug = std.debug;
const mem   = std.mem;
const io    = std.io;

error NoFileInArguments;
error UnknownPokemonVersion;
error UnableToFindOffset;

pub fn main() %void {
    // TODO: Use Zig's own general purpose allocator... When it has one.
    var inc_allocator = try std.heap.IncrementingAllocator.init(1024 * 1024 * 1024);
    defer inc_allocator.deinit();
    const allocator = &inc_allocator.allocator;

    var stdout = try io.getStdOut();
    var stdout_file_stream = io.FileOutStream.init(&stdout);
    var stdout_stream = &stdout_file_stream.stream;

    const args = try os.argsAlloc(allocator);
    defer os.argsFree(allocator, args);

    if (args.len != 2) {
        try stdout_stream.print("No file was provided.\n");
        return error.NoFileInArguments;
    }

    var file = io.File.openRead(args[1], null) catch |err| {
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
        Version.Emerald => findOffset(u8, data,
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
        Version.Ruby, Version.Shappire => findOffset(u8, data,
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
        []?u8 {
            // Dummy bytes
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,

            // Pound bytes
            0x00, 0x28, 0x00, 0x64, 0x23, 0x00, 0x00, 0x00, 0x33, 0x00, 0x00, 0x00,
        },
        []?u8 {
            // Psycho Boost bytes
            0xcc, 0x8c, 0x0e, 0x5a, 0x05, 0x64, 0x00, 0x00, 0x32, 0x00, 0x00, 0x00,
        }) ?? {
        try stdout_stream.print("Unable to find moves offset.\n");
        return error.UnableToFindOffset;
    };

    // https://github.com/pret/pokeemerald/blob/master/data/tm_hm_learnsets.inc
    const tm_hm_learnset = findOffset(u8, data,
        []?u8 {
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Dummy Pokémon
            0x20, 0x07, 0x35, 0x84, 0x08, 0x1e, 0xe4, 0x00, // Bulbasaur
            0x20, 0x07, 0x35, 0x84, 0x08, 0x1e, 0xe4, 0x00, // Ivysaur
            0x30, 0x47, 0x35, 0x86, 0x08, 0x1e, 0xe4, 0x00, // Venusaur
        },
        []?u8 {
            0x3e, 0xd6, 0xbb, 0xb7, 0x93, 0x5e, 0x5c, 0x03, // Latios
            0x2c, 0xc6, 0x9b, 0xb5, 0x93, 0x8e, 0x40, 0x00, // Jirachi
            0x2d, 0xde, 0xbb, 0xf5, 0xc3, 0x8f, 0xe5, 0x00, // Deoxys
            0x28, 0x8e, 0x1b, 0xb4, 0x03, 0x9f, 0x41, 0x00, // Chimecho
        }) ?? {
        try stdout_stream.print("Unable to find tm_hm_learnset offset.\n");
        return error.UnableToFindOffset;
    };

    const base_stats = findOffset(u8, data,
        []?u8 {
            // Dummy mon bytes
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,

            // Bulbasaur bytes
            0x2D, 0x31, 0x31, 0x2D, 0x41, 0x41, 0x0C, 0x03, 0x2D, 0x40, 0x00, 0x01, 0x00, 0x00,
            0x00, 0x00, 0x1F, 0x14, 0x46, 0x03, 0x01, 0x07, 0x41, 0x00, 0x00, 0x03, 0x00, 0x00,
        },
        []?u8 {
            // Chimecho bytes
            0x41, 0x32, 0x46, 0x41, 0x5f, 0x50, 0x0e, 0x0e, 0x2d, 0x93, 0x00, 0x05, 0x00, 0x00,
            0x00, 0x00, 0x7f, 0x19, 0x46, 0x04, 0x0b, 0x0b, 0x1a, 0x00, 0x00, 0x01, 0x00, 0x00,
        }) ?? {
        try stdout_stream.print("Unable to find base_stats offset.\n");
        return error.UnableToFindOffset;
    };

    // TODO:
    // evolution_table
    // level_up_learnset_pointers
    // hms
    // items
    // tms

    try stdout_stream.print("game_title: {}\n", header.game_title);
    try stdout_stream.print("gamecode: {}\n", header.gamecode);
    try stdout_stream.print(".trainers       = {{ .start = 0x{x7}, .end = 0x{x7}, }},\n", trainers.start, trainers.end);
    try stdout_stream.print(".moves          = {{ .start = 0x{x7}, .end = 0x{x7}, }},\n", moves.start, moves.end);
    try stdout_stream.print(".tm_hm_learnset = {{ .start = 0x{x7}, .end = 0x{x7}, }},\n", tm_hm_learnset.start, tm_hm_learnset.end);
    try stdout_stream.print(".base_stats     = {{ .start = 0x{x7}, .end = 0x{x7}, }},\n", base_stats.start, base_stats.end);
}

const Version = enum {
    Ruby, Shappire, Emerald, FireRed, LeafGreen,
};

const Offset = struct {
    start: usize,
    end: usize,
};

/// Finds the start and end index based on a start and end pattern.
fn findOffset(comptime T: type, data: []const T, start: []const ?T, end: []const ?T) ?Offset {
    const start_index = indexOfPattern(T, data, 0, start) ?? return null;
    const end_index = indexOfPattern(T, data, start_index, end) ?? return null;

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