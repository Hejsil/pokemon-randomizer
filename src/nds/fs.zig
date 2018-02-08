const std    = @import("std");
const common = @import("common.zig");
const little = @import("../little.zig");
const utils  = @import("../utils.zig");

const debug = std.debug;
const mem   = std.mem;
const io    = std.io;

const assert = debug.assert;

const toLittle = little.toLittle;
const Little   = little.Little;

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

pub const FntMainEntry = packed struct {
    offset_to_subtable: Little(u32),
    first_file_id_in_subtable: Little(u16),

    // For the first entry in main-table, the parent id is actually,
    // the total number of directories (See FNT Directory Main-Table):
    // http://problemkaputt.de/gbatek.htm#dscartridgenitroromandnitroarcfilesystems
    parent_id: Little(u16),
};

pub const FatEntry = packed struct {
    start: Little(u32),
    end: Little(u32),

    fn init(offset: u32, size: u32) FatEntry {
        return FatEntry {
            .start = toLittle(offset),
            .end   = toLittle(offset + size),
        };
    }

    fn getSize(self: &const FatEntry) usize {
        return self.end.get() - self.start.get();
    }
};

pub fn read(file: &io.File, allocator: &mem.Allocator, fnt_offset: usize, fnt_size: usize, fat_offset: usize, fat_size: usize) %Folder {
    if (fat_size % @sizeOf(FatEntry) != 0)    return error.InvalidFatSize;
    if (fat_size > 61440 * @sizeOf(FatEntry)) return error.InvalidFatSize;

    const fnt_first = try utils.seekToNoAllocRead(FntMainEntry, file, fnt_offset);
    const fnt_main_table = try utils.seekToAllocAndRead(FntMainEntry, file, allocator, fnt_offset, fnt_first.parent_id.get());
    defer allocator.free(fnt_main_table);

    if (!utils.between(usize, fnt_main_table.len, 1, 4096))       return error.InvalidFntMainTableSize;
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
    var files = std.ArrayList(File).init(allocator);
    errdefer {
        for (folders.toSlice()) |f| f.destroy(allocator);
        for (files.toSlice())   |f| f.destroy(allocator);

        folders.deinit();
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

pub const FSWriter = struct {
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
            const start = common.alignAddr(writer.file_offset, u32(0x200));
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

