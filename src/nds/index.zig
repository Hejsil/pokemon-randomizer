const std    = @import("std");
const crc    = @import("crc");
const utils  = @import("utils.zig");
const ascii  = @import("ascii.zig");
const little = @import("little.zig");

const debug = std.debug;
const mem   = std.mem;
const io    = std.io;
const sort  = std.sort;

const assert = debug.assert;

const toLittle = little.toLittle;
const Little   = little.Little;

pub const Header = @import("header.zig").Header;

error InvalidVersion;
error InvalidVersionPadding;
error InvalidHasAnimatedDsiIconPadding;
error InvalidReserved1;
error InvalidReserved2;
error InvalidChinese;
error InvalidKorean;
error InvalidIconAnimationBitmap;
error InvalidIconAnimationPalette;
error InvalidIconAnimationSequence;

pub const IconTitle = packed struct {
    pub const Version = enum(u2) {
        Original                  = 0x01,
        WithChineseTitle          = 0x02,
        WithChineseAndKoreanTitle = 0x03,
    };

    version: Version,
    version_padding: u6,

    has_animated_dsi_icon: bool,
    has_animated_dsi_icon_padding: u7,

    crc16_across_0020h_083Fh: Little(u16),
    crc16_across_0020h_093Fh: Little(u16),
    crc16_across_0020h_0A3Fh: Little(u16),
    crc16_across_1240h_23BFh: Little(u16),

    reserved1: [0x16]u8,

    icon_bitmap: [0x200]u8,
    icon_palette: [0x20]u8,

    title_japanese: [0x100]u8,
    title_english:  [0x100]u8,
    title_french:   [0x100]u8,
    title_german:   [0x100]u8,
    title_italian:  [0x100]u8,
    title_spanish:  [0x100]u8,
    //title_chinese:  [0x100]u8,
    //title_korean:   [0x100]u8,

    // TODO: IconTitle is actually a variable size structure.
    //       "original Icon/Title structure rounded to 200h-byte sector boundary (ie. A00h bytes for Version 1 or 2)," 
    //       "however, later DSi carts are having a size entry at CartHdr[208h] (usually 23C0h)."
    //reserved2: [0x800]u8,

    //// animated DSi icons only
    //icon_animation_bitmap: [0x1000]u8,
    //icon_animation_palette: [0x100]u8,
    //icon_animation_sequence: [0x80]u8, // Should be [0x40]Little(u16)?

    pub fn validate(self: &const IconTitle) %void {
        if (u2(self.version) == 0)
            return error.InvalidVersion;
        if (self.version_padding != 0)
            return error.InvalidVersionPadding;
        if (self.has_animated_dsi_icon_padding != 0)
            return error.InvalidHasAnimatedDsiIconPadding;

        if (!utils.all(u8, self.reserved1, ascii.isZero))
            return error.InvalidReserved1;

        //if (!utils.all(u8, self.reserved2, ascii.isZero))
        //    return error.InvalidReserved2;

        //if (!self.has_animated_dsi_icon) {
        //    if (!utils.all(u8, self.icon_animation_bitmap, is0xFF))
        //        return error.InvalidIconAnimationBitmap;
        //    if (!utils.all(u8, self.icon_animation_palette, is0xFF))
        //        return error.InvalidIconAnimationPalette;
        //    if (!utils.all(u8, self.icon_animation_sequence, is0xFF))
        //        return error.InvalidIconAnimationSequence;
        //}
    }

    fn is0xFF(char: u8) bool { return char == 0xFF; }
};

error AddressesOverlap;

pub const File = struct {
    name: []u8,
    data: []u8,

    pub fn destroy(file: &const File, allocator: &mem.Allocator) void {
        allocator.free(file.name);
        allocator.free(file.data);
    }
};

