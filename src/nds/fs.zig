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
const fmt   = std.fmt;

const assert = debug.assert;

const toLittle = little.toLittle;
const Little   = little.Little;

pub fn Tree(comptime FileType: type) type {
    return struct {
        const Self = this;

        arena: std.heap.ArenaAllocator,
        root: &Folder,

        // TODO: When we have https://github.com/zig-lang/zig/issues/287, then we don't need to
        //       allocate the tree anymore.
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
            const fat_chunk = try utils.file.read(file, formats.FatChunk);
            const fat_size = math.sub(u32, fat_chunk.header.size.get(), @sizeOf(formats.FatChunk)) catch return error.InvalidChunkSize;

            if (!mem.eql(u8, fat_chunk.header.name, names.fat)) return error.InvalidChunkName;
            if (fat_size % @sizeOf(FatEntry) != 0) return error.InvalidChunkSize;
            if (fat_size / @sizeOf(FatEntry) != fat_chunk.file_count.get()) return error.InvalidChunkSize;

            const fat = try utils.file.allocRead(file, tmp_allocator, FatEntry, fat_chunk.file_count.get());
            defer tmp_allocator.free(fat);

            const fnt_header = try utils.file.read(file, formats.Chunk);
            const fnt_size = math.sub(u32, fnt_header.size.get(), @sizeOf(formats.Chunk)) catch return error.InvalidChunkSize;

            if (!mem.eql(u8, fnt_header.name, names.fnt)) return error.InvalidChunkName;

            const fnt = try utils.file.allocRead(file, tmp_allocator, u8, fnt_size);
            defer tmp_allocator.free(fnt);

            const fnt_end = try file.getPos();
            debug.assert(fnt_end % 4 == 0);

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
                try files.ensureCapacity(fat_chunk.file_count.get());

                for (fat) |entry, i| {
                    const sub_file_name = try fmt.allocPrint(&sub_tree.arena.allocator, "{}", i);
                    const sub_file = try readFile(NarcFile, sub_tree, file, tmp_allocator, entry, narc_img_base, sub_file_name);
                    files.append(sub_file) catch unreachable;
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

pub fn FntAndFiles(comptime FileType: type) type {
    return struct {
        files: []&FileType,
        main_fnt: []FntMainEntry,
        sub_fnt: []const u8,
    };
}

pub fn getFntAndFiles(comptime FileType: type, tree: &Tree(FileType), allocator: &mem.Allocator) !FntAndFiles(FileType) {
    var files = std.ArrayList(&FileType).init(allocator);
    var main_fnt = std.ArrayList(FntMainEntry).init(allocator);
    var sub_fnt = try std.Buffer.initSize(allocator, 0);

    const State = struct {
        folder: &Tree(FileType).Folder,
        parent_id: u16,
    };
    var states = std.ArrayList(State).init(allocator);
    var current_state : u16 = 0;

    defer states.deinit();
    try states.append(State {
        .folder = tree.root,
        .parent_id = undefined, // We don't know the parent_id of root yet. Filling it out later
    });

    while (current_state < states.len) : (current_state += 1) {
        const state = states.toSliceConst()[current_state];

        try main_fnt.append(FntMainEntry {
            .offset_to_subtable        = toLittle(u32(sub_fnt.len())),
            .first_file_id_in_subtable = toLittle(u16(files.len)),
            .parent_id                 = toLittle(u16(state.parent_id)),
        });

        for (state.folder.files.toSliceConst()) |f| {
            debug.assert(f.name.len != 0x00); // TODO: We should probably return an error here instead of asserting
            try sub_fnt.appendByte(u8(f.name.len));
            try sub_fnt.append(f.name);
            try files.append(f);
        }

        for (state.folder.folders.toSliceConst()) |folder| {
            try sub_fnt.appendByte(u8(folder.name.len + 0x80));
            try sub_fnt.append(folder.name);
            try sub_fnt.append(toLittle(u16(states.len + 0xF000)).bytes);

            try states.append(State {
                .folder = folder,
                .parent_id = current_state + 0xF000,
            });
        }

        try sub_fnt.appendByte(0x00);
    }

    main_fnt.items[0].parent_id = toLittle(u16(main_fnt.len));
    for (main_fnt.toSlice()) |*entry| {
        entry.offset_to_subtable = toLittle(u32(main_fnt.len * @sizeOf(FntMainEntry) + entry.offset_to_subtable.get()));
    }

    return FntAndFiles(FileType) {
        .files = files.toOwnedSlice(),
        .main_fnt = main_fnt.toOwnedSlice(),
        .sub_fnt = sub_fnt.list.toOwnedSlice(),
    };
}

pub fn writeFile(comptime FileType: type, file: &os.File, allocator: &mem.Allocator, fs_file: &const FileType) !void {
    if (FileType == NitroFile) {
        switch (fs_file.@"type") {
            NitroFile.Type.Binary => |data| {
                try file.write(data);
            },
            NitroFile.Type.Narc => |narc_fs| {
                const fntAndFiles = try getFntAndFiles(NarcFile, narc_fs, allocator);
                const files = fntAndFiles.files;
                const main_fnt = fntAndFiles.main_fnt;
                const sub_fnt = fntAndFiles.sub_fnt;
                defer {
                    allocator.free(files);
                    allocator.free(main_fnt);
                    allocator.free(sub_fnt);
                }

                const file_start = try file.getPos();
                const fat_start = file_start + @sizeOf(formats.Header);
                const fnt_start = fat_start + @sizeOf(formats.FatChunk) + files.len * @sizeOf(FatEntry);
                const file_image_start = common.@"align"(fnt_start + @sizeOf(formats.Chunk) + sub_fnt.len + main_fnt.len * @sizeOf(FntMainEntry), u32(0x4));
                const narc_img_base = file_image_start + @sizeOf(formats.Chunk);
                const file_end = blk: {
                    var res = narc_img_base;
                    for (files) |f| {
                        res += f.data.len;
                    }

                    break :blk res;
                };

                try file.write(utils.toBytes(formats.Header, formats.Header.narc(u32(file_end - file_start))));
                assert(fat_start == try file.getPos());
                try file.write(
                    utils.toBytes(formats.FatChunk, formats.FatChunk {
                        .header = formats.Chunk {
                            .name = formats.Chunk.names.fat,
                            .size = toLittle(u32(fnt_start - fat_start))
                        },
                        .file_count = toLittle(u16(files.len)),
                        .reserved = toLittle(u16(0x00)),
                    })
                );

                var start = u32(0);
                for (files) |f| {
                    const fat_entry = FatEntry.init(start, u32(f.data.len));
                    try file.write(utils.toBytes(FatEntry, fat_entry));
                    start += u32(f.data.len);
                }

                assert(fnt_start == try file.getPos());
                try file.write(
                    utils.toBytes(formats.Chunk, formats.Chunk {
                        .name = formats.Chunk.names.fnt,
                        .size = toLittle(u32(file_image_start - fnt_start)),
                    })
                );
                try file.write(([]u8)(main_fnt));
                try file.write(sub_fnt);
                try file.seekTo(common.@"align"(try file.getPos(), 4));

                assert(file_image_start == try file.getPos());
                try file.write(
                    utils.toBytes(formats.Chunk, formats.Chunk {
                        .name = formats.Chunk.names.file_data,
                        .size = toLittle(u32(file_end - file_image_start)),
                    })
                );
                assert(narc_img_base == try file.getPos());
                for (files) |f| {
                    try writeFile(NarcFile, file, allocator, f);
                }

                assert(file_end == try file.getPos());
            },
        }
    } else if (FileType == NarcFile) {
        try file.write(fs_file.data);
    } else {
        comptime unreachable;
    }
}
