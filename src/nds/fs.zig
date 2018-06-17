const std = @import("std");
const fun = @import("fun");
const common = @import("common.zig");
const formats = @import("formats.zig");
const little = @import("../little.zig");
const utils = @import("../utils/index.zig");

const generic = fun.generic;

const debug = std.debug;
const mem = std.mem;
const heap = std.heap;
const io = std.io;
const os = std.os;
const math = std.math;
const fmt = std.fmt;

const assert = debug.assert;

const toLittle = little.toLittle;
const Little = little.Little;

fn FileSystem(comptime FileType: type) type {
    return struct {
        const File = FileType;
        const Self = this;

        arena: std.heap.ArenaAllocator,
        root: *Folder,

        // TODO: When we have https://github.com/zig-lang/zig/issues/287, then we don't need to
        //       allocate the fs anymore.
        pub fn alloc(allocator: *mem.Allocator) !*Self {
            const res = try allocator.create(Self);
            res.arena = std.heap.ArenaAllocator.init(allocator);
            res.root = try res.createFolder(try mem.dupe(&res.arena.allocator, u8, ""));

            return res;
        }

        pub const Folder = struct {
            name: []u8,
            files: std.ArrayList(*FileType),
            folders: std.ArrayList(*Folder),
        };

        pub fn createFolder(fs: *Self, name: []u8) !*Folder {
            const node = try fs.arena.allocator.create(Folder);
            node.* = Folder{
                .name = name,
                .files = std.ArrayList(*FileType).init(&fs.arena.allocator),
                .folders = std.ArrayList(*Folder).init(&fs.arena.allocator),
            };

            return node;
        }

        pub fn createFile(fs: *Self, init_value: *const FileType) !*FileType {
            const node = try fs.arena.allocator.create(FileType);
            node.* = init_value.*;

            return node;
        }

        pub fn getFile(fs: *const Self, path: []const u8) ?*FileType {
            var splitIter = mem.split(path, "/");
            var curr_folder = fs.root;
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

        pub fn deinit(fs: *Self) void {
            fs.arena.deinit();
            fs.arena.child_allocator.destroy(fs);
        }
    };
}

pub const Narc = FileSystem(struct {
    name: []u8,
    data: []u8,
});

pub const Nitro = FileSystem(struct {
    name: []u8,
    @"type": Type,

    const Type = union(enum) {
        Binary: []u8,
        Narc: *Narc,
    };
});

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
        return FatEntry{
            .start = toLittle(offset),
            .end = toLittle(offset + size),
        };
    }

    fn getSize(entry: *const FatEntry) usize {
        return entry.end.get() - entry.start.get();
    }
};

pub fn readNitro(file: *os.File, allocator: *mem.Allocator, fnt: []const u8, fat: []const FatEntry) !*Nitro {
    return readHelper(Nitro, file, allocator, fnt, fat, 0);
}

pub fn readNarc(file: *os.File, allocator: *mem.Allocator, fnt: []const u8, fat: []const FatEntry, img_base: usize) !*Narc {
    return readHelper(Narc, file, allocator, fnt, fat, img_base);
}

