const std    = @import("std");
const fs     = @import("fs.zig");
const utils  = @import("../utils.zig");
const little = @import("../little.zig");

const io = std.io;

const alignAddr = @import("alignment.zig").alignAddr;
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

pub const Writer = struct {
    file: &io.File,
    file_offset: u32,
    file_id: u16,

    fn init(file: &io.File, file_offset: u32, start_file_id: u16) Writer {
        return Writer {
            .file = file,
            .file_offset = file_offset,
            .file_id = start_file_id,
        };
    }

    fn writeOverlayFiles(self: &Writer, overlay_table: []Overlay, overlay_files: []const []u8, fat_offset: usize) %void {
        for (overlay_table) |*overlay_entry, i| {
            const overlay_file = overlay_files[i];
            const fat_entry = fs.FatEntry.init(alignAddr(u32, self.file_offset, 0x200), u32(overlay_file.len));
            try self.file.seekTo(fat_offset + (self.file_id * @sizeOf(fs.FatEntry)));
            try self.file.write(utils.asConstBytes(fs.FatEntry, fat_entry));

            try self.file.seekTo(fat_entry.start.get());
            try self.file.write(overlay_file);

            overlay_entry.overlay_id = toLittle(u32, u32(i));
            overlay_entry.file_id = toLittle(u32, u32(self.file_id));
            self.file_offset = u32(try self.file.getPos());
            self.file_id += 1;
        }
    }
};