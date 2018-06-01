const std     = @import("std");
const pokemon = @import("pokemon");
const gba     = @import("gba");
const gb      = @import("gb");
const gen3    = @import("gen3.zig");
const gen2    = @import("gen2.zig");

const io     = std.io;
const os     = std.os;
const mem    = std.mem;
const debug  = std.debug;

const common = pokemon.common;

pub fn main() !void {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

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

        var file_stream = io.FileInStream.init(&file);
        var stream = &file_stream.stream;
        const data = try stream.readAllAlloc(allocator, @maxValue(usize));
        defer allocator.free(data);

        var gamecode: []const u8 = undefined;
        const version = blk: {
            const gba_gamecode = gbaGamecode(data);
            const gb_gamecode = gbGamecode(data);
            const gb_title = gbTitle(data);

            if (getVersion(gba_gamecode)) |v| {
                gamecode = gba_gamecode;
                break :blk v;
            } else |err1| if (getVersion(gb_gamecode)) |v| {
                gamecode = gb_gamecode;
                break :blk v;
            } else |err2| if (getVersion(gb_title)) |v| {
                gamecode = gb_title;
                break :blk v;
            } else |err3| {
                debug.warn("Neither gba gamecode '{}', gb gamecode '{}' or gb title '{}' correspond with any Pokemon game.\n", gba_gamecode, gb_gamecode, gb_title);
                return err3;
            }
        };

        debug.warn("Gamecode: {}\n", gamecode);
        debug.warn("Game: {}\n", @tagName(version));
        debug.warn("Generation: {}\n", @tagName(version.generation()));

        switch (version.generation()) {
            common.Generation.I => unreachable,
            common.Generation.II => {
                const info = try gen2.findInfoInFile(data, version, allocator);

                debug.warn(".base_stats = Offset {{ .start = 0x{X7}, .len = {d3}, }},\n", info.base_stats.start, info.base_stats.len);
            },
            common.Generation.III => {
                const info = try gen3.findInfoInFile(data, version);

                debug.warn(".trainers                   = Offset {{ .start = 0x{X7}, .len = {d3}, }},\n", info.trainers.start,                   info.trainers.len);
                debug.warn(".moves                      = Offset {{ .start = 0x{X7}, .len = {d3}, }},\n", info.moves.start,                      info.moves.len);
                debug.warn(".tm_hm_learnset             = Offset {{ .start = 0x{X7}, .len = {d3}, }},\n", info.tm_hm_learnset.start,             info.tm_hm_learnset.len);
                debug.warn(".base_stats                 = Offset {{ .start = 0x{X7}, .len = {d3}, }},\n", info.base_stats.start,                 info.base_stats.len);
                debug.warn(".evolution_table            = Offset {{ .start = 0x{X7}, .len = {d3}, }},\n", info.evolution_table.start,            info.evolution_table.len);
                debug.warn(".level_up_learnset_pointers = Offset {{ .start = 0x{X7}, .len = {d3}, }},\n", info.level_up_learnset_pointers.start, info.level_up_learnset_pointers.len);
                debug.warn(".hms                        = Offset {{ .start = 0x{X7}, .len = {d3}, }},\n", info.hms.start,                        info.hms.len);
                debug.warn(".tms                        = Offset {{ .start = 0x{X7}, .len = {d3}, }},\n", info.tms.start,                        info.tms.len);
                debug.warn(".items                      = Offset {{ .start = 0x{X7}, .len = {d3}, }},\n", info.items.start,                      info.items.len);
            },
            else => unreachable,
        }
    }
}

fn getVersion(gamecode: []const u8) !common.Version {
    if (mem.startsWith(u8, gamecode, "BPE"))
        return common.Version.Emerald;
    if (mem.startsWith(u8, gamecode, "BPR"))
       return common.Version.FireRed;
    if (mem.startsWith(u8, gamecode, "BPG"))
        return common.Version.LeafGreen;
    if (mem.startsWith(u8, gamecode, "AXV"))
        return common.Version.Ruby;
    if (mem.startsWith(u8, gamecode, "AXP"))
        return common.Version.Sapphire;
    if (mem.startsWith(u8, gamecode, "AAX"))
        return common.Version.Silver;
    if (mem.startsWith(u8, gamecode, "AAU"))
        return common.Version.Gold;
    if (mem.startsWith(u8, gamecode, "BYT"))
        return common.Version.Crystal;
    if (mem.startsWith(u8, gamecode, "POKEMON RED"))
        return common.Version.Red;
    if (mem.startsWith(u8, gamecode, "POKEMON BLUE"))
        return common.Version.Blue;
    if (mem.startsWith(u8, gamecode, "POKEMON YELLOW"))
        return common.Version.Yellow;

    return error.UnknownPokemonVersion;
}

fn gbaGamecode(data: []const u8) []const u8 {
    const header = &([]const gba.Header)(data[0..@sizeOf(gba.Header)])[0];
    return header.gamecode;
}

fn gbGamecode(data: []const u8) []const u8 {
    const header = &([]const gb.Header)(data[0..@sizeOf(gb.Header)])[0];
    return header.title.split.gamecode;
}

fn gbTitle(data: []const u8) []const u8 {
    const header = &([]const gb.Header)(data[0..@sizeOf(gb.Header)])[0];
    return header.title.full;
}
