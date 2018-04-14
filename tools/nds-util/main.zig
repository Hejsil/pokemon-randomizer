const std   = @import("std");
const utils = @import("utils");
// TODO: When https://github.com/zig-lang/zig/issues/855 is fixed. Make this into a package import instead of this HACK
const nds   = @import("../../src/nds/index.zig");

const heap  = std.heap;
const os    = std.os;
const io    = std.io;
const fmt   = std.fmt;
const debug = std.debug;
const path  = os.path;

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
    var stdout_file_stream = io.FileOutStream.init(&stdout_handle);
    var stdout = &stdout_file_stream.stream;

    // NOTE: Do we want to use another allocator for arguments? Does it matter? Idk.
    const args = try os.argsAlloc(allocator);
    defer os.argsFree(allocator, args);

    if (args.len != 2) {
        // TODO: Helpful err
        return error.WrongArgs;
    }

    const nds_path = args[1];
    var rom_file = try os.File.openRead(allocator, args[1]);
    defer rom_file.close();
    var rom = try nds.Rom.fromFile(&rom_file, allocator);
    defer rom.deinit();

    // TODO: No hardcoding in here!
    const out_folder = "rom";

    const arm9_overlay_folder = try path.join(allocator, out_folder, "arm9_overlays"); defer allocator.free(arm9_overlay_folder);
    const arm7_overlay_folder = try path.join(allocator, out_folder, "arm7_overlays"); defer allocator.free(arm7_overlay_folder);
    const root_folder         = try path.join(allocator, out_folder, "root");          defer allocator.free(root_folder);

    var path_buffer : [1024 * 6]u8 = undefined;
    var path_allocator = heap.FixedBufferAllocator.init(path_buffer[0..]);
    try os.makePath(&path_allocator.allocator, arm9_overlay_folder);
    try os.makePath(&path_allocator.allocator, arm7_overlay_folder);
    try os.makePath(&path_allocator.allocator, root_folder);

    try writeToFileInFolder(out_folder, "arm9", rom.arm9);
    try writeToFileInFolder(out_folder, "arm7", rom.arm7);
    try writeToFileInFolder(out_folder, "banner", utils.toBytes(nds.Banner, rom.banner));

    if (rom.hasNitroFooter())
        try writeToFileInFolder(out_folder, "nitro_footer", utils.toBytes(@typeOf(rom.nitro_footer), rom.nitro_footer));

    try writeOverlays(arm9_overlay_folder, rom.arm9_overlay_table, rom.arm9_overlay_files);
    try writeOverlays(arm7_overlay_folder, rom.arm7_overlay_table, rom.arm7_overlay_files);

    try writeFs(root_folder, rom.tree);
}

fn writeFs(folder: []const u8, fs: &const nds.fs.Tree(nds.fs.NitroFile)) error!void {
    for (fs.root.files.toSliceConst()) |f| {
        var buffer : [1024 * 4]u8 = undefined;
        var fixed_allocator = heap.FixedBufferAllocator.init(buffer[0..]);
        var file = try os.File.openWrite(&fixed_allocator.allocator, try path.join(&fixed_allocator.allocator, folder, f.name));
        defer file.close();
        _ = try nds.fs.writeFile(nds.fs.NitroFile, &file, &fixed_allocator.allocator, f);
    }

    for (fs.root.folders.toSliceConst()) |f| {
        var buffer : [1024 * 4]u8 = undefined;
        var fixed_allocator = heap.FixedBufferAllocator.init(buffer[0..]);
        const sub_folder = try path.join(&fixed_allocator.allocator, folder, f.name);
        try os.makePath(&fixed_allocator.allocator, sub_folder);
        try writeFs(sub_folder, nds.fs.Tree(nds.fs.NitroFile) {
            .arena = fs.arena,
            .root = f,
        });
    }
}

fn writeOverlays(folder: []const u8, overlays: []const nds.Overlay, files: []const []const u8) !void {
    {
        var path_buffer : [1024 * 6]u8 = undefined;
        var path_allocator = heap.FixedBufferAllocator.init(path_buffer[0..]);
        const overlay_path  = try path.join(&path_allocator.allocator, folder, "overlay");

        for (overlays) |overlay, i| {
            var buffer : [1024 * 2]u8 = undefined;
            var fixed_allocator = heap.FixedBufferAllocator.init(buffer[0..]);
            try writeToFile(try fmt.allocPrint(&fixed_allocator.allocator, "{}{}", overlay_path, i), utils.toBytes(nds.Overlay, overlay));
        }
    }

    {
        var path_buffer : [1024 * 6]u8 = undefined;
        var path_allocator = heap.FixedBufferAllocator.init(path_buffer[0..]);
        const file_path    = try path.join(&path_allocator.allocator, folder, "file");

        for (files) |file, i| {
            var buffer : [1024 * 2]u8 = undefined;
            var fixed_allocator = heap.FixedBufferAllocator.init(buffer[0..]);
            try writeToFile(try fmt.allocPrint(&fixed_allocator.allocator, "{}{}", file_path, i), file);
        }
    }
}

fn writeToFileInFolder(folder_path: []const u8, file: []const u8, data: []const u8) !void {
    var buffer : [1024 * 2]u8 = undefined;
    var fixed_allocator = heap.FixedBufferAllocator.init(buffer[0..]);
    try writeToFile(try path.join(&fixed_allocator.allocator, folder_path, file), data);
}

fn writeToFile(file_path: []const u8, data: []const u8) !void {
    var buffer : [1024 * 2]u8 = undefined;
    var fixed_allocator = heap.FixedBufferAllocator.init(buffer[0..]);
    var file = try os.File.openWrite(&fixed_allocator.allocator, file_path);
    defer file.close();
    try file.write(data);
}