pub const Folder = struct {
    name:    []u8,
    files:   []File,
    folders: []Folder,

    pub fn destroy(folder: &const Folder, allocator: &mem.Allocator) void {
        for (folder.folders) |fold| {
            fold.destroy(allocator);
        }

        for (folder.files) |file| {
            file.destroy(allocator);
        }

        allocator.free(folder.name);
        allocator.free(folder.files);
        allocator.free(folder.folders);
    }

    pub fn getFile(folder: &const Folder, path: []const u8) ?&File {
        var splitIter = mem.split(path, "/");
        var curr_folder = folder;
        var curr = splitIter.next() ?? return null;

        while (splitIter.next()) |next| : (curr = next) {
            for (curr_folder.folders) |*sub_folder| {
                if (mem.eql(u8, curr, sub_folder.name)) {
                    curr_folder = sub_folder;
                    break;
                }
            } else {
                return null;
            }
        }

        for (curr_folder.files) |*file| {
            if (mem.eql(u8, curr, file.name)) {
                return file;
            }
        }

        return null;
    }

    fn printIndent(stream: &io.OutStream, indent: usize) %void {
        var i : usize = 0;
        while (i < indent) : (i += 1) {
            try stream.write("    ");
        }
    }

    pub fn tree(folder: &const Folder, stream: &io.OutStream, indent: usize) %void {
        try printIndent(stream, indent);
        try stream.print("{}/\n", folder.name);

        for (folder.folders) |f| {
            try f.tree(stream, indent + 1);
        }

        for (folder.files) |f| {
            try printIndent(stream, indent + 1);
            try stream.print("{}\n", f.name);
        }
    }

    const Sizes = struct {
        files: u16,
        folders: u16,
        fnt_sub_size: u32,
    };

    fn sizes(folder: &const Folder) Sizes {
        var result = Sizes {
            .files = 0,
            .folders = 0,
            .fnt_sub_size = 0,
        };

        // Each folder have a sub fnt, which is terminated by 0x00
        result.fnt_sub_size += 1;
        result.folders      += 1;

        for (folder.folders) |fold| {
            const s = fold.sizes();
            result.files        += s.files;
            result.folders      += s.folders;
            result.fnt_sub_size += s.fnt_sub_size;

            result.fnt_sub_size += 1;
            result.fnt_sub_size += u16(fold.name.len);
            result.fnt_sub_size += 2;
        }

        for (folder.files) |file| {
            result.files        += 1;
            result.fnt_sub_size += 1;
            result.fnt_sub_size += u16(file.name.len);
        }

        return result;
    }
};

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

    icon_title: IconTitle,
    root: Folder,

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
        result.arm9_overlay_files = try readOverlayFiles(file, allocator, result.arm9_overlay_table, result.header.fat_offset.get());
        errdefer cleanUpOverlayFiles(result.arm9_overlay_files, allocator);

        result.arm7_overlay_table = try utils.seekToAllocAndRead(
            Overlay,
            file,
            allocator,
            result.header.arm7_overlay_offset.get(),
            result.header.arm7_overlay_size.get() / @sizeOf(Overlay));
        errdefer allocator.free(result.arm7_overlay_table);
        result.arm7_overlay_files = try readOverlayFiles(file, allocator, result.arm7_overlay_table, result.header.fat_offset.get());
        errdefer cleanUpOverlayFiles(result.arm7_overlay_files, allocator);

        // TODO: On dsi, this can be of different sizes
        result.icon_title = try utils.seekToNoAllocRead(IconTitle, file, result.header.icon_title_offset.get());
        try result.icon_title.validate();

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

    fn readOverlayFiles(file: &io.File, allocator: &mem.Allocator, overlay_table: []Overlay, fat_offset: usize) %[][]u8 {
        var results = try allocator.alloc([]u8, overlay_table.len);
        var allocated : usize = 0;
        errdefer cleanUpOverlayFiles(results[0..allocated], allocator);

        var file_stream = io.FileInStream.init(file);
        var stream = &file_stream.stream;

        for (results) |*res, i| {
            const overlay = overlay_table[i];
            const offset = (overlay.file_id.get() & 0x0FFF) * @sizeOf(FatEntry);

            var fat_entry : FatEntry = undefined;
            try file.seekTo(fat_offset + offset);
            try stream.readNoEof(utils.asBytes(FatEntry, &fat_entry));

            *res = try utils.seekToAllocAndRead(u8, file, allocator, fat_entry.start.get(), fat_entry.getSize());
        }

        return results;
    }

    fn cleanUpOverlayFiles(files: [][]u8, allocator: &mem.Allocator) void {
        for (files) |file|
            allocator.free(file);

        allocator.free(files);
    }

    fn readFileSystem(file: &io.File, allocator: &mem.Allocator, fnt_offset: usize, fnt_size: usize, fat_offset: usize, fat_size: usize) %Folder {
        if (fat_size % @sizeOf(FatEntry) != 0)       return error.InvalidFatSize;
        if (fat_size > 61440 * @sizeOf(FatEntry))    return error.InvalidFatSize;

        const fnt_first = try utils.seekToNoAllocRead(FntMainEntry, file, fnt_offset);
        const fnt_main_table = try utils.seekToAllocAndRead(FntMainEntry, file, allocator, fnt_offset, fnt_first.parent_id.get());
        defer allocator.free(fnt_main_table);

        if (!utils.between(usize, fnt_main_table.len, 1, 4096))    return error.InvalidFntMainTableSize;
        if (fnt_size < fnt_main_table.len * @sizeOf(FntMainEntry)) return error.InvalidFntMainTableSize;

        const fat = try utils.seekToAllocAndRead(FatEntry, file, allocator, fat_offset, fat_size / @sizeOf(FatEntry));
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
        fat: []const FatEntry,
        fnt_main_table: []const FntMainEntry,
        fnt_entry: &const FntMainEntry,
        fnt_offset: usize,
        img_base: usize,
        name: []u8) %Folder {

        try file.seekTo(fnt_entry.offset_to_subtable.get() + fnt_offset);
        var folders = std.ArrayList(Folder).init(allocator);
        errdefer {
            for (folders.toSlice()) |f| {
                f.destroy(allocator);
            }

            folders.deinit();
        }

        var files = std.ArrayList(File).init(allocator);
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
                        File {
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

        return Folder {
            .name    = name,
            .folders = folders.toOwnedSlice(),
            .files   = files.toOwnedSlice()
        };
    }

    pub fn writeToFile(self: &Rom, file: &io.File) %void {
        try self.icon_title.validate();

        const header = &self.header;
        const fs_info = self.root.sizes();

        if (@maxValue(u16) < fs_info.folders * @sizeOf(FntMainEntry)) return error.InvalidSizeInHeader;
        if (@maxValue(u16) < fs_info.files   * @sizeOf(FatEntry))     return error.InvalidSizeInHeader;

        header.arm9_rom_offset     = toLittle(u32, 0x4000);
        header.arm9_size           = toLittle(u32, u32(self.arm9.len));
        header.arm9_overlay_offset = little.add(u32, header.arm9_rom_offset, header.arm9_size);
        header.arm9_overlay_size   = toLittle(u32, u32(self.arm9_overlay_table.len * @sizeOf(Overlay)));
        if (self.hasNitroFooter()) {
            header.arm9_overlay_offset = toLittle(u32, header.arm9_overlay_offset.get() + @sizeOf(@typeOf(self.nitro_footer)));
        }

        header.arm7_rom_offset     = toLittle(u32, alignAddr(u32, header.arm9_overlay_offset.get() + header.arm9_overlay_size.get(), nds_alignment));
        header.arm7_size           = toLittle(u32, u32(self.arm7.len));
        header.arm7_overlay_offset = toLittle(u32, header.arm7_rom_offset.get() + header.arm7_size.get());
        header.arm7_overlay_size   = toLittle(u32, u32(self.arm7_overlay_table.len * @sizeOf(Overlay)));
        header.icon_title_offset   = toLittle(u32, alignAddr(u32, header.arm7_overlay_offset.get() + header.arm7_overlay_size.get(), nds_alignment));
        header.icon_title_size     = toLittle(u32, @sizeOf(IconTitle));
        header.fnt_offset          = toLittle(u32, alignAddr(u32, header.icon_title_offset.get() + header.icon_title_size.get(), nds_alignment));
        header.fnt_size            = toLittle(u32, u32(fs_info.folders * @sizeOf(FntMainEntry) + fs_info.fnt_sub_size));
        header.fat_offset          = toLittle(u32, alignAddr(u32, header.fnt_offset.get() + header.fnt_size.get(), nds_alignment));
        header.fat_size            = toLittle(u32, u32((fs_info.files + self.arm9_overlay_table.len + self.arm7_overlay_table.len) * @sizeOf(FatEntry)));

        const fnt_sub_offset = header.fnt_offset.get() + fs_info.folders * @sizeOf(FntMainEntry);
        const file_offset = header.fat_offset.get() + header.fat_size.get();

        var overlay_writer = OverlayWriter.init(file, file_offset, 0);
        try overlay_writer.writeOverlayFiles(self.arm9_overlay_table, self.arm9_overlay_files, header.fat_offset.get());
        try overlay_writer.writeOverlayFiles(self.arm7_overlay_table, self.arm7_overlay_files, header.fat_offset.get());

        var fs_writer = FSWriter.init(file, overlay_writer.file_offset, fnt_sub_offset, overlay_writer.file_id);
        try fs_writer.writeFileSystem(self.root, header.fnt_offset.get(), header.fat_offset.get(), 0, fs_info.folders);

        header.total_used_rom_size = toLittle(u32, alignAddr(u32, fs_writer.file_offset, 4));
        header.device_capacity = blk: {
            // Devicecapacity (Chipsize = 128KB SHL nn) (eg. 7 = 16MB)
            const size = header.total_used_rom_size.get();
            var device_cap : u6 = 0;
            while (@shlExact(u64(128000), device_cap) < size) : (device_cap += 1) { }

            break :blk device_cap;
        };
        header.header_checksum = toLittle(u16, crc_modbus.checksum(utils.asConstBytes(Header, header)[0..0x15E]));

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
        try file.seekTo(header.icon_title_offset.get());
        try file.write(utils.asBytes(IconTitle, &self.icon_title));
    }

    fn hasNitroFooter(self: &const Rom) bool {
        return self.nitro_footer[0].get() == 0xDEC00621;
    }

    pub fn destroy(self: &const Rom, allocator: &mem.Allocator) void {
        allocator.free(self.arm9);
        allocator.free(self.arm7);
        allocator.free(self.arm9_overlay_table);
        allocator.free(self.arm7_overlay_table);
        cleanUpOverlayFiles(self.arm9_overlay_files, allocator);
        cleanUpOverlayFiles(self.arm7_overlay_files, allocator);
        self.root.destroy(allocator);
        allocator.destroy(self);
    }
};

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

