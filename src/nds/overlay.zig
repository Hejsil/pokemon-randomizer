const std = @import("std");
const fs = @import("fs.zig");
const common = @import("common.zig");
const int = @import("../int.zig");
const utils = @import("../utils/index.zig");

const io = std.io;
const mem = std.mem;
const os = std.os;

const lu32 = int.lu32;

pub const Overlay = packed struct {
    overlay_id: lu32,
    ram_address: lu32,
    ram_size: lu32,
    bss_size: lu32,
    static_initialiser_start_address: lu32,
    static_initialiser_end_address: lu32,
    file_id: lu32,
    reserved: [4]u8,
};

pub fn readFiles(file: os.File, allocator: *mem.Allocator, overlay_table: []Overlay, fat: []fs.FatEntry) ![][]u8 {
    var results = std.ArrayList([]u8).init(allocator);
    try results.ensureCapacity(overlay_table.len);
    errdefer {
        freeFiles(results.toSlice(), allocator);
        results.deinit();
    }

    var file_stream = io.FileInStream.init(file);
    var stream = &file_stream.stream;

    for (overlay_table) |overlay, i| {
        const id = overlay.file_id.value() & 0x0FFF;

        const start = fat[id].start.value();
        const size = fat[id].getSize();

        try file.seekTo(start);
        const overay_file = try utils.stream.allocRead(stream, allocator, u8, size);
        try results.append(overay_file);
    }

    return results.toOwnedSlice();
}

pub fn freeFiles(files: [][]u8, allocator: *mem.Allocator) void {
    for (files) |file|
        allocator.free(file);
    allocator.free(files);
}
