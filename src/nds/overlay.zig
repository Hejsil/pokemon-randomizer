const std    = @import("std");
const fs     = @import("fs.zig");
const common = @import("common.zig");
const little = @import("../little.zig");
const utils  = @import("../utils/index.zig");

const io  = std.io;
const mem = std.mem;
const os  = std.os;

const toLittle = little.toLittle;
const Little   = little.Little;

pub const Overlay = packed struct {
    overlay_id: Little(u32),
    ram_address: Little(u32),
    ram_size: Little(u32),
    bss_size: Little(u32),
    static_initialiser_start_address: Little(u32),
    static_initialiser_end_address: Little(u32),
    file_id: Little(u32),
    reserved: [4]u8,
};

pub fn readFiles(file: &os.File, allocator: &mem.Allocator, overlay_table: []Overlay, fat: []fs.FatEntry) ![][]u8 {
    var results = std.ArrayList([]u8).init(allocator);
    try results.ensureCapacity(overlay_table.len);
    errdefer {
        freeFiles(results.toSlice(), allocator);
        results.deinit();
    }

    for (overlay_table) |overlay, i| {
        const id = overlay.file_id.get() & 0x0FFF;

        const start = fat[id].start.get();
        const size = fat[id].getSize();

        const overay_file = try utils.file.seekToAllocRead(file, start, allocator, u8, size);
        try results.append(overay_file);
    }

    return results.toOwnedSlice();
}

pub fn freeFiles(files: [][]u8, allocator: &mem.Allocator) void {
    for (files) |file| allocator.free(file);
    allocator.free(files);
}

pub const Writer = struct {
    file: &os.File,
    file_offset: u32,
    file_id: u16,

    fn init(file: &os.File, file_offset: u32, start_file_id: u16) Writer {
        return Writer {
            .file = file,
            .file_offset = file_offset,
            .file_id = start_file_id,
        };
    }

    fn writeOverlayFiles(writer: &Writer, overlay_table: []Overlay, overlay_files: []const []u8, fat_offset: usize) !void {
        for (overlay_table) |*overlay_entry, i| {
            const overlay_file = overlay_files[i];
            const fat_entry = fs.FatEntry.init(common.@"align"(writer.file_offset, u32(0x200)), u32(overlay_file.len));
            try writer.file.seekTo(fat_offset + (writer.file_id * @sizeOf(fs.FatEntry)));
            try writer.file.write(utils.toBytes(fs.FatEntry, fat_entry));

            try writer.file.seekTo(fat_entry.start.get());
            try writer.file.write(overlay_file);

            overlay_entry.overlay_id = toLittle(u32(i));
            overlay_entry.file_id = toLittle(u32(writer.file_id));
            writer.file_offset = u32(try writer.file.getPos());
            writer.file_id += 1;
        }
    }
};