const OverlayWriter = struct {
    file: &io.File,
    file_offset: u32,
    file_id: u16,

    fn init(file: &io.File, file_offset: u32, start_file_id: u16) OverlayWriter {
        return OverlayWriter {
            .file = file,
            .file_offset = file_offset,
            .file_id = start_file_id,
        };
    }

    fn writeOverlayFiles(self: &OverlayWriter, overlay_table: []Overlay, overlay_files: []const []u8, fat_offset: usize) %void {
        for (overlay_table) |*overlay_entry, i| {
            const overlay_file = overlay_files[i];
            const fat_entry = FatEntry.init(alignAddr(u32, self.file_offset, nds_alignment), u32(overlay_file.len));
            try self.file.seekTo(fat_offset + (self.file_id * @sizeOf(FatEntry)));
            try self.file.write(utils.asConstBytes(FatEntry, fat_entry));

            try self.file.seekTo(fat_entry.start.get());
            try self.file.write(overlay_file);

            overlay_entry.overlay_id = toLittle(u32, u32(i));
            overlay_entry.file_id = toLittle(u32, u32(self.file_id));
            self.file_offset = u32(try self.file.getPos());
            self.file_id += 1;
        }
    }
};

const nds_alignment = 0x200;
fn alignAddr(comptime T: type, address: T, alignment: T) T {
    const rem = address % alignment;
    const result = address + (alignment - rem);

    assert(result % alignment == 0);
    assert(address <= result);

    return result;
}

