const std    = @import("std");
const common = @import("common.zig");
const formats = @import("formats.zig");
const little = @import("../little.zig");
const utils  = @import("../utils/index.zig");

const debug = std.debug;
const mem   = std.mem;
const heap  = std.heap;
const io    = std.io;
const os    = std.os;
const math  = std.math;

const assert = debug.assert;

const toLittle = little.toLittle;
const Little   = little.Little;

pub fn Tree(comptime FileType: type) type {
    return struct {
        const Self = this;

        arena: std.heap.ArenaAllocator,
        root: &Folder,

        // GIGA HACK!: We allocate the tree with the arenas child allocator. This allows us to
        //             return Trees without invalidating the pointers to tree.arena.allocator.
        pub fn alloc(allocator: &mem.Allocator) !&Self {
            const res = try allocator.create(Self);
            res.arena = std.heap.ArenaAllocator.init(allocator);
            res.root = try res.createFolder(try mem.dupe(&res.arena.allocator, u8, ""));

            return res;
        }

        pub const Folder = struct {
            name:    []u8,
            files:   std.ArrayList(&FileType),
            folders: std.ArrayList(&Folder),
        };

        pub fn createFolder(tree: &Self, name: []u8) !&Folder {
            const node = try tree.arena.allocator.create(Folder);
            *node = Folder {
                .name = name,
                .files = std.ArrayList(&FileType).init(&tree.arena.allocator),
                .folders = std.ArrayList(&Folder).init(&tree.arena.allocator),
            };

            return node;
        }

        pub fn createFile(tree: &Self, init_value: &const FileType) !&FileType {
            const node = try tree.arena.allocator.create(FileType);
            *node = *init_value;

            return node;
        }

        pub fn getFile(tree: &const Self, path: []const u8) ?&FileType {
            var splitIter = mem.split(path, "/");
            var curr_folder = tree.root;
            var curr = splitIter.next() ?? return null;

            while (splitIter.next()) |next| : (curr = next) {
                for (curr_folder.folders.toSliceConst()) |sub_folder| {
                    if (mem.eql(u8, curr, sub_folder.name)) {
                        curr_folder = sub_folder;
                        break;
                    }
                } else {
                    return null;
                }
            }

            for (curr_folder.files.toSliceConst()) |file| {
                if (mem.eql(u8, curr, file.name)) {
                    return file;
                }
            }

            return null;
        }

        fn printIndent(stream: &io.OutStream, indent: usize) !void {
            var i : usize = 0;
            while (i < indent) : (i += 1) {
                try stream.write("    ");
            }
        }

        // TODO: Remove recursion and make this function less hacky
        pub fn printTree(tree: &const Tree, stream: &io.OutStream, indent: usize) !void {
            try printIndent(stream, indent);
            try stream.print("{}/\n", tree.root.name);

            for (folder.folders) |f| {
                const new_tree = Self {
                    .arena = tree.arena,
                    .root = f,
                };
                try new_tree.printTree(stream, indent + 1);
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

        // TODO: Remove recursion and make this function less hacky
        fn sizes(tree: &const Self) Sizes {
            var result = Sizes {
                .files = 0,
                .folders = 0,
                .fnt_sub_size = 0,
            };

            // Each folder have a sub fnt, which is terminated by 0x00
            result.fnt_sub_size += 1;
            result.folders      += 1;

            for (tree.root.folders.toSliceConst()) |fold| {
                const new_tree = Self {
                    .arena = tree.arena,
                    .root = fold,
                };
                const s = new_tree.sizes();
                result.files        += s.files;
                result.folders      += s.folders;
                result.fnt_sub_size += s.fnt_sub_size;

                result.fnt_sub_size += 1;
                result.fnt_sub_size += u16(fold.name.len);
                result.fnt_sub_size += 2;
            }

            for (tree.root.files.toSliceConst()) |file| {
                result.files        += 1;
                result.fnt_sub_size += 1;
                result.fnt_sub_size += u16(file.name.len);
            }

            return result;
        }

        pub fn deinit(tree: &Self) void {
            tree.arena.deinit();
            tree.arena.child_allocator.destroy(tree);
        }
    };
}

pub const NarcFile = struct {
    name: []u8,
    data: []u8,
};

pub const NitroFile = struct {
    name: []u8,
    @"type": Type,

    const Type = union(enum) {
        Binary: []u8,
        Narc: &Tree(NarcFile),
    };
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

    fn getSize(entry: &const FatEntry) usize {
        return entry.end.get() - entry.start.get();
    }
};

pub fn read(file: &os.File, allocator: &mem.Allocator, fnt: []const u8, fat: []const FatEntry) !&Tree(NitroFile) {
    return readHelper(NitroFile, file, allocator, fnt, fat, 0);
}

fn readHelper(comptime FileType: type, file: &os.File, allocator: &mem.Allocator, fnt: []const u8, fat: []const FatEntry, img_base: usize) !&Tree(FileType) {
    const fnt_main_table = blk: {
        const new_len = fnt.len - (fnt.len % @sizeOf(FntMainEntry));
        const tmp = ([]const FntMainEntry)(fnt[0..new_len]);

        const first = utils.slice.atOrNull(tmp, 0) ?? return error.InvalidFnt;
        const res = utils.slice.sliceOrNull(tmp, 0, first.parent_id.get()) ?? return error.InvalidFnt;
        if (res.len > 4096) return error.InvalidFnt;

        break :blk res;
    };

    const State = struct {
        folder: &Tree(FileType).Folder,
        file_id: u16,
        fnt_sub_table: []const u8,
    };

    var stack = std.ArrayList(State).init(allocator);
    defer stack.deinit();

    const tree = try Tree(FileType).alloc(allocator);
    errdefer tree.deinit();

    const fnt_first = fnt_main_table[0];
    try stack.append(State {
        .folder = tree.root,
        .file_id = fnt_first.first_file_id_in_subtable.get(),
        .fnt_sub_table = utils.slice.sliceOrNull(fnt, fnt_first.offset_to_subtable.get(), fnt.len) ?? return error.InvalidFnt,
    });

    while (stack.popOrNull()) |state| {
        const folder = state.folder;
        const file_id = state.file_id;
        const fnt_sub_table = state.fnt_sub_table;

        var mem_stream = utils.stream.MemInStream.init(fnt_sub_table);
        const stream = &mem_stream.stream;

        const Kind = enum(u8) { File = 0x00, Folder = 0x80 };
        const type_length = try utils.stream.read(stream, u8);

        if (type_length == 0x80) return error.InvalidSubTableTypeLength;
        if (type_length == 0x00) continue;

        const lenght = type_length & 0x7F;
        const kind = Kind((type_length & 0x80));
        assert(kind == Kind.File or kind == Kind.Folder);

        const name = try utils.stream.allocRead(stream, &tree.arena.allocator, u8, lenght);
        switch (kind) {
            Kind.File => {
                const fat_entry = utils.slice.atOrNull(fat, file_id) ?? return error.InvalidFileId;
                const sub_file = try readFile(FileType, tree, file, allocator, fat_entry, img_base, name);
                try folder.files.append(sub_file);

                stack.append(State {
                    .folder = folder,
                    .file_id = file_id + 1,
                    .fnt_sub_table = mem_stream.memory,
                }) catch unreachable;
            },
            Kind.Folder => {
                const id = try utils.stream.read(stream, Little(u16));
                if (id.get() < 0xF001 or id.get() > 0xFFFF) return error.InvalidSubDirectoryId;

                const fnt_entry = utils.slice.atOrNull(fnt_main_table, id.get() & 0x0FFF) ?? return error.InvalidSubDirectoryId;
                const sub_folder = try tree.createFolder(name);

                try folder.folders.append(sub_folder);

                stack.append(State {
                    .folder = folder,
                    .file_id = file_id,
                    .fnt_sub_table = mem_stream.memory,
                }) catch unreachable;
                try stack.append(State {
                    .folder = sub_folder,
                    .file_id = fnt_entry.first_file_id_in_subtable.get(),
                    .fnt_sub_table = utils.slice.sliceOrNull(fnt, fnt_entry.offset_to_subtable.get(), fnt.len) ?? return error.InvalidFnt,
                });
            }
        }
    }

    return tree;
}

fn readFile(comptime FileType: type, tree: &Tree(FileType), file: &os.File, tmp_allocator: &mem.Allocator, fat_entry: &const FatEntry, img_base: usize, name: []u8) !&FileType {
    if (FileType == NitroFile) {
        narc_read: {
            const names = formats.Chunk.names;
            const header = utils.file.seekToRead(file, fat_entry.start.get() + img_base, formats.Header) catch break :narc_read;
            if (!mem.eql(u8, header.chunk_name, names.narc)) break :narc_read;
            if (header.byte_order.get() != 0xFFFE)           break :narc_read;
            if (header.chunk_size.get() != 0x0010)           break :narc_read;
            if (header.following_chunks.get() != 0x0003)     break :narc_read;

            // If we have a valid narc header, then we assume we are reading a narc
            // file. All error from here, are therefore bubbled up.
            const fat_chunk_size = @sizeOf(formats.Chunk) + @sizeOf(Little(u16)) * 2;
            const fat_header      = try utils.file.read(file, formats.Chunk);
            const file_count      = try utils.file.read(file, Little(u16));
            const reserved        = try utils.file.read(file, Little(u16));
            if (!mem.eql(u8, fat_header.name, names.fat)) return error.InvalidChunkName;
            if ((fat_header.size.get() - fat_chunk_size) % @sizeOf(FatEntry) != 0) return error.InvalidChunkSize;
            if ((fat_header.size.get() - fat_chunk_size) / @sizeOf(FatEntry) != file_count.get()) return error.InvalidChunkSize;

            const fat = try utils.file.allocRead(file, tmp_allocator, FatEntry, file_count.get());
            defer tmp_allocator.free(fat);

            const fnt_header = try utils.file.read(file, formats.Chunk);
            if (!mem.eql(u8, fnt_header.name, names.fnt))       return error.InvalidChunkName;

            const fnt_size = math.sub(u32, fnt_header.size.get(), @sizeOf(formats.Chunk)) catch return error.InvalidChunkSize;
            const fnt = try utils.file.allocRead(file, tmp_allocator, u8, fnt_size);
            defer tmp_allocator.free(fnt);

            const first_fnt = utils.slice.atOrNull(([]FntMainEntry)(fnt[0..fnt.len - (fnt.len % @sizeOf(FntMainEntry))]), 0) ?? return error.InvalidChunkSize;

            const file_data_header = try utils.file.read(file, formats.Chunk);
            const narc_img_base    = try file.getPos();
            if (!mem.eql(u8, file_data_header.name, names.file_data)) return error.InvalidChunkName;

            // If the first_fnt's offset points into it self, then there doesn't exist an
            // fnt sub table and files don't have names. We therefore can't use our normal
            // read function, as it relies on the fnt sub table to build the file system.
            if (first_fnt.offset_to_subtable.get() < @sizeOf(FntMainEntry)) {
                const sub_tree = try Tree(NarcFile).alloc(&tree.arena.allocator);
                const files = &sub_tree.root.files;
                try files.ensureCapacity(file_count.get());

                for (fat) |entry| {
                    const sub_file_name = try mem.dupe(&sub_tree.arena.allocator, u8, "");
                    const sub_file = try readFile(NarcFile, sub_tree, file, tmp_allocator, entry, narc_img_base, sub_file_name);
                    try files.append(sub_file);
                }

                return tree.createFile(
                    NitroFile {
                        .name = name,
                        .@"type" = NitroFile.Type { .Narc = sub_tree, },
                    }
                );
            } else {
                const sub_tree = try readHelper(NarcFile, file, &tree.arena.allocator, fnt, fat, narc_img_base);
                return tree.createFile(
                    NitroFile {
                        .name = name,
                        .@"type" = NitroFile.Type { .Narc = sub_tree, },
                    }
                );
            }
        }

        const data = try utils.file.seekToAllocRead(file, fat_entry.start.get() + img_base, &tree.arena.allocator, u8, fat_entry.getSize());
        return tree.createFile(
            NitroFile {
                .name = name,
                .@"type" = NitroFile.Type { .Binary = data, },
            }
        );
    } else if (FileType == NarcFile) {
        const data = try utils.file.seekToAllocRead(file, fat_entry.start.get() + img_base, &tree.arena.allocator, u8, fat_entry.getSize());
        return tree.createFile(
            NarcFile {
                .name = name,
                .data = data,
            }
        );
    } else {
        comptime unreachable;
    }
}

pub fn FSWriter(comptime FileType: type) type {
    return struct {
        const Self = this;
        const TreeType = Tree(FileType);

        file: &os.File,
        file_offset: u32,
        fnt_sub_offset: u32,
        file_id: u16,
        folder_id: u16,

        pub fn init(file: &os.File, file_offset: u32, start_file_id: u16) Self {
            return Self {
                .file = file,
                .file_offset = file_offset,
                .fnt_sub_offset = 0,
                .file_id = start_file_id,
                .folder_id = 0xF000,
            };
        }

        // TODO: More specific error set
        pub fn writeFileSystem(writer: &Self, tree: &const Tree(FileType), fnt_offset: u32, fat_offset: u32, img_base: u32, folder_count: u16) error!void {
            writer.fnt_sub_offset = fnt_offset + folder_count * @sizeOf(FntMainEntry);
            try writer.file.seekTo(fnt_offset);
            try writer.file.write(utils.toBytes(
                FntMainEntry,
                FntMainEntry {
                    .offset_to_subtable        = Little(u32).init(writer.fnt_sub_offset - fnt_offset),
                    .first_file_id_in_subtable = Little(u16).init(writer.file_id),
                    .parent_id                 = Little(u16).init(folder_count),
                }));

            try writer.writeFolder(tree.root, fnt_offset, fat_offset, img_base, writer.folder_id);
        }

        // TODO: More specific error set
        fn writeFolder(writer: &Self, folder: &const Tree(FileType).Folder, fnt_offset: u32, fat_offset: u32, img_base: u32, id: u16) error!void {
            for (folder.files.toSliceConst()) |f| {
                // Write file to sub fnt
                try writer.file.seekTo(writer.fnt_sub_offset);
                try writer.file.write([]u8 { u8(f.name.len) });
                try writer.file.write(f.name);
                writer.fnt_sub_offset = u32(try writer.file.getPos());

                // Write file content
                const start = common.@"align"(writer.file_offset, u32(0x200));
                try writer.file.seekTo(start);

                const size = try writeFile(FileType, writer.file, f);
                writer.file_offset = start + size;

                // Write offsets to fat
                try writer.file.seekTo(fat_offset + @sizeOf(FatEntry) * usize(writer.file_id));
                try writer.file.write(utils.toBytes(FatEntry, FatEntry.init(u32(start - img_base), size)));
                writer.file_id += 1;
            }

            // Skip writing folders to sub table, but still skip forward all the bytes
            // so we can start writing sub folders sub tables.
            var curr_sub_offset = writer.fnt_sub_offset;
            for (folder.folders.toSliceConst()) |f, i| {
                writer.fnt_sub_offset += 1;               // try writer.file.write([]u8 { u8(f.name.len + 0x80) });
                writer.fnt_sub_offset += u32(f.name.len); // try writer.file.write(f.name);
                writer.fnt_sub_offset += 2;               // try writer.file.write(utils.asConstBytes(Little(u16), Little(u16).init(writer.folder_id)));
            }
            writer.fnt_sub_offset += 1; // '\0'

            const assert_end = writer.fnt_sub_offset;

            for (folder.folders.toSliceConst()) |f| {
                writer.folder_id += 1;
                try writer.file.seekTo(curr_sub_offset);
                try writer.file.write([]u8 { u8(f.name.len + 0x80) });
                try writer.file.write(f.name);
                try writer.file.write(utils.toBytes(Little(u16), Little(u16).init(writer.folder_id)));
                curr_sub_offset = u32(try writer.file.getPos());

                const main_offset = fnt_offset + @sizeOf(FntMainEntry) * (writer.folder_id & 0x0FFF);
                try writer.file.seekTo(main_offset);
                try writer.file.write(utils.toBytes(
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
}

// TODO: More specific error set
pub fn writeFile(comptime FileType: type, file: &os.File, fs_file: &const FileType) error!u32 {
    const start = try file.getPos();

    if (FileType == NitroFile) {
        switch (fs_file.@"type") {
            NitroFile.Type.Binary => |data| {
                try file.write(data);
                return u32(data.len);
            },
            NitroFile.Type.Narc => |narc_fs| {
                const names = formats.Chunk.names;
                const fs_info = narc_fs.sizes();

                // We write the narc header last.
                try file.seekTo(start + @sizeOf(formats.Header));
                const fat_chunk_start = try file.getPos();
                const fat_chunk_end   = fat_chunk_start + @sizeOf(formats.Chunk) + 0x4 + usize(fs_info.files) * @sizeOf(FatEntry);
                const fat_chunk_size  = fat_chunk_end - fat_chunk_start;
                try file.write(
                    utils.toBytes(
                        formats.Chunk,
                        formats.Chunk {
                            .name = names.fat,
                            .size = toLittle(u32(fat_chunk_size)),
                        },
                    ));
                try file.write(toLittle(u16(fs_info.files)).bytes);
                try file.write([2]u8{ 0x00, 0x00 });
                const narc_fat_offset = try file.getPos();

                try file.seekTo(fat_chunk_end);
                const fnt_chunk_start = try file.getPos();
                const fnt_chunk_end   = common.@"align"(fnt_chunk_start + @sizeOf(formats.Chunk) + fs_info.fnt_sub_size, u32(4));
                const fnt_chunk_size  = fnt_chunk_end - fnt_chunk_start;
                try file.write(
                    utils.toBytes(
                        formats.Chunk,
                        formats.Chunk {
                            .name = names.fnt,
                            .size = toLittle(u32(fnt_chunk_size)),
                        },
                    ));
                const narc_fnt_offset = try file.getPos();
                const narc_img_base = fnt_chunk_end + @sizeOf(formats.Chunk);

                // We also skip writing file_data chunk header, till after we've written
                // the file system, as we don't know the size of the chunk otherwise.
                var fs_writer = FSWriter(NarcFile).init(file, u32(narc_img_base), 0);
                try fs_writer.writeFileSystem(narc_fs, u32(narc_fnt_offset), u32(narc_fat_offset), u32(narc_img_base), fs_info.folders);
                const file_offset = fs_writer.file_offset;

                const file_data_chunk_size = file_offset - fnt_chunk_end;
                try file.seekTo(fnt_chunk_end);
                try file.write(
                    utils.toBytes(
                        formats.Chunk,
                        formats.Chunk {
                            .name = names.file_data,
                            .size = toLittle(u32(file_data_chunk_size)),
                        },
                    ));

                const narc_file_size = u32(file_offset - start);
                try file.seekTo(start);
                try file.write(utils.toBytes(formats.Header, formats.Header.narc(narc_file_size)));

                return narc_file_size;
            },
        }
    } else if (FileType == NarcFile) {
        try file.write(fs_file.data);
        return u32(fs_file.data.len);
    } else {
        comptime unreachable;
    }
}
