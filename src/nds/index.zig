const std     = @import("std");
const blz     = @import("blz");
const common  = @import("common.zig");
const overlay = @import("overlay.zig");
const little  = @import("../little.zig");
const utils   = @import("../utils/index.zig");

const debug = std.debug;
const mem   = std.mem;
const io    = std.io;
const os    = std.os;

const assert = debug.assert;

const toLittle = little.toLittle;
const Little   = little.Little;

pub const fs = @import("fs.zig");

pub const Header  = @import("header.zig").Header;
pub const Banner  = @import("banner.zig").Banner;
pub const Overlay = overlay.Overlay;

pub const Rom = struct {
    // TODO: Do we actually want to store the header?
    //       Info like offsets, the user of the lib shouldn't touch, but other info, are allowed.
    //       Instead of storing the header. Only store info relevant for customization, and let
    //       the writeToFile function generate the offsets
    //       Or maybe the user of the lib should be able to set the offsets manually. Maybe they want
    //       to have the rom change as little as possible so they can share small patches.
    header: Header,
    arm9: []u8,

    // After arm9, there is 12 bytes that might be a nitro footer. If the first
    // 4 bytes are == 0xDEC00621, then it's a nitro_footer.
    // NOTE: This information was deduced from reading the source code for
    //       ndstool and EveryFileExplore. http://problemkaputt.de/gbatek.htm does
    //       not seem to have this information anywhere.
    nitro_footer: [3]Little(u32),

    arm7: []u8,

    arm9_overlay_table: []Overlay,
    arm9_overlay_files: [][]u8,

    arm7_overlay_table: []Overlay,
    arm7_overlay_files: [][]u8,

    banner: Banner,
    file_system: &fs.Nitro,

    allocator: &mem.Allocator,

    pub fn fromFile(file: &os.File, allocator: &mem.Allocator) !Rom {
        const header = try utils.file.read(file, Header);
        try header.validate();

        const arm9 = blk: {
            const raw = try utils.file.seekToAllocRead(file, header.arm9_rom_offset.get(), allocator, u8, header.arm9_size.get());
            defer allocator.free(raw);

            // If blz.decode failes, we assume that the arm9 is not encoded and just use the raw data
            break :blk blz.decode(raw, allocator) catch raw;
        };
        errdefer allocator.free(arm9);
        const nitro_footer = try utils.file.read(file, [3]Little(u32));

        const arm7 = try utils.file.seekToAllocRead(file, header.arm7_rom_offset.get(), allocator, u8, header.arm7_size.get());
        errdefer allocator.free(arm7);

        // TODO: On dsi, this can be of different sizes
        const banner = try utils.file.seekToRead(file, header.banner_offset.get(), Banner);
        try banner.validate();
        if (header.fat_size.get() % @sizeOf(fs.FatEntry) != 0) return error.InvalidFatSize;

        const fnt = try utils.file.seekToAllocRead(file, header.fnt_offset.get(), allocator, u8, header.fnt_size.get());
        const fat = try utils.file.seekToAllocRead(file, header.fat_offset.get(), allocator, fs.FatEntry, header.fat_size.get() / @sizeOf(fs.FatEntry));

        const file_system = try fs.readNitro(file, allocator, fnt, fat);
        errdefer file_system.deinit();

        const arm9_overlay_table = try utils.file.seekToAllocRead(
            file,
            header.arm9_overlay_offset.get(),
            allocator,
            Overlay,
            header.arm9_overlay_size.get() / @sizeOf(Overlay));
        errdefer allocator.free(arm9_overlay_table);
        const arm9_overlay_files = try overlay.readFiles(file, allocator, arm9_overlay_table, fat);
        errdefer overlay.freeFiles(arm9_overlay_files, allocator);

        const arm7_overlay_table = try utils.file.seekToAllocRead(
            file,
            header.arm7_overlay_offset.get(),
            allocator,
            Overlay,
            header.arm7_overlay_size.get() / @sizeOf(Overlay));
        errdefer allocator.free(arm7_overlay_table);
        const arm7_overlay_files = try overlay.readFiles(file, allocator, arm7_overlay_table, fat);
        errdefer overlay.freeFiles(arm7_overlay_files, allocator);

        return Rom {
            .header = header,
            .arm9 = arm9,
            .nitro_footer = nitro_footer,
            .arm7 = arm7,
            .arm9_overlay_table = arm9_overlay_table,
            .arm9_overlay_files = arm9_overlay_files,
            .arm7_overlay_table = arm7_overlay_table,
            .arm7_overlay_files = arm7_overlay_files,
            .banner = banner,
            .file_system = file_system,
            .allocator = allocator,
        };
    }

    pub fn writeToFile(rom: &Rom, file: &os.File, allocator: &mem.Allocator) !void {
        const header = &rom.header;

        const arm9_pos = 0x4000;
        try file.seekTo(arm9_pos);

        // TODO: There might be times when people want/need to encode the arm9 again when saving,
        //       so we should probably give them the option to do so.
        //       Maybe encoding and decoding, is something that should be done outside the loading/saving
        //       of roms. Hmmm :thinking:
        try file.write(rom.arm9);
        if (rom.hasNitroFooter()) {
            try file.write(([]u8)(rom.nitro_footer[0..]));
        }

        header.arm9_rom_offset = toLittle(u32(arm9_pos));
        header.arm9_size       = toLittle(u32(rom.arm9.len));

        const arm7_pos = try file.getPos();
        try file.write(rom.arm7);

        header.arm7_rom_offset = toLittle(u32(arm7_pos));
        header.arm7_size       = toLittle(u32(rom.arm7.len));

        const banner_pos = try file.getPos();
        try file.write(utils.toBytes(Banner, rom.banner));

        header.banner_offset  = toLittle(u32(banner_pos));
        header.banner_size    = toLittle(u32(@sizeOf(Banner)));

        const fntAndFiles = try fs.getFntAndFiles(fs.Nitro.File, rom.file_system, allocator);
        const files = fntAndFiles.files;
        const main_fnt = fntAndFiles.main_fnt;
        const sub_fnt = fntAndFiles.sub_fnt;
        defer {
            allocator.free(files);
            allocator.free(main_fnt);
            allocator.free(sub_fnt);
        }

        const fnt_pos = try file.getPos();
        try file.write(([]u8)(main_fnt));
        try file.write(sub_fnt);

        header.fnt_offset = toLittle(u32(fnt_pos));
        header.fnt_size   = toLittle(u32(main_fnt.len * @sizeOf(fs.FntMainEntry) + sub_fnt.len));

        var fat = std.ArrayList(fs.FatEntry).init(allocator);
        try fat.ensureCapacity(files.len + rom.arm9_overlay_files.len + rom.arm7_overlay_files.len);

        for (files) |f| {
            const pos = u32(try file.getPos());
            try fs.writeNitroFile(file, allocator, f);
            fat.append(fs.FatEntry.init(pos, u32(try file.getPos()) - pos)) catch unreachable;
        }

        for (rom.arm9_overlay_files) |f, i| {
            const pos = u32(try file.getPos());
            try file.write(f);
            fat.append(fs.FatEntry.init(pos, u32(try file.getPos()) - pos)) catch unreachable;

            const table_entry = &rom.arm9_overlay_table[i];
            table_entry.overlay_id = toLittle(u32(i));
            table_entry.file_id = toLittle(u32(files.len + i));
        }

        for (rom.arm7_overlay_files) |f, i| {
            const pos = u32(try file.getPos());
            try file.write(f);
            fat.append(fs.FatEntry.init(pos, u32(try file.getPos()) - pos)) catch unreachable;

            const table_entry = &rom.arm7_overlay_table[i];
            table_entry.overlay_id = toLittle(u32(i));
            table_entry.file_id = toLittle(u32(rom.arm9_overlay_files.len + files.len + i));
        }

        const fat_pos = try file.getPos();
        try file.write(([]const u8)(fat.toSliceConst()));

        header.fat_offset = toLittle(u32(fat_pos));
        header.fat_size   = toLittle(u32((files.len + rom.arm9_overlay_table.len + rom.arm7_overlay_table.len) * @sizeOf(fs.FatEntry)));

        const arm9_overlay_pos = try file.getPos();
        try file.write(([]const u8)(rom.arm9_overlay_table));

        header.arm9_overlay_offset = toLittle(u32(arm9_overlay_pos));
        header.arm9_overlay_size   = toLittle(u32(rom.arm9_overlay_table.len * @sizeOf(Overlay)));

        const arm7_overlay_pos = try file.getPos();
        try file.write(([]const u8)(rom.arm7_overlay_table));

        header.arm7_overlay_offset = toLittle(u32(arm7_overlay_pos));
        header.arm7_overlay_size   = toLittle(u32(rom.arm7_overlay_table.len * @sizeOf(Overlay)));

        header.total_used_rom_size = toLittle(common.@"align"(u32(try file.getPos()), u32(4)));
        header.device_capacity = blk: {
            // Devicecapacity (Chipsize = 128KB SHL nn) (eg. 7 = 16MB)
            const size = header.total_used_rom_size.get();
            var device_cap : u6 = 0;
            while (@shlExact(u64(128000), device_cap) < size) : (device_cap += 1) { }

            break :blk device_cap;
        };
        header.header_checksum = toLittle(header.calcChecksum());

        try header.validate();
        try file.seekTo(0x00);
        try file.write(utils.toBytes(Header, header));
    }

    pub fn hasNitroFooter(rom: &const Rom) bool {
        return rom.nitro_footer[0].get() == 0xDEC00621;
    }

    pub fn deinit(rom: &Rom) void {
        rom.allocator.free(rom.arm9);
        rom.allocator.free(rom.arm7);
        rom.allocator.free(rom.arm9_overlay_table);
        rom.allocator.free(rom.arm7_overlay_table);
        overlay.freeFiles(rom.arm9_overlay_files, rom.allocator);
        overlay.freeFiles(rom.arm7_overlay_files, rom.allocator);
        rom.file_system.deinit();
    }
};
