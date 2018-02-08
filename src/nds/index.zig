const std     = @import("std");
const overlay = @import("overlay.zig");
const utils   = @import("../utils.zig");
const little  = @import("../little.zig");

const debug = std.debug;
const mem   = std.mem;
const io    = std.io;

const assert = debug.assert;

const alignAddr = @import("alignment.zig").alignAddr;
const toLittle = little.toLittle;
const Little   = little.Little;

pub const fs = @import("fs.zig");

pub const Header  = @import("header.zig").Header;
pub const Banner  = @import("banner.zig").Banner;
pub const Overlay = overlay.Overlay;

error AddressesOverlap;

error InvalidFatSize;
error InvalidFntMainTableSize;
error InvalidFntRootDirectoryId;
error InvalidFntSubDirectoryId;
error InvalidSubTableTypeLength;
error InvalidSubDirectoryId;
error InvalidFileId;
error InvalidNameLength;
error InvalidSizeInHeader;
error FailedToWriteNitroToFnt;
error FailedToWriteNitroToFat;

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

    pub fn fromFile(file: &io.File, allocator: &mem.Allocator) %&Rom {
        var result = try allocator.create(Rom);
        errdefer allocator.destroy(result);

        result.header = try utils.noAllocRead(Header, file);
        try result.header.validate();

        result.arm9 = try utils.seekToAllocAndRead(u8, file, allocator, result.header.arm9_rom_offset.get(), result.header.arm9_size.get());
        errdefer allocator.free(result.arm9);
        result.nitro_footer = try utils.noAllocRead([3]Little(u32), file);

        result.arm7 = try utils.seekToAllocAndRead(u8, file, allocator, result.header.arm7_rom_offset.get(), result.header.arm7_size.get());
        errdefer allocator.free(result.arm7);

        result.arm9_overlay_table = try utils.seekToAllocAndRead(
            Overlay,
            file,
            allocator,
            result.header.arm9_overlay_offset.get(),
            result.header.arm9_overlay_size.get() / @sizeOf(Overlay));
        errdefer allocator.free(result.arm9_overlay_table);
        result.arm9_overlay_files = try overlay.readFiles(file, allocator, result.arm9_overlay_table, result.header.fat_offset.get());
        errdefer overlay.freeFiles(result.arm9_overlay_files, allocator);

        result.arm7_overlay_table = try utils.seekToAllocAndRead(
            Overlay,
            file,
            allocator,
            result.header.arm7_overlay_offset.get(),
            result.header.arm7_overlay_size.get() / @sizeOf(Overlay));
        errdefer allocator.free(result.arm7_overlay_table);
        result.arm7_overlay_files = try overlay.readFiles(file, allocator, result.arm7_overlay_table, result.header.fat_offset.get());
        errdefer overlay.freeFiles(result.arm7_overlay_files, allocator);

        // TODO: On dsi, this can be of different sizes
        result.banner = try utils.seekToNoAllocRead(Banner, file, result.header.banner_offset.get());
        try result.banner.validate();

        result.root = try readFileSystem(
            file,
            allocator,
            result.header.fnt_offset.get(),
            result.header.fnt_size.get(),
            result.header.fat_offset.get(),
            result.header.fat_size.get());
        errdefer result.root.destroy(allocator);

        return result;
    }

    fn readFileSystem(file: &io.File, allocator: &mem.Allocator, fnt_offset: usize, fnt_size: usize, fat_offset: usize, fat_size: usize) %fs.Folder {
        if (fat_size % @sizeOf(fs.FatEntry) != 0)       return error.InvalidFatSize;
        if (fat_size > 61440 * @sizeOf(fs.FatEntry))    return error.InvalidFatSize;

        const fnt_first = try utils.seekToNoAllocRead(fs.FntMainEntry, file, fnt_offset);
        const fnt_main_table = try utils.seekToAllocAndRead(fs.FntMainEntry, file, allocator, fnt_offset, fnt_first.parent_id.get());
        defer allocator.free(fnt_main_table);

        if (!utils.between(usize, fnt_main_table.len, 1, 4096))    return error.InvalidFntMainTableSize;
        if (fnt_size < fnt_main_table.len * @sizeOf(fs.FntMainEntry)) return error.InvalidFntMainTableSize;

        const fat = try utils.seekToAllocAndRead(fs.FatEntry, file, allocator, fat_offset, fat_size / @sizeOf(fs.FatEntry));
        defer allocator.free(fat);

        const root_name = try allocator.alloc(u8, 0);
        errdefer allocator.free(root_name);

        return buildFolderFromFntMainEntry(
            file,
            allocator,
            fat,
            fnt_main_table,
            fnt_main_table[0],
            fnt_offset,
            0,
            root_name
        );
    }

    fn buildFolderFromFntMainEntry(
        file: &io.File,
        allocator: &mem.Allocator,
        fat: []const fs.FatEntry,
        fnt_main_table: []const fs.FntMainEntry,
        fnt_entry: &const fs.FntMainEntry,
        fnt_offset: usize,
        img_base: usize,
        name: []u8) %fs.Folder {

        try file.seekTo(fnt_entry.offset_to_subtable.get() + fnt_offset);
        var folders = std.ArrayList(fs.Folder).init(allocator);
        errdefer {
            for (folders.toSlice()) |f| {
                f.destroy(allocator);
            }

            folders.deinit();
        }

        var files = std.ArrayList(fs.File).init(allocator);
        errdefer {
            for (files.toSlice()) |f| {
                f.destroy(allocator);
            }

            files.deinit();
        }

        // See FNT Sub-Tables:
        // http://problemkaputt.de/gbatek.htm#dscartridgenitroromandnitroarcfilesystems
        var file_id = fnt_entry.first_file_id_in_subtable.get();
        while (true) {
            const Kind = enum(u8) { File = 0x00, Folder = 0x80 };
            const type_length = try utils.noAllocRead(u8, file);

            if (type_length == 0x80) return error.InvalidSubTableTypeLength;
            if (type_length == 0x00) break;

            const lenght = type_length & 0x7F;
            const kind = Kind((type_length & 0x80));
            assert(kind == Kind.File or kind == Kind.Folder);

            const child_name = try utils.allocAndRead(u8, file, allocator, lenght);
            errdefer allocator.free(child_name);

            switch (kind) {
                Kind.File => {
                    if (fat.len <= file_id) return error.InvalidFileId;

                    const entry = fat[file_id];
                    const current_pos = try file.getPos();
                    const file_data = try utils.seekToAllocAndRead(u8, file, allocator, entry.start.get() + img_base, entry.getSize());
                    errdefer allocator.free(file_data);

                    try file.seekTo(current_pos);
                    try files.append(
                        fs.File {
                            .name = child_name,
                            .data = file_data,
                        }
                    );

                    file_id += 1;
                },
                Kind.Folder => {
                    const id = try utils.noAllocRead(Little(u16), file);
                    if (!utils.between(u16, id.get(), 0xF001, 0xFFFF)) return error.InvalidSubDirectoryId;
                    if (fnt_main_table.len <= id.get() & 0x0FFF)       return error.InvalidSubDirectoryId;

                    const current_pos = try file.getPos();
                    try folders.append(
                        try buildFolderFromFntMainEntry(
                            file,
                            allocator,
                            fat,
                            fnt_main_table,
                            fnt_main_table[id.get() & 0x0FFF],
                            fnt_offset,
                            img_base,
                            child_name
                        )
                    );

                    try file.seekTo(current_pos);
                }
            }
        }

        return fs.Folder {
            .name    = name,
            .folders = folders.toOwnedSlice(),
            .files   = files.toOwnedSlice()
        };
    }

    pub fn writeToFile(self: &Rom, file: &io.File) %void {
        try self.banner.validate();

        const header = &self.header;
        const fs_info = self.root.sizes();

        if (@maxValue(u16) < fs_info.folders * @sizeOf(fs.FntMainEntry)) return error.InvalidSizeInHeader;
        if (@maxValue(u16) < fs_info.files   * @sizeOf(fs.FatEntry))     return error.InvalidSizeInHeader;

        header.arm9_rom_offset     = toLittle(u32, 0x4000);
        header.arm9_size           = toLittle(u32, u32(self.arm9.len));
        header.arm9_overlay_offset = little.add(u32, header.arm9_rom_offset, header.arm9_size);
        header.arm9_overlay_size   = toLittle(u32, u32(self.arm9_overlay_table.len * @sizeOf(Overlay)));
        if (self.hasNitroFooter()) {
            header.arm9_overlay_offset = toLittle(u32, header.arm9_overlay_offset.get() + @sizeOf(@typeOf(self.nitro_footer)));
        }

        header.arm7_rom_offset     = toLittle(u32, alignAddr(u32, header.arm9_overlay_offset.get() + header.arm9_overlay_size.get(), 0x200));
        header.arm7_size           = toLittle(u32, u32(self.arm7.len));
        header.arm7_overlay_offset = toLittle(u32, header.arm7_rom_offset.get() + header.arm7_size.get());
        header.arm7_overlay_size   = toLittle(u32, u32(self.arm7_overlay_table.len * @sizeOf(Overlay)));
        header.banner_offset       = toLittle(u32, alignAddr(u32, header.arm7_overlay_offset.get() + header.arm7_overlay_size.get(), 0x200));
        header.banner_size         = toLittle(u32, @sizeOf(Banner));
        header.fnt_offset          = toLittle(u32, alignAddr(u32, header.banner_offset.get() + header.banner_size.get(), 0x200));
        header.fnt_size            = toLittle(u32, u32(fs_info.folders * @sizeOf(fs.FntMainEntry) + fs_info.fnt_sub_size));
        header.fat_offset          = toLittle(u32, alignAddr(u32, header.fnt_offset.get() + header.fnt_size.get(), 0x200));
        header.fat_size            = toLittle(u32, u32((fs_info.files + self.arm9_overlay_table.len + self.arm7_overlay_table.len) * @sizeOf(fs.FatEntry)));

        const fnt_sub_offset = header.fnt_offset.get() + fs_info.folders * @sizeOf(fs.FntMainEntry);
        const file_offset = header.fat_offset.get() + header.fat_size.get();

        var overlay_writer = overlay.Writer.init(file, file_offset, 0);
        try overlay_writer.writeOverlayFiles(self.arm9_overlay_table, self.arm9_overlay_files, header.fat_offset.get());
        try overlay_writer.writeOverlayFiles(self.arm7_overlay_table, self.arm7_overlay_files, header.fat_offset.get());

        var fs_writer = fs.FSWriter.init(file, overlay_writer.file_offset, fnt_sub_offset, overlay_writer.file_id);
        try fs_writer.writeFileSystem(self.root, header.fnt_offset.get(), header.fat_offset.get(), 0, fs_info.folders);

        header.total_used_rom_size = toLittle(u32, alignAddr(u32, fs_writer.file_offset, 4));
        header.device_capacity = blk: {
            // Devicecapacity (Chipsize = 128KB SHL nn) (eg. 7 = 16MB)
            const size = header.total_used_rom_size.get();
            var device_cap : u6 = 0;
            while (@shlExact(u64(128000), device_cap) < size) : (device_cap += 1) { }

            break :blk device_cap;
        };
        header.header_checksum = toLittle(u16, header.calcChecksum());

        try header.validate();
        try file.seekTo(0x00);
        try file.write(utils.asBytes(Header, header));
        try file.seekTo(header.arm9_rom_offset.get());
        try file.write(self.arm9);
        if (self.hasNitroFooter()) {
            try file.write(([]u8)(self.nitro_footer[0..]));
        }

        try file.seekTo(header.arm9_overlay_offset.get());
        try file.write(([]u8)(self.arm9_overlay_table));
        try file.seekTo(header.arm7_rom_offset.get());
        try file.write(self.arm7);
        try file.seekTo(header.arm7_overlay_offset.get());
        try file.write(([]u8)(self.arm7_overlay_table));
        try file.seekTo(header.banner_offset.get());
        try file.write(utils.asBytes(Banner, &self.banner));
    }

    fn hasNitroFooter(self: &const Rom) bool {
        return self.nitro_footer[0].get() == 0xDEC00621;
    }

    pub fn destroy(self: &const Rom, allocator: &mem.Allocator) void {
        allocator.free(self.arm9);
        allocator.free(self.arm7);
        allocator.free(self.arm9_overlay_table);
        allocator.free(self.arm7_overlay_table);
        overlay.freeFiles(self.arm9_overlay_files, allocator);
        overlay.freeFiles(self.arm7_overlay_files, allocator);
        self.root.destroy(allocator);
        allocator.destroy(self);
    }
};