fn readHelper(comptime Fs: type, file: *os.File, allocator: *mem.Allocator, fnt: []const u8, fat: []const FatEntry, img_base: usize) !*Fs {
    const fnt_main_table = blk: {
        const fnt_mains = generic.widenTrim(fnt, FntMainEntry);
        const first = generic.at(fnt_mains, 0) catch return error.InvalidFnt;
        const res = generic.slice(fnt_mains, 0, first.parent_id.get()) catch return error.InvalidFnt;
        if (res.len > 4096) return error.InvalidFnt;

        break :blk res;
    };

    const State = struct {
        folder: *Fs.Folder,
        file_id: u16,
        fnt_sub_table: []const u8,
    };

    var stack = std.ArrayList(State).init(allocator);
    defer stack.deinit();

    const fs = try Fs.alloc(allocator);
    errdefer fs.deinit();

    const fnt_first = fnt_main_table[0];
    try stack.append(State{
        .folder = fs.root,
        .file_id = fnt_first.first_file_id_in_subtable.get(),
        .fnt_sub_table = generic.slice(fnt, fnt_first.offset_to_subtable.get(), fnt.len) catch return error.InvalidFnt,
    });

    while (stack.popOrNull()) |state| {
        const folder = state.folder;
        const file_id = state.file_id;
        const fnt_sub_table = state.fnt_sub_table;

        var mem_stream = utils.stream.MemInStream.init(fnt_sub_table);
        const stream = &mem_stream.stream;

        const Kind = enum(u8) {
            File = 0x00,
            Folder = 0x80,
        };
        const type_length = try utils.stream.read(stream, u8);

        if (type_length == 0x80) return error.InvalidSubTableTypeLength;
        if (type_length == 0x00) continue;

        const lenght = type_length & 0x7F;
        const kind = Kind((type_length & 0x80));
        assert(kind == Kind.File or kind == Kind.Folder);

        const name = try utils.stream.allocRead(stream, &fs.arena.allocator, u8, lenght);
        switch (kind) {
            Kind.File => {
                const fat_entry = generic.at(fat, file_id) catch return error.InvalidFileId;
                try folder.files.append(switch (Fs) {
                    Nitro => try readNitroFile(fs, file, allocator, fat_entry, img_base, name),
                    Narc => try readNarcFile(fs, file, allocator, fat_entry, img_base, name),
                    else => comptime unreachable,
                });

                stack.append(State{
                    .folder = folder,
                    .file_id = file_id + 1,
                    .fnt_sub_table = mem_stream.memory,
                }) catch unreachable;
            },
            Kind.Folder => {
                const id = try utils.stream.read(stream, Little(u16));
                if (id.get() < 0xF001 or id.get() > 0xFFFF) return error.InvalidSubDirectoryId;

                const fnt_entry = generic.at(fnt_main_table, id.get() & 0x0FFF) catch return error.InvalidSubDirectoryId;
                const sub_folder = try fs.createFolder(name);

                try folder.folders.append(sub_folder);

                stack.append(State{
                    .folder = folder,
                    .file_id = file_id,
                    .fnt_sub_table = mem_stream.memory,
                }) catch unreachable;
                try stack.append(State{
                    .folder = sub_folder,
                    .file_id = fnt_entry.first_file_id_in_subtable.get(),
                    .fnt_sub_table = generic.slice(fnt, fnt_entry.offset_to_subtable.get(), fnt.len) catch return error.InvalidFnt,
                });
            },
        }
    }

    return fs;
}

pub fn readNitroFile(fs: *Nitro, file: *os.File, tmp_allocator: *mem.Allocator, fat_entry: *const FatEntry, img_base: usize, name: []u8) !*Nitro.File {
    var file_in_stream = io.FileInStream.init(file);

    narc_read: {
        const names = formats.Chunk.names;

        try file.seekTo(fat_entry.start.get() + img_base);
        const file_start = try file.getPos();

        var buffered_in_stream = io.BufferedInStream(io.FileInStream.Error).init(&file_in_stream.stream);
        const stream = &buffered_in_stream.stream;

        const header = utils.stream.read(stream, formats.Header) catch break :narc_read;
        if (!mem.eql(u8, header.chunk_name, names.narc))
            break :narc_read;
        if (header.byte_order.get() != 0xFFFE)
            break :narc_read;
        if (header.chunk_size.get() != 0x0010)
            break :narc_read;
        if (header.following_chunks.get() != 0x0003)
            break :narc_read;

        // If we have a valid narc header, then we assume we are reading a narc
        // file. All error from here, are therefore bubbled up.
        const fat_header = try utils.stream.read(stream, formats.FatChunk);
        const fat_size = math.sub(u32, fat_header.header.size.get(), @sizeOf(formats.FatChunk)) catch return error.InvalidChunkSize;

        if (!mem.eql(u8, fat_header.header.name, names.fat))
            return error.InvalidChunkName;
        if (fat_size % @sizeOf(FatEntry) != 0)
            return error.InvalidChunkSize;
        if (fat_size / @sizeOf(FatEntry) != fat_header.file_count.get())
            return error.InvalidChunkSize;

        const fat = try utils.stream.allocRead(stream, tmp_allocator, FatEntry, fat_header.file_count.get());
        defer tmp_allocator.free(fat);

        const fnt_header = try utils.stream.read(stream, formats.Chunk);
        const fnt_size = math.sub(u32, fnt_header.size.get(), @sizeOf(formats.Chunk)) catch return error.InvalidChunkSize;

        if (!mem.eql(u8, fnt_header.name, names.fnt)) return error.InvalidChunkName;

        const fnt = try utils.stream.allocRead(stream, tmp_allocator, u8, fnt_size);
        defer tmp_allocator.free(fnt);

        const fnt_mains = generic.widenTrim(fnt, FntMainEntry);
        const first_fnt = generic.at(fnt_mains, 0) catch return error.InvalidChunkSize;

        const file_data_header = try utils.stream.read(stream, formats.Chunk);
        if (!mem.eql(u8, file_data_header.name, names.file_data))
            return error.InvalidChunkName;

        // Since we are using buffered input, be have to seek back to the narc_img_base,
        // when we start reading the file system
        const narc_img_base = file_start + @sizeOf(formats.Header) + fat_header.header.size.get() + fnt_header.size.get() + @sizeOf(formats.Chunk);
        try file.seekTo(narc_img_base);

        // If the first_fnt's offset points into it self, then there doesn't exist an
        // fnt sub table and files don't have names. We therefore can't use our normal
        // read function, as it relies on the fnt sub table to build the file system.
        if (first_fnt.offset_to_subtable.get() < @sizeOf(FntMainEntry)) {
            const sub_fs = try Narc.alloc(&fs.arena.allocator);
            const files = &sub_fs.root.files;
            try files.ensureCapacity(fat_header.file_count.get());

            for (fat) |entry, i| {
                const sub_file_name = try fmt.allocPrint(&sub_fs.arena.allocator, "{}", i);
                const sub_file = try readNarcFile(sub_fs, file, tmp_allocator, entry, narc_img_base, sub_file_name);
                files.append(sub_file) catch unreachable;
            }

            return fs.createFile(Nitro.File{
                .name = name,
                .@"type" = Nitro.File.Type{ .Narc = sub_fs },
            });
        } else {
            const sub_fs = try readNarc(file, &fs.arena.allocator, fnt, fat, narc_img_base);
            return fs.createFile(Nitro.File{
                .name = name,
                .@"type" = Nitro.File.Type{ .Narc = sub_fs },
            });
        }
    }

    try file.seekTo(fat_entry.start.get() + img_base);
    const data = try utils.stream.allocRead(&file_in_stream.stream, &fs.arena.allocator, u8, fat_entry.getSize());
    return fs.createFile(Nitro.File{
        .name = name,
        .@"type" = Nitro.File.Type{ .Binary = data },
    });
}

