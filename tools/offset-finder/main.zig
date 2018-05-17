const std = @import("std");
const gen3 = @import("gen3.zig");

const io     = std.io;
const os     = std.os;
const debug  = std.debug;

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

        if (gen3.findInfoInFile(&file, allocator)) |info| {
            defer allocator.free(info.gamecode);

            // TODO: Write start offset and length in items insead of start and end. This is to avoid "slice widening size mismatch"
            try stdout.print("gamecode: {}\n", info.gamecode);
            try stdout.print(".trainers                   = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", info.trainers.start,                   info.trainers.end);
            try stdout.print(".moves                      = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", info.moves.start,                      info.moves.end);
            try stdout.print(".tm_hm_learnset             = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", info.tm_hm_learnset.start,             info.tm_hm_learnset.end);
            try stdout.print(".base_stats                 = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", info.base_stats.start,                 info.base_stats.end);
            try stdout.print(".evolution_table            = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", info.evolution_table.start,            info.evolution_table.end);
            try stdout.print(".level_up_learnset_pointers = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", info.level_up_learnset_pointers.start, info.level_up_learnset_pointers.end);
            try stdout.print(".hms                        = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", info.hms.start,                        info.hms.end);
            try stdout.print(".tms                        = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", info.tms.start,                        info.tms.end);
            try stdout.print(".items                      = Offset {{ .start = 0x{X7}, .end = 0x{X7}, }},\n", info.items.start,                      info.items.end);
        } else |err| {
            // TODO: This is the starting point for error messages. They should probably be better, but at least
            //       all errors from "findInfoInFile" are handled in this switch.
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
                error.OutOfMemory                       => debug.warn("Ran out of memory.\n"),
                error.BadFd                             => debug.warn("BadFd.\n"),
                error.Unexpected                        => debug.warn("An unexpected error occured.\n"),
                error.StreamTooLong                     => debug.warn("StreamTooLong.\n"),
                error.Overflow                          => debug.warn("Overflow.\n"),
                error.EndOfStream                       => debug.warn("EndOfStream.\n"),
                else => unreachable,
            }

            return err;
        }

    }
}

//fn getVersion(file: &os.File) struct { gamecode: []const u8, }
