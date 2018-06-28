const std = @import("std");
// TODO: We can't have packages in tests
const blz = @import("../../lib/blz/blz.zig");
const common = @import("common.zig");
const overlay = @import("overlay.zig");
const int = @import("../int.zig");
const utils = @import("../utils/index.zig");

const debug = std.debug;
const mem = std.mem;
const io = std.io;
const os = std.os;

const assert = debug.assert;

const lu16 = int.lu16;
const lu32 = int.lu32;

pub const fs = @import("fs.zig");

pub const Header = @import("header.zig").Header;
pub const Banner = @import("banner.zig").Banner;
pub const Overlay = overlay.Overlay;

test "nds" {
    _ = @import("banner.zig");
    _ = @import("common.zig");
    _ = @import("formats.zig");
    _ = @import("fs.zig");
    //_ = @import("header.zig");
    _ = @import("overlay.zig");
}

pub const Rom = struct {
    allocator: *mem.Allocator,

    // TODO: Do we actually want to store the header?
    //       Info like offsets, the user of the lib shouldn't touch, but other info, are allowed.
    //       Instead of storing the header. Only store info relevant for customization, and let
    //       the writeToFile function generate the offsets
    //       Or maybe the user of the lib should be able to set the offsets manually. Maybe they want
    //       to have the rom change as little as possible so they can share small patches.
    header: Header,
    banner: Banner,

    arm9: []u8,
    arm7: []u8,

    // After arm9, there is 12 bytes that might be a nitro footer. If the first
    // 4 bytes are == 0xDEC00621, then it's a nitro_footer.
    // NOTE: This information was deduced from reading the source code for
    //       ndstool and EveryFileExplore. http://problemkaputt.de/gbatek.htm does
    //       not seem to have this information anywhere.
    nitro_footer: [3]lu32,

    arm9_overlay_table: []Overlay,
    arm9_overlay_files: [][]u8,

    arm7_overlay_table: []Overlay,
    arm7_overlay_files: [][]u8,

    file_system: *fs.Nitro,

    pub fn fromFile(file: *os.File, allocator: *mem.Allocator) !Rom {
        var file_stream = io.FileInStream.init(file);
        var stream = &file_stream.stream;

        const header = try utils.stream.read(stream, Header);
        try header.validate();

        const arm9 = blk: {
            try file.seekTo(header.arm9_rom_offset.value());
            const raw = try utils.stream.allocRead(stream, allocator, u8, header.arm9_size.value());
            defer allocator.free(raw);

            // If blz.decode failes, we assume that the arm9 is not encoded and just use the raw data
            break :blk blz.decode(raw, allocator) catch raw;
        };
        errdefer allocator.free(arm9);
        const nitro_footer = try utils.stream.read(stream, [3]lu32);

        try file.seekTo(header.arm7_rom_offset.value());
        const arm7 = try utils.stream.allocRead(stream, allocator, u8, header.arm7_size.value());
        errdefer allocator.free(arm7);

        // TODO: On dsi, this can be of different sizes
        try file.seekTo(header.banner_offset.value());
        const banner = try utils.stream.read(stream, Banner);
        try banner.validate();
        if (header.fat_size.value() % @sizeOf(fs.FatEntry) != 0) return error.InvalidFatSize;

        try file.seekTo(header.fnt_offset.value());
        const fnt = try utils.stream.allocRead(stream, allocator, u8, header.fnt_size.value());

        try file.seekTo(header.fat_offset.value());
        const fat = try utils.stream.allocRead(stream, allocator, fs.FatEntry, header.fat_size.value() / @sizeOf(fs.FatEntry));

        const file_system = try fs.readNitro(file, allocator, fnt, fat);
        errdefer file_system.deinit();

        try file.seekTo(header.arm9_overlay_offset.value());
        const arm9_overlay_table = try utils.stream.allocRead(
            stream,
            allocator,
            Overlay,
            header.arm9_overlay_size.value() / @sizeOf(Overlay),
        );
        errdefer allocator.free(arm9_overlay_table);
        const arm9_overlay_files = try overlay.readFiles(file, allocator, arm9_overlay_table, fat);
        errdefer overlay.freeFiles(arm9_overlay_files, allocator);

        try file.seekTo(header.arm7_overlay_offset.value());
        const arm7_overlay_table = try utils.stream.allocRead(
            stream,
            allocator,
            Overlay,
            header.arm7_overlay_size.value() / @sizeOf(Overlay),
        );
        errdefer allocator.free(arm7_overlay_table);
        const arm7_overlay_files = try overlay.readFiles(file, allocator, arm7_overlay_table, fat);
        errdefer overlay.freeFiles(arm7_overlay_files, allocator);

        return Rom{
            .allocator = allocator,
            .header = header,
            .banner = banner,
            .arm9 = arm9,
            .arm7 = arm7,
            .nitro_footer = nitro_footer,
            .arm9_overlay_table = arm9_overlay_table,
            .arm9_overlay_files = arm9_overlay_files,
            .arm7_overlay_table = arm7_overlay_table,
            .arm7_overlay_files = arm7_overlay_files,
            .file_system = file_system,
        };
    }

    pub fn writeToFile(rom: Rom, file: *os.File, allocator: *mem.Allocator) !void {
        var header = rom.header;

        const arm9_pos = 0x4000;
        try file.seekTo(arm9_pos);

        // TODO: There might be times when people want/need to encode the arm9 again when saving,
        //       so we should probably give them the option to do so.
        //       Maybe encoding and decoding, is something that should be done outside the loading/saving
        //       of roms. Hmmm :thinking:
        try file.write(rom.arm9);
        if (rom.hasNitroFooter()) {
            try file.write(@sliceToBytes(rom.nitro_footer[0..]));
        }

        header.arm9_rom_offset = lu32.init(@intCast(u32, arm9_pos));
        header.arm9_size = lu32.init(@intCast(u32, rom.arm9.len));

        const arm7_pos = try file.getPos();
        try file.write(rom.arm7);

        header.arm7_rom_offset = lu32.init(@intCast(u32, arm7_pos));
        header.arm7_size = lu32.init(@intCast(u32, rom.arm7.len));

        const banner_pos = try file.getPos();
        try file.write(utils.toBytes(Banner, rom.banner));

        header.banner_offset = lu32.init(@intCast(u32, banner_pos));
        header.banner_size = lu32.init(@sizeOf(Banner));

        const fntAndFiles = try fs.getFntAndFiles(fs.Nitro, rom.file_system.*, allocator);
        const files = fntAndFiles.files;
        const main_fnt = fntAndFiles.main_fnt;
        const sub_fnt = fntAndFiles.sub_fnt;
        defer {
            allocator.free(files);
            allocator.free(main_fnt);
            allocator.free(sub_fnt);
        }

        const fnt_pos = try file.getPos();
        try file.write(@sliceToBytes(main_fnt));
        try file.write(sub_fnt);

        header.fnt_offset = lu32.init(@intCast(u32, fnt_pos));
        header.fnt_size = lu32.init(@intCast(u32, main_fnt.len * @sizeOf(fs.FntMainEntry) + sub_fnt.len));

        var fat = std.ArrayList(fs.FatEntry).init(allocator);
        try fat.ensureCapacity(files.len + rom.arm9_overlay_files.len + rom.arm7_overlay_files.len);

        for (files) |f| {
            const pos = @intCast(u32, try file.getPos());
            try fs.writeNitroFile(file, allocator, f.*);
            fat.append(fs.FatEntry.init(pos, @intCast(u32, try file.getPos()) - pos)) catch unreachable;
        }

        for (rom.arm9_overlay_files) |f, i| {
            const pos = @intCast(u32, try file.getPos());
            try file.write(f);
            fat.append(fs.FatEntry.init(pos, @intCast(u32, try file.getPos()) - pos)) catch unreachable;

            const table_entry = &rom.arm9_overlay_table[i];
            table_entry.overlay_id = lu32.init(@intCast(u32, i));
            table_entry.file_id = lu32.init(@intCast(u32, files.len + i));
        }

        for (rom.arm7_overlay_files) |f, i| {
            const pos = @intCast(u32, try file.getPos());
            try file.write(f);
            fat.append(fs.FatEntry.init(pos, @intCast(u32, try file.getPos()) - pos)) catch unreachable;

            const table_entry = &rom.arm7_overlay_table[i];
            table_entry.overlay_id = lu32.init(@intCast(u32, i));
            table_entry.file_id = lu32.init(@intCast(u32, rom.arm9_overlay_files.len + files.len + i));
        }

        const fat_pos = try file.getPos();
        try file.write(@sliceToBytes(fat.toSliceConst()));

        header.fat_offset = lu32.init(@intCast(u32, fat_pos));
        header.fat_size = lu32.init(@intCast(u32, (files.len + rom.arm9_overlay_table.len + rom.arm7_overlay_table.len) * @sizeOf(fs.FatEntry)));

        const arm9_overlay_pos = try file.getPos();
        try file.write(@sliceToBytes(rom.arm9_overlay_table));

        header.arm9_overlay_offset = lu32.init(@intCast(u32, arm9_overlay_pos));
        header.arm9_overlay_size = lu32.init(@intCast(u32, rom.arm9_overlay_table.len * @sizeOf(Overlay)));

        const arm7_overlay_pos = try file.getPos();
        try file.write(@sliceToBytes(rom.arm7_overlay_table));

        header.arm7_overlay_offset = lu32.init(@intCast(u32, arm7_overlay_pos));
        header.arm7_overlay_size = lu32.init(@intCast(u32, rom.arm7_overlay_table.len * @sizeOf(Overlay)));

        header.total_used_rom_size = lu32.init(common.@"align"(@intCast(u32, try file.getPos()), u32(4)));
        header.device_capacity = blk: {
            // Devicecapacity (Chipsize = 128KB SHL nn) (eg. 7 = 16MB)
            const size = header.total_used_rom_size.value();
            var device_cap: u6 = 0;
            while (@shlExact(u64(128000), device_cap) < size) : (device_cap += 1) {}

            break :blk device_cap;
        };
        header.header_checksum = lu16.init(header.calcChecksum());

        try header.validate();
        try file.seekTo(0x00);
        try file.write(utils.toBytes(Header, header));
    }

    pub fn hasNitroFooter(rom: Rom) bool {
        return rom.nitro_footer[0].value() == 0xDEC00621;
    }

    pub fn deinit(rom: *Rom) void {
        rom.allocator.free(rom.arm9);
        rom.allocator.free(rom.arm7);
        rom.allocator.free(rom.arm9_overlay_table);
        rom.allocator.free(rom.arm7_overlay_table);
        overlay.freeFiles(rom.arm9_overlay_files, rom.allocator);
        overlay.freeFiles(rom.arm7_overlay_files, rom.allocator);
        rom.file_system.deinit();
    }
};
