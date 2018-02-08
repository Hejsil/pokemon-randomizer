const std     = @import("std");
const little  = @import("../little.zig");
const utils   = @import("../utils.zig");

const debug = std.debug;
const mem   = std.mem;
const io    = std.io;

const alignAddr = @import("alignment.zig").alignAddr;
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
            .start = toLittle(u32, offset),
            .end   = toLittle(u32, offset + size),
        };
    }

    fn getSize(self: &const FatEntry) usize {
        return self.end.get() - self.start.get();
    }
};

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
            const start = alignAddr(u32, writer.file_offset, 0x200);
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