const FntMainEntry = packed struct {
    offset_to_subtable: Little(u32),
    first_file_id_in_subtable: Little(u16),

    // For the first entry in main-table, the parent id is actually,
    // the total number of directories (See FNT Directory Main-Table):
    // http://problemkaputt.de/gbatek.htm#dscartridgenitroromandnitroarcfilesystems
    parent_id: Little(u16),
};

const FatEntry = packed struct {
    start: Little(u32),
    end: Little(u32),

    fn init(offset: u32, size: u32) FatEntry {
        return FatEntry {
            .start = toLittle(u32, offset),
            .end   = toLittle(u32, offset + size),
        };
    }

    fn getSize(self: &const FatEntry) usize {
        return self.end.get() - self.start.get();
    }
};

const FSWriter = struct {
    file: &io.File,
    file_offset: u32,
    fnt_sub_offset: u32,
    file_id: u16,
    folder_id: u16,

    fn init(file: &io.File, file_offset: u32, fnt_sub_offset: u32, start_file_id: u16) FSWriter {
        return FSWriter {
            .file = file,
            .file_offset = file_offset,
            .fnt_sub_offset = fnt_sub_offset,
            .file_id = start_file_id,
            .folder_id = 0xF000,
        };
    }

    fn writeFileSystem(writer: &FSWriter, root: &const Folder, fnt_offset: u32, fat_offset: u32, img_base: u32, folder_count: u16) %void {
        try writer.file.seekTo(fnt_offset);
        try writer.file.write(utils.asConstBytes(
            FntMainEntry,
            FntMainEntry {
                .offset_to_subtable        = Little(u32).init(writer.fnt_sub_offset - fnt_offset),
                .first_file_id_in_subtable = Little(u16).init(writer.file_id),
                .parent_id                 = Little(u16).init(folder_count),
            }));

        try writer.writeFolder(root, fnt_offset, fat_offset, img_base, writer.folder_id);
    }

    fn writeFolder(writer: &FSWriter, folder: &const Folder, fnt_offset: u32, fat_offset: u32, img_base: u32, id: u16) %void {
        for (folder.files) |f| {
            // Write file to sub fnt
            try writer.file.seekTo(writer.fnt_sub_offset);
            try writer.file.write([]u8 { u8(f.name.len) });
            try writer.file.write(f.name);
            writer.fnt_sub_offset = u32(try writer.file.getPos());

            // Write file content
            const start = alignAddr(u32, writer.file_offset, nds_alignment);
            try writer.file.seekTo(start);
            try writer.file.write(f.data);

            writer.file_offset = u32(try writer.file.getPos());
            const size = writer.file_offset - start;

            // Write offsets to fat
            try writer.file.seekTo(fat_offset + @sizeOf(FatEntry) * writer.file_id);
            try writer.file.write(
                utils.asConstBytes(
                    FatEntry,
                    FatEntry.init(u32(start - img_base), u32(size))
                ));
            writer.file_id += 1;
        }

        // Skip writing folders to sub table, but still skip forward all the bytes
        // so we can start writing sub folders sub tables.
        var curr_sub_offset = writer.fnt_sub_offset;
        for (folder.folders) |f, i| {
            writer.fnt_sub_offset += 1;               // try writer.file.write([]u8 { u8(f.name.len + 0x80) });
            writer.fnt_sub_offset += u32(f.name.len); // try writer.file.write(f.name);
            writer.fnt_sub_offset += 2;               // try writer.file.write(utils.asConstBytes(Little(u16), Little(u16).init(writer.folder_id)));
        }
        writer.fnt_sub_offset += 1; // '\0'

        const assert_end = writer.fnt_sub_offset;

        for (folder.folders) |f| {
            writer.folder_id += 1;
            try writer.file.seekTo(curr_sub_offset);
            try writer.file.write([]u8 { u8(f.name.len + 0x80) });
            try writer.file.write(f.name);
            try writer.file.write(utils.asConstBytes(Little(u16), Little(u16).init(writer.folder_id)));
            curr_sub_offset = u32(try writer.file.getPos());

            const main_offset = fnt_offset + @sizeOf(FntMainEntry) * (writer.folder_id & 0x0FFF);
            try writer.file.seekTo(main_offset);
            try writer.file.write(utils.asConstBytes(
                FntMainEntry,
                FntMainEntry {
                    .offset_to_subtable        = Little(u32).init(writer.fnt_sub_offset - fnt_offset),
                    .first_file_id_in_subtable = Little(u16).init(writer.file_id),
                    .parent_id                 = Little(u16).init(id),
                }));

            try writer.writeFolder(f, fnt_offset, fat_offset, img_base, writer.folder_id);
        }

        try writer.file.seekTo(curr_sub_offset);
        try writer.file.write([]u8 { 0x00 });
        curr_sub_offset = u32(try writer.file.getPos());
        assert(curr_sub_offset == assert_end);
    }
};

