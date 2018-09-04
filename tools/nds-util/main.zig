const std = @import("std");
const utils = @import("utils");
// TODO: When https://github.com/zig-lang/zig/issues/855 is fixed. Make this into a package import instead of this HACK
const nds = @import("../../src/nds/index.zig");

const heap = std.heap;
const os = std.os;
const io = std.io;
const fmt = std.fmt;
const mem = std.mem;
const debug = std.debug;
const path = os.path;

/// For now, this tool only extracts nds roms to a folder of the same name.
/// Later on, we probably want to be able to create a nds file from a folder too.
/// Basicly, this is a replacement for ndstool.
pub fn main() !void {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();
    var arena = std.heap.ArenaAllocator.init(&direct_allocator.allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    var stdout_handle = try io.getStdOut();
    var stdout_file_stream = io.FileOutStream.init(stdout_handle);
    var stdout = &stdout_file_stream.stream;

    // NOTE: Do we want to use another allocator for arguments? Does it matter? Idk.
    const args = try os.argsAlloc(allocator);
    defer os.argsFree(allocator, args);

    if (args.len != 2) {
        // TODO: Helpful err
        return error.WrongArgs;
    }

    const nds_path = args[1];
    var rom_file = try os.File.openRead(args[1]);
    defer rom_file.close();
    var rom = try nds.Rom.fromFile(rom_file, allocator);
    defer rom.deinit();

    // TODO: No hardcoding in here!
    const out_folder = "rom";

    const arm9_overlay_folder = try path.join(allocator, out_folder, "arm9_overlays");
    defer allocator.free(arm9_overlay_folder);
    const arm7_overlay_folder = try path.join(allocator, out_folder, "arm7_overlays");
    defer allocator.free(arm7_overlay_folder);
    const root_folder = try path.join(allocator, out_folder, "root");
    defer allocator.free(root_folder);

    try os.makePath(allocator, arm9_overlay_folder);
    try os.makePath(allocator, arm7_overlay_folder);
    try os.makePath(allocator, root_folder);

    try writeToFileInFolder(out_folder, "arm9", rom.arm9, allocator);
    try writeToFileInFolder(out_folder, "arm7", rom.arm7, allocator);
    try writeToFileInFolder(out_folder, "banner", utils.toBytes(nds.Banner, rom.banner), allocator);

    if (rom.hasNitroFooter())
        try writeToFileInFolder(out_folder, "nitro_footer", utils.toBytes(@typeOf(rom.nitro_footer), rom.nitro_footer), allocator);

    try writeOverlays(arm9_overlay_folder, rom.arm9_overlay_table, rom.arm9_overlay_files, allocator);
    try writeOverlays(arm7_overlay_folder, rom.arm7_overlay_table, rom.arm7_overlay_files, allocator);

    try writeFs(nds.fs.Nitro, root_folder, rom.root, allocator);
}

fn writeFs(comptime Fs: type, p: []const u8, folder: *Fs, allocator: *mem.Allocator) !void {
    const State = struct {
        path: []const u8,
        folder: *Fs,
    };

    var stack = std.ArrayList(State).init(allocator);
    defer stack.deinit();

    try stack.append(State{
        .path = try mem.dupe(allocator, u8, p),
        .folder = folder,
    });

    while (stack.popOrNull()) |state| {
        defer allocator.free(state.path);

        for (state.folder.nodes.toSliceConst()) |node| {
            const node_path = try path.join(allocator, state.path, node.name);
            switch (node.kind) {
                Fs.Node.Kind.File => |f| {
                    defer allocator.free(node_path);
                    const Tag = @TagType(nds.fs.Nitro.File);
                    switch (Fs) {
                        nds.fs.Nitro => switch (f.*) {
                            Tag.Binary => |bin| {
                                var file = try os.File.openWrite(node_path);
                                defer file.close();
                                try file.write(bin.data);
                            },
                            Tag.Narc => |narc| {
                                try os.makePath(allocator, node_path);
                                try writeFs(nds.fs.Narc, node_path, narc, allocator);
                            }
                        },
                        nds.fs.Narc => {
                            var file = try os.File.openWrite(node_path);
                            defer file.close();
                            try file.write(f.data);
                        },
                        else => comptime unreachable,
                    }
                },
                Fs.Node.Kind.Folder => |f| {
                    try os.makePath(allocator, node_path);
                    try stack.append(State{
                        .path = node_path,
                        .folder = f,
                    });
                },
            }
        }
    }
}

fn writeOverlays(folder: []const u8, overlays: []const nds.Overlay, files: []const []const u8, allocator: *mem.Allocator) !void {
    const overlay_folder_path = try path.join(allocator, folder, "overlay");
    defer allocator.free(overlay_folder_path);

    for (overlays) |overlay, i| {
        const overlay_path = try fmt.allocPrint(allocator, "{}{}", overlay_folder_path, i);
        defer allocator.free(overlay_path);

        try writeToFile(overlay_path, utils.toBytes(nds.Overlay, overlay), allocator);
    }

    const file_folder_path = try path.join(allocator, folder, "file");
    defer allocator.free(file_folder_path);

    for (files) |file, i| {
        const file_path = try fmt.allocPrint(allocator, "{}{}", file_folder_path, i);
        defer allocator.free(file_path);

        try writeToFile(file_path, file, allocator);
    }
}

fn writeToFileInFolder(folder_path: []const u8, file: []const u8, data: []const u8, allocator: *mem.Allocator) !void {
    const joined_path = try path.join(allocator, folder_path, file);
    defer allocator.free(joined_path);

    try writeToFile(joined_path, data, allocator);
}

fn writeToFile(file_path: []const u8, data: []const u8, allocator: *mem.Allocator) !void {
    var file = try os.File.openWrite(file_path);
    defer file.close();

    try file.write(data);
}
