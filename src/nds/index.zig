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
    root: fs.Folder,

    pub fn fromFile(file: &os.File, allocator: &mem.Allocator) !Rom {
        const header = try utils.file.read(file, Header);
        try header.validate();

        const arm9 = blk: {
            const raw = try utils.file.seekToAllocRead(file, header.arm9_rom_offset.get(), allocator, u8, header.arm9_size.get());
            // defer allocator.free(raw); TODO: error: unreachable code

            break :blk raw; // try blz.decode(raw, allocator);
        };
        errdefer allocator.free(arm9);
        const nitro_footer = try utils.file.read(file, [3]Little(u32));

        const arm7 = try utils.file.seekToAllocRead(file, header.arm7_rom_offset.get(), allocator, u8, header.arm7_size.get());
        errdefer allocator.free(arm7);

        const arm9_overlay_table = try utils.file.seekToAllocRead(
            file,
            header.arm9_overlay_offset.get(),
            allocator,
            Overlay,
            header.arm9_overlay_size.get() / @sizeOf(Overlay));
        errdefer allocator.free(arm9_overlay_table);
        const arm9_overlay_files = try overlay.readFiles(file, allocator, arm9_overlay_table, header.fat_offset.get());
        errdefer overlay.freeFiles(arm9_overlay_files, allocator);

        const arm7_overlay_table = try utils.file.seekToAllocRead(
            file,
            header.arm7_overlay_offset.get(),
            allocator,
            Overlay,
            header.arm7_overlay_size.get() / @sizeOf(Overlay));
        errdefer allocator.free(arm7_overlay_table);
        const arm7_overlay_files = try overlay.readFiles(file, allocator, arm7_overlay_table, header.fat_offset.get());
        errdefer overlay.freeFiles(arm7_overlay_files, allocator);

        // TODO: On dsi, this can be of different sizes
        const banner = try utils.file.seekToRead(file, header.banner_offset.get(), Banner);
        try banner.validate();
        if (header.fat_size.get() % @sizeOf(fs.FatEntry) != 0) return error.InvalidFatSize;

        const root = try fs.read(
            file,
            allocator,
            header.fnt_offset.get(),
            header.fat_offset.get(),
            header.fat_size.get() / @sizeOf(fs.FatEntry),
            0);
        errdefer root.destroy(allocator);

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
            .root = root,
        };
    }

    pub fn writeToFile(rom: &Rom, file: &os.File, allocator: &mem.Allocator) !void {
        try rom.banner.validate();

        const header = &rom.header;
        const fs_info = rom.root.sizes();

        if (@maxValue(u16) < fs_info.folders * @sizeOf(fs.FntMainEntry)) return error.InvalidSizeInHeader;
        if (@maxValue(u16) < fs_info.files   * @sizeOf(fs.FatEntry))     return error.InvalidSizeInHeader;

        header.arm9_rom_offset     = toLittle(u32(0x4000));
        header.arm9_size           = toLittle(u32(rom.arm9.len));
        header.arm9_overlay_offset = little.add(u32, header.arm9_rom_offset, header.arm9_size);
        header.arm9_overlay_size   = toLittle(u32(rom.arm9_overlay_table.len * @sizeOf(Overlay)));
        if (rom.hasNitroFooter()) {
            header.arm9_overlay_offset = toLittle(header.arm9_overlay_offset.get() + @sizeOf(@typeOf(rom.nitro_footer)));
        }

        header.arm7_rom_offset     = toLittle(common.@"align"(header.arm9_overlay_offset.get() + header.arm9_overlay_size.get(), u32(0x200)));
        header.arm7_size           = toLittle(u32(rom.arm7.len));
        header.arm7_overlay_offset = toLittle(header.arm7_rom_offset.get() + header.arm7_size.get());
        header.arm7_overlay_size   = toLittle(u32(rom.arm7_overlay_table.len * @sizeOf(Overlay)));
        header.banner_offset       = toLittle(common.@"align"(header.arm7_overlay_offset.get() + header.arm7_overlay_size.get(), u32(0x200)));
        header.banner_size         = toLittle(u32(@sizeOf(Banner)));
        header.fnt_offset          = toLittle(common.@"align"(header.banner_offset.get() + header.banner_size.get(), u32(0x200)));
        header.fnt_size            = toLittle(u32(fs_info.folders * @sizeOf(fs.FntMainEntry) + fs_info.fnt_sub_size));
        header.fat_offset          = toLittle(common.@"align"(header.fnt_offset.get() + header.fnt_size.get(), u32(0x200)));
        header.fat_size            = toLittle(u32((fs_info.files + rom.arm9_overlay_table.len + rom.arm7_overlay_table.len) * @sizeOf(fs.FatEntry)));

        const file_offset = header.fat_offset.get() + header.fat_size.get();
        var overlay_writer = overlay.Writer.init(file, file_offset, 0);
        try overlay_writer.writeOverlayFiles(rom.arm9_overlay_table, rom.arm9_overlay_files, header.fat_offset.get());
        try overlay_writer.writeOverlayFiles(rom.arm7_overlay_table, rom.arm7_overlay_files, header.fat_offset.get());

        var fs_writer = fs.FSWriter.init(file, overlay_writer.file_offset, overlay_writer.file_id);
        try fs_writer.writeFileSystem(rom.root, header.fnt_offset.get(), header.fat_offset.get(), 0, fs_info.folders);

        header.total_used_rom_size = toLittle( common.@"align"(fs_writer.file_offset, u32(4)));
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
        try file.seekTo(header.arm9_rom_offset.get());
        try file.write(blk: {
            const encoded = rom.arm9; // try blz.encode(rom.arm9, blz.Mode.Normal, allocator);
            // defer allocator.free(encoded);

            break :blk encoded;
        });
        if (rom.hasNitroFooter()) {
            try file.write(([]u8)(rom.nitro_footer[0..]));
        }

        try file.seekTo(header.arm9_overlay_offset.get());
        try file.write(([]u8)(rom.arm9_overlay_table));
        try file.seekTo(header.arm7_rom_offset.get());
        try file.write(rom.arm7);
        try file.seekTo(header.arm7_overlay_offset.get());
        try file.write(([]u8)(rom.arm7_overlay_table));
        try file.seekTo(header.banner_offset.get());
        try file.write(utils.toBytes(Banner, rom.banner));
    }

    pub fn hasNitroFooter(rom: &const Rom) bool {
        return rom.nitro_footer[0].get() == 0xDEC00621;
    }

    pub fn destroy(rom: &const Rom, allocator: &mem.Allocator) void {
        allocator.free(rom.arm9);
        allocator.free(rom.arm7);
        allocator.free(rom.arm9_overlay_table);
        allocator.free(rom.arm7_overlay_table);
        overlay.freeFiles(rom.arm9_overlay_files, allocator);
        overlay.freeFiles(rom.arm7_overlay_files, allocator);
        rom.root.destroy(allocator);
    }
};