comptime {
    assert(@offsetOf(IconTitle, "version")                  == 0x0000);
    assert(@offsetOf(IconTitle, "has_animated_dsi_icon")    == 0x0001);

    assert(@offsetOf(IconTitle, "crc16_across_0020h_083Fh") == 0x0002);
    assert(@offsetOf(IconTitle, "crc16_across_0020h_093Fh") == 0x0004);
    assert(@offsetOf(IconTitle, "crc16_across_0020h_0A3Fh") == 0x0006);
    assert(@offsetOf(IconTitle, "crc16_across_1240h_23BFh") == 0x0008);
    assert(@offsetOf(IconTitle, "reserved1")                == 0x000A);

    assert(@offsetOf(IconTitle, "icon_bitmap")              == 0x0020);
    assert(@offsetOf(IconTitle, "icon_palette")             == 0x0220);

    assert(@offsetOf(IconTitle, "title_japanese")           == 0x0240);
    assert(@offsetOf(IconTitle, "title_english")            == 0x0340);
    assert(@offsetOf(IconTitle, "title_french")             == 0x0440);
    assert(@offsetOf(IconTitle, "title_german")             == 0x0540);
    assert(@offsetOf(IconTitle, "title_italian")            == 0x0640);
    assert(@offsetOf(IconTitle, "title_spanish")            == 0x0740);
    //assert(@offsetOf(IconTitle, "title_chinese")            == 0x0840);
    //assert(@offsetOf(IconTitle, "title_korean")             == 0x0940);
    //assert(@offsetOf(IconTitle, "reserved2")               == 0x0A40);

    //assert(@offsetOf(IconTitleT, "icon_animation_bitmap")   == 0x1240);
    //assert(@offsetOf(IconTitleT, "icon_animation_palette")  == 0x2240);
    //assert(@offsetOf(IconTitle, "icon_animation_sequence") == 0x2340);
    //
    //assert(@sizeOf(IconTitle) == 0x23C0);
}