pub fn readNarcFile(fs: *Narc, file: *os.File, tmp_allocator: *mem.Allocator, fat_entry: *const FatEntry, img_base: usize, name: []u8) !*Narc.File {
    var file_in_stream = io.FileInStream.init(file);
    const stream = &file_in_stream.stream;

    try file.seekTo(fat_entry.start.get() + img_base);
    const data = try utils.stream.allocRead(&file_in_stream.stream, &fs.arena.allocator, u8, fat_entry.getSize());
    return fs.createFile(Narc.File{
        .name = name,
        .data = data,
    });
}

pub fn FntAndFiles(comptime FileType: type) type {
    return struct {
        files: []*FileType,
        main_fnt: []FntMainEntry,
        sub_fnt: []const u8,
    };
}

pub fn getFntAndFiles(comptime Fs: type, fs: *const Fs, allocator: *mem.Allocator) !FntAndFiles(Fs.File) {
    comptime assert(Fs == Nitro or Fs == Narc);

    var files = std.ArrayList(*Fs.File).init(allocator);
    var main_fnt = std.ArrayList(FntMainEntry).init(allocator);
    var sub_fnt = try std.Buffer.initSize(allocator, 0);

    const State = struct {
        folder: *Fs.Folder,
        parent_id: u16,
    };
    var states = std.ArrayList(State).init(allocator);
    var current_state: u16 = 0;

    defer states.deinit();
    try states.append(State{
        .folder = fs.root,
        .parent_id = undefined, // We don't know the parent_id of root yet. Filling it out later
    });

    while (current_state < states.len) : (current_state += 1) {
        const state = states.toSliceConst()[current_state];

        try main_fnt.append(FntMainEntry{
            .offset_to_subtable = toLittle(u32(sub_fnt.len())),
            .first_file_id_in_subtable = toLittle(u16(files.len)),
            .parent_id = toLittle(u16(state.parent_id)),
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

            try states.append(State{
                .folder = folder,
                .parent_id = current_state + 0xF000,
            });
        }

        try sub_fnt.appendByte(0x00);
    }

    // Filling in root parent id!
    main_fnt.items[0].parent_id = toLittle(u16(main_fnt.len));
    for (main_fnt.toSlice()) |*entry| {
        entry.offset_to_subtable = toLittle(u32(main_fnt.len * @sizeOf(FntMainEntry) + entry.offset_to_subtable.get()));
    }

    return FntAndFiles(Fs.File){
        .files = files.toOwnedSlice(),
        .main_fnt = main_fnt.toOwnedSlice(),
        .sub_fnt = sub_fnt.list.toOwnedSlice(),
    };
}

pub fn writeNitroFile(file: *os.File, allocator: *mem.Allocator, fs_file: *const Nitro.File) !void {
    switch (fs_file.@"type") {
        Nitro.File.Type.Binary => |data| {
            try file.write(data);
        },
        Nitro.File.Type.Narc => |narc_fs| {
            const fntAndFiles = try getFntAndFiles(Narc, narc_fs, allocator);
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
            const fnt_end = fnt_start + @sizeOf(formats.Chunk) + sub_fnt.len + main_fnt.len * @sizeOf(FntMainEntry);
            const file_image_start = common.@"align"(fnt_end, u32(0x4));
            const narc_img_base = file_image_start + @sizeOf(formats.Chunk);
            const file_end = blk: {
                var res = narc_img_base;
                for (files) |f| {
                    res += f.data.len;
                }

                break :blk res;
            };

            var file_out_stream = io.FileOutStream.init(file);
            var buffered_out_stream = io.BufferedOutStream(io.FileOutStream.Error).init(&file_out_stream.stream);

            const stream = &buffered_out_stream.stream;

            try stream.write(utils.toBytes(formats.Header, formats.Header.narc(u32(file_end - file_start))));
            try stream.write(utils.toBytes(formats.FatChunk, formats.FatChunk{
                .header = formats.Chunk{
                    .name = formats.Chunk.names.fat,
                    .size = toLittle(u32(fnt_start - fat_start)),
                },
                .file_count = toLittle(u16(files.len)),
                .reserved = toLittle(u16(0x00)),
            }));

            var start = u32(0);
            for (files) |f| {
                const fat_entry = FatEntry.init(start, u32(f.data.len));
                try stream.write(utils.toBytes(FatEntry, fat_entry));
                start += u32(f.data.len);
            }

            try stream.write(utils.toBytes(formats.Chunk, formats.Chunk{
                .name = formats.Chunk.names.fnt,
                .size = toLittle(u32(file_image_start - fnt_start)),
            }));
            try stream.write(([]u8)(main_fnt));
            try stream.write(sub_fnt);
            try stream.writeByteNTimes(0xFF, file_image_start - fnt_end);

            try stream.write(utils.toBytes(formats.Chunk, formats.Chunk{
                .name = formats.Chunk.names.file_data,
                .size = toLittle(u32(file_end - file_image_start)),
            }));
            for (files) |f| {
                try stream.write(f.data);
            }

            try buffered_out_stream.flush();
        },
    }
}

fn fsEqual(allocator: &mem.Allocator, comptime Fs: type, fs1: &const Fs, fs2: &const Fs) bool {
    comptime assert(Fs == Nitro or Fs == Narc);

    const FolderPair = struct {
        f1: Fs.Folder,
        f2: Fs.Folder,
    };

    var folders_to_compare = std.ArrayList(FolderPair).init(allocator);
    defer folders_to_compare.deinit();
    try folders_to_compare.append(FolderPair {
        .f1 = fs1.root,
        .f2 = fs2.root,
    });

    while (folders_to_compare.popOrNull()) |pair| {
        for (pair.f1.folders) |f1| {
            for (pair.f2.folders) |f2| {
                if (mem.eql(u8, f1.name, f2.name)) {
                    folders_to_compare.append(FolderPair {
                        .f1 = f1,
                        .f2 = f2,
                    });
                    break;
                }
            } else {
                return false;
            }
        }

        for (pair.f1.files) |f1| {
            for (pair.f2.files) |f2| {
                if (mem.eql(u8, f1.name, f2.name)) {
                    switch (Fs) {
                        Nitro => {
                            switch (f1.@"type") {
                                Nitro.File.Binary => {
                                    if (f2.@"type" != Nitro.File.Binary)
                                        return false;
                                    if (!mem.eql(u8, f1.@"type".Binary, f2.@"type".Binary))
                                        return false;
                                },
                                Nitro.File.Narc => {
                                    if (f2.@"type" != Nitro.File.Narc)
                                        return false;
                                    if (!fsEqual(allocator, Narc, f1.@"type".Narc, f2.@"type".Narc))
                                        return false;
                                }
                            }
                        },
                        Narc => {
                            if (!mem.eql(u8, f1.data, f2.data))
                                return false;
                        },
                        else => comptime unreachable,
                    }
                    break;
                }
            } else {
                return false;
            }
        }
    }

    return true;
}

test "nds.fs: Nitro.File read/write" {
    const fs = Nitro {
        .folders = std.ArrayList(Nitro.Folder)
    };
}
