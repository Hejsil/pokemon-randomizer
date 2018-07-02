const std = @import("std");

// TODO: We can't have packages in tests, so we have to import the fun-with-zig lib manually
const fun = @import("../../lib/fun-with-zig/src/index.zig");
const common = @import("common.zig");
const formats = @import("formats.zig");
const int = @import("../int.zig");
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

const lu16 = int.lu16;
const lu32 = int.lu32;

fn Folder(comptime TFile: type) type {
    return struct {
        const Self = this;
        const IndexMap = std.HashMap([]const u8, usize, mem.hash_slice_u8, mem.eql_slice_u8);
        const Nodes = std.ArrayList(Node);

        pub const File = TFile;
        pub const Node = struct {
            name: []const u8,
            kind: Kind,

            const Kind = union(enum) {
                File: *File,
                Folder: *Self,
            };
        };

        parent: ?*Self,
        indexs: IndexMap,
        nodes: Nodes,

        pub fn create(a: *mem.Allocator) !*Self {
            return try a.create(Self.init(a));
        }

        pub fn destroy(folder: *Self) void {
            folder.deinit();
            folder.allocator().destroy(folder);
        }

        pub fn init(a: *mem.Allocator) Self {
            return Self{
                .parent = null,
                .indexs = IndexMap.init(a),
                .nodes = Nodes.init(a),
            };
        }

        pub fn deinit(folder: *Self) void {
            var curr: ?*Self = folder;
            while (@ptrToInt(curr) != @ptrToInt(folder.parent)) {
                const f = curr.?;
                const a = f.allocator();
                if (f.nodes.popOrNull()) |node| {
                    switch (node.kind) {
                        Node.Kind.File => |file| {
                            file.deinit();
                            a.destroy(file);
                        },
                        Node.Kind.Folder => |sub_folder| curr = sub_folder,
                    }
                } else {
                    var it = f.indexs.iterator();
                    while (it.next()) |entry|
                        a.free(entry.key);

                    f.indexs.deinit();
                    f.nodes.deinit();
                    curr = f.parent;
                    a.destroy(f);
                    f.* = undefined;
                }
            }
        }

        pub fn allocator(folder: Self) *mem.Allocator {
            return folder.nodes.allocator;
        }

        pub fn root(folder: *Self) *Self {
            var res = folder;
            while (res.parent) |next|
                res = next;

            return res;
        }

        pub fn getFolder(folder: *Self, path: []const u8) ?*Self {
            const node = folder.get(path) orelse return null;
            switch (node) {
                Node.Kind.File => return null,
                Node.Kind.Folder => |res| return res,
            }
        }

        pub fn getFile(folder: *Self, path: []const u8) ?*File {
            const node = folder.get(path) orelse return null;
            switch (node) {
                Node.Kind.File => |res| return res,
                Node.Kind.Folder => return null,
            }
        }

        fn get(folder: *Self, path: []const u8) ?Node.Kind {
            var res = Node.Kind{ .Folder = folder.startFolder(path) };
            var it = mem.split(path, "/");
            while (it.next()) |name| {
                switch (res) {
                    Node.Kind.File => return null,
                    Node.Kind.Folder => |tmp| {
                        const entry = tmp.indexs.get(name) orelse return null;
                        const index = entry.value;
                        res = tmp.nodes.toSlice()[index].kind;
                    },
                }
            }

            return res;
        }

        pub fn exists(folder: *Self, name: []const u8) bool {
            return folder.indexs.contains(name);
        }

        pub fn createFile(folder: *Self, name: []const u8, file: File) !*File {
            const res = try folder.createNode(name);
            res.kind = Node.Kind{ .File = try folder.allocator().create(file) };

            return res.kind.File;
        }

        pub fn createFolder(folder: *Self, name: []const u8) !*Self {
            const res = try folder.createNode(name);
            const fold = try Self.create(folder.allocator());
            fold.parent = folder;
            res.kind = Node.Kind{ .Folder = fold };

            return res.kind.Folder;
        }

        fn createNode(folder: *Self, name: []const u8) !*Node {
            if (folder.exists(name))
                return error.FileExists;

            const a = folder.allocator();
            const index = folder.nodes.len;
            const owned_name = try mem.dupe(a, u8, name);
            errdefer a.free(owned_name);

            const res = try folder.nodes.addOne();
            errdefer _ = folder.nodes.pop();
            _ = try folder.indexs.put(name, index);

            res.name = owned_name;
            return res;
        }

        fn startFolder(folder: *Self, path: []const u8) *Self {
            if (path.len == 0 or path[0] != '/')
                return folder;

            return folder.root();
        }
    };
}

pub const Narc = Folder(struct {
    const Self = this;

    allocator: *mem.Allocator,
    data: []u8,

    pub fn deinit(file: *Self) void {
        file.allocator.free(file.data);
        file.* = undefined;
    }
});

pub const Nitro = Folder(union(enum) {
    const Self = this;

    Binary: Binary,
    Narc: *Narc,

    pub fn deinit(file: *Self) void {
        switch (file.*) {
            @TagType(Self).Binary => |bin| bin.allocator.free(bin.data),
            @TagType(Self).Narc => |narc| narc.destroy(),
        }

        file.* = undefined;
    }

    const Binary = struct {
        allocator: *mem.Allocator,
        data: []u8,
    };
});

pub const FntMainEntry = packed struct {
    offset_to_subtable: lu32,
    first_file_id_in_subtable: lu16,

    // For the first entry in main-table, the parent id is actually,
    // the total number of directories (See FNT Directory Main-Table):
    // http://problemkaputt.de/gbatek.htm#dscartridgenitroromandnitroarcfilesystems
    parent_id: lu16,
};

pub const FatEntry = packed struct {
    start: lu32,
    end: lu32,

    fn init(offset: u32, size: u32) FatEntry {
        return FatEntry{
            .start = lu32.init(offset),
            .end = lu32.init(offset + size),
        };
    }

    fn getSize(entry: FatEntry) usize {
        return entry.end.value() - entry.start.value();
    }
};

pub fn readNitro(file: *os.File, allocator: *mem.Allocator, fnt: []const u8, fat: []const FatEntry) !*Nitro {
    return readHelper(Nitro, file, allocator, fnt, fat, 0);
}

pub fn readNarc(file: *os.File, allocator: *mem.Allocator, fnt: []const u8, fat: []const FatEntry, img_base: usize) !*Narc {
    return readHelper(Narc, file, allocator, fnt, fat, img_base);
}

fn readHelper(comptime F: type, file: *os.File, allocator: *mem.Allocator, fnt: []const u8, fat: []const FatEntry, img_base: usize) !*F {
    const fnt_main_table = blk: {
        const fnt_mains = generic.bytesToSliceTrim(FntMainEntry, fnt);
        const first = generic.at(fnt_mains, 0) catch return error.InvalidFnt;
        const res = generic.slice(fnt_mains, 0, first.parent_id.value()) catch return error.InvalidFnt;
        if (res.len > 4096) return error.InvalidFnt;

        break :blk res;
    };

    const State = struct {
        folder: *F,
        file_id: u16,
        fnt_sub_table: []const u8,
    };

    var stack = std.ArrayList(State).init(allocator);
    defer stack.deinit();

    const root = try F.create(allocator);
    errdefer root.destroy();

    const fnt_first = fnt_main_table[0];
    try stack.append(State{
        .folder = root,
        .file_id = fnt_first.first_file_id_in_subtable.value(),
        .fnt_sub_table = generic.slice(fnt, fnt_first.offset_to_subtable.value(), fnt.len) catch return error.InvalidFnt,
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

        if (type_length == 0x80)
            return error.InvalidSubTableTypeLength;
        if (type_length == 0x00)
            continue;

        const lenght = type_length & 0x7F;
        const kind = @intToEnum(Kind, type_length & 0x80);
        assert(kind == Kind.File or kind == Kind.Folder);

        const name = try utils.stream.allocRead(stream, allocator, u8, lenght);
        defer allocator.free(name);
        switch (kind) {
            Kind.File => {
                const fat_entry = generic.at(fat, file_id) catch return error.InvalidFileId;
                _ = try folder.createFile(name, switch (F) {
                    Nitro => try readNitroFile(file, allocator, fat_entry.*, img_base),
                    Narc => try readNarcFile(file, allocator, fat_entry.*, img_base),
                    else => comptime unreachable,
                });

                stack.append(State{
                    .folder = folder,
                    .file_id = file_id + 1,
                    .fnt_sub_table = mem_stream.memory,
                }) catch unreachable;
            },
            Kind.Folder => {
                const id = try utils.stream.read(stream, lu16);
                if (id.value() < 0xF001 or id.value() > 0xFFFF)
                    return error.InvalidSubDirectoryId;

                const fnt_entry = generic.at(fnt_main_table, id.value() & 0x0FFF) catch return error.InvalidSubDirectoryId;
                const sub_folder = try folder.createFolder(name);

                stack.append(State{
                    .folder = folder,
                    .file_id = file_id,
                    .fnt_sub_table = mem_stream.memory,
                }) catch unreachable;
                try stack.append(State{
                    .folder = sub_folder,
                    .file_id = fnt_entry.first_file_id_in_subtable.value(),
                    .fnt_sub_table = generic.slice(fnt, fnt_entry.offset_to_subtable.value(), fnt.len) catch return error.InvalidFnt,
                });
            },
        }
    }

    return root;
}

pub fn readNitroFile(file: *os.File, allocator: *mem.Allocator, fat_entry: FatEntry, img_base: usize) !Nitro.File {
    var file_in_stream = io.FileInStream.init(file);

    narc_read: {
        const names = formats.Chunk.names;

        try file.seekTo(fat_entry.start.value() + img_base);
        const file_start = try file.getPos();

        var buffered_in_stream = io.BufferedInStream(io.FileInStream.Error).init(&file_in_stream.stream);
        const stream = &buffered_in_stream.stream;

        const header = utils.stream.read(stream, formats.Header) catch break :narc_read;
        if (!mem.eql(u8, header.chunk_name, names.narc))
            break :narc_read;
        if (header.byte_order.value() != 0xFFFE)
            break :narc_read;
        if (header.chunk_size.value() != 0x0010)
            break :narc_read;
        if (header.following_chunks.value() != 0x0003)
            break :narc_read;

        // If we have a valid narc header, then we assume we are reading a narc
        // file. All error from here, are therefore bubbled up.
        const fat_header = try utils.stream.read(stream, formats.FatChunk);
        const fat_size = math.sub(u32, fat_header.header.size.value(), @sizeOf(formats.FatChunk)) catch return error.InvalidChunkSize;

        if (!mem.eql(u8, fat_header.header.name, names.fat))
            return error.InvalidChunkName;
        if (fat_size % @sizeOf(FatEntry) != 0)
            return error.InvalidChunkSize;
        if (fat_size / @sizeOf(FatEntry) != fat_header.file_count.value())
            return error.InvalidChunkSize;

        const fat = try utils.stream.allocRead(stream, allocator, FatEntry, fat_header.file_count.value());
        defer allocator.free(fat);

        const fnt_header = try utils.stream.read(stream, formats.Chunk);
        const fnt_size = math.sub(u32, fnt_header.size.value(), @sizeOf(formats.Chunk)) catch return error.InvalidChunkSize;

        if (!mem.eql(u8, fnt_header.name, names.fnt)) return error.InvalidChunkName;

        const fnt = try utils.stream.allocRead(stream, allocator, u8, fnt_size);
        defer allocator.free(fnt);

        const fnt_mains = generic.bytesToSliceTrim(FntMainEntry, fnt);
        const first_fnt = generic.at(fnt_mains, 0) catch return error.InvalidChunkSize;

        const file_data_header = try utils.stream.read(stream, formats.Chunk);
        if (!mem.eql(u8, file_data_header.name, names.file_data))
            return error.InvalidChunkName;

        // Since we are using buffered input, be have to seek back to the narc_img_base,
        // when we start reading the file system
        const narc_img_base = file_start + @sizeOf(formats.Header) + fat_header.header.size.value() + fnt_header.size.value() + @sizeOf(formats.Chunk);
        try file.seekTo(narc_img_base);

        // If the first_fnt's offset points into it self, then there doesn't exist an
        // fnt sub table and files don't have names. We therefore can't use our normal
        // read function, as it relies on the fnt sub table to build the file system.
        if (first_fnt.offset_to_subtable.value() < @sizeOf(FntMainEntry)) {
            const narc = try Narc.create(allocator);

            for (fat) |entry, i| {
                var buf: [10]u8 = undefined;
                const sub_file_name = try fmt.bufPrint(buf[0..], "{}", i);
                const sub_file = try readNarcFile(file, allocator, entry, narc_img_base);
                _ = try narc.createFile(sub_file_name, sub_file);
            }

            return Nitro.File{ .Narc = narc };
        } else {
            return Nitro.File{ .Narc = try readNarc(file, allocator, fnt, fat, narc_img_base) };
        }
    }

    try file.seekTo(fat_entry.start.value() + img_base);
    const data = try utils.stream.allocRead(&file_in_stream.stream, allocator, u8, fat_entry.getSize());
    return Nitro.File{
        .Binary = Nitro.File.Binary{
            .allocator = allocator,
            .data = data,
        },
    };
}

pub fn readNarcFile(file: *os.File, allocator: *mem.Allocator, fat_entry: FatEntry, img_base: usize) !Narc.File {
    var file_in_stream = io.FileInStream.init(file);
    const stream = &file_in_stream.stream;

    try file.seekTo(fat_entry.start.value() + img_base);
    const data = try utils.stream.allocRead(&file_in_stream.stream, allocator, u8, fat_entry.getSize());
    return Narc.File{
        .allocator = allocator,
        .data = data,
    };
}

pub fn FntAndFiles(comptime FileType: type) type {
    return struct {
        files: []*FileType,
        main_fnt: []FntMainEntry,
        sub_fnt: []const u8,
    };
}

pub fn getFntAndFiles(comptime F: type, root: *F, allocator: *mem.Allocator) !FntAndFiles(F.File) {
    comptime assert(F == Nitro or F == Narc);

    var files = std.ArrayList(*F.File).init(allocator);
    var main_fnt = std.ArrayList(FntMainEntry).init(allocator);
    var sub_fnt = try std.Buffer.initSize(allocator, 0);

    const State = struct {
        folder: *F,
        parent_id: u16,
    };
    var states = std.ArrayList(State).init(allocator);
    var current_state: u16 = 0;

    defer states.deinit();
    try states.append(State{
        .folder = root,
        .parent_id = undefined, // We don't know the parent_id of root yet. Filling it out later
    });

    while (current_state < states.len) : (current_state += 1) {
        const state = states.toSliceConst()[current_state];

        try main_fnt.append(FntMainEntry{
            .offset_to_subtable = lu32.init(@intCast(u32, sub_fnt.len())),
            .first_file_id_in_subtable = lu16.init(@intCast(u16, files.len)),
            .parent_id = lu16.init(state.parent_id),
        });

        for (state.folder.nodes.toSliceConst()) |node| {
            switch (node.kind) {
                F.Node.Kind.Folder => |folder| {
                    try sub_fnt.appendByte(@intCast(u8, node.name.len + 0x80));
                    try sub_fnt.append(node.name);
                    try sub_fnt.append(lu16.init(@intCast(u16, states.len + 0xF000)).bytes);

                    try states.append(State{
                        .folder = folder,
                        .parent_id = current_state + 0xF000,
                    });
                },
                F.Node.Kind.File => |f| {
                    debug.assert(node.name.len != 0x00); // TODO: We should probably return an error here instead of asserting
                    try sub_fnt.appendByte(@intCast(u8, node.name.len));
                    try sub_fnt.append(node.name);
                    try files.append(f);
                },
            }
        }

        try sub_fnt.appendByte(0x00);
    }

    // Filling in root parent id!
    main_fnt.items[0].parent_id = lu16.init(@intCast(u16, main_fnt.len));
    for (main_fnt.toSlice()) |*entry| {
        entry.offset_to_subtable = lu32.init(@intCast(u32, main_fnt.len * @sizeOf(FntMainEntry) + entry.offset_to_subtable.value()));
    }

    return FntAndFiles(F.File){
        .files = files.toOwnedSlice(),
        .main_fnt = main_fnt.toOwnedSlice(),
        .sub_fnt = sub_fnt.list.toOwnedSlice(),
    };
}

pub fn writeNitroFile(file: *os.File, allocator: *mem.Allocator, fs_file: Nitro.File) !void {
    const Tag = @TagType(Nitro.File);
    switch (fs_file) {
        Tag.Binary => |bin| {
            try file.write(bin.data);
        },
        Tag.Narc => |narc| {
            const fntAndFiles = try getFntAndFiles(Narc, narc, allocator);
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

            try stream.write(utils.toBytes(formats.Header, formats.Header.narc(@intCast(u32, file_end - file_start))));
            try stream.write(utils.toBytes(formats.FatChunk, formats.FatChunk{
                .header = formats.Chunk{
                    .name = formats.Chunk.names.fat,
                    .size = lu32.init(@intCast(u32, fnt_start - fat_start)),
                },
                .file_count = lu16.init(@intCast(u16, files.len)),
                .reserved = lu16.init(0x00),
            }));

            var start: u32 = 0;
            for (files) |f| {
                const fat_entry = FatEntry.init(start, @intCast(u32, f.data.len));
                try stream.write(utils.toBytes(FatEntry, fat_entry));
                start += @intCast(u32, f.data.len);
            }

            try stream.write(utils.toBytes(formats.Chunk, formats.Chunk{
                .name = formats.Chunk.names.fnt,
                .size = lu32.init(@intCast(u32, file_image_start - fnt_start)),
            }));
            try stream.write(@sliceToBytes(main_fnt));
            try stream.write(sub_fnt);
            try stream.writeByteNTimes(0xFF, file_image_start - fnt_end);

            try stream.write(utils.toBytes(formats.Chunk, formats.Chunk{
                .name = formats.Chunk.names.file_data,
                .size = lu32.init(@intCast(u32, file_end - file_image_start)),
            }));
            for (files) |f| {
                try stream.write(f.data);
            }

            try buffered_out_stream.flush();
        },
    }
}

fn fsEqual(allocator: *mem.Allocator, comptime Fs: type, fs1: *Fs, fs2: *Fs) !bool {
    comptime assert(Fs == Nitro or Fs == Narc);

    const FolderPair = struct {
        f1: *Fs,
        f2: *Fs,
    };

    var folders_to_compare = std.ArrayList(FolderPair).init(allocator);
    defer folders_to_compare.deinit();
    try folders_to_compare.append(FolderPair{
        .f1 = fs1,
        .f2 = fs2,
    });

    while (folders_to_compare.popOrNull()) |pair| {
        for (pair.f1.nodes.toSliceConst()) |n1| {
            switch (n1.kind) {
                Fs.Node.Kind.File => |f1| {
                    const f2 = pair.f2.getFile(n1.name) orelse return false;
                    switch (Fs) {
                        Nitro => {
                            const Tag = @TagType(Nitro.File);
                            switch (f1.*) {
                                Tag.Binary => {
                                    if (f2.* != Tag.Binary)
                                        return false;
                                    if (!mem.eql(u8, f1.Binary.data, f2.Binary.data))
                                        return false;
                                },
                                Tag.Narc => {
                                    if (f2.* != Tag.Narc)
                                        return false;
                                    if (!try fsEqual(allocator, Narc, f1.Narc, f2.Narc))
                                        return false;
                                },
                            }
                        },
                        Narc => {
                            if (!mem.eql(u8, f1.data, f2.data))
                                return false;
                        },
                        else => comptime unreachable,
                    }
                },
                Fs.Node.Kind.Folder => |f1| {
                    const f2 = pair.f2.getFolder(n1.name) orelse return false;
                    try folders_to_compare.append(FolderPair{
                        .f1 = f1,
                        .f2 = f2,
                    });
                },
            }
        }
    }

    return true;
}

test "nds.fs: Nitro.File read/write" {
    var buf: [100 * 1024]u8 = undefined;
    var fix_buf_alloc = heap.FixedBufferAllocator.init(buf[0..]);
    const allocator = &fix_buf_alloc.allocator;

    const root = try Nitro.create(allocator);
    _ = try root.createFile("hello.world", Nitro.File{
        .Binary = Nitro.File.Binary{
            .allocator = allocator,
            .data = try mem.dupe(allocator, u8, "Hello World!"),
        },
    });
    _ = try root.createFile("hello.dupe", Nitro.File{
        .Binary = Nitro.File.Binary{
            .allocator = allocator,
            .data = try mem.dupe(allocator, u8, "Hello Dupe!"),
        },
    });

    const folder = try root.createFolder("hello.folder");
    _ = try folder.createFile("good.bye", Nitro.File{
        .Binary = Nitro.File.Binary{
            .allocator = allocator,
            .data = try mem.dupe(allocator, u8, "Cya!"),
        },
    });
    const narc_file = try folder.createFile("good.narc", Nitro.File{ .Narc = try Narc.create(allocator) });
    const narc = narc_file.Narc;

    _ = try narc.createFile("good", Narc.File{
        .allocator = allocator,
        .data = try mem.dupe(allocator, u8, "Good is good!"),
    });
    _ = try narc.createFolder("empty");

    const fntAndFiles = try getFntAndFiles(Nitro, root, allocator);
    const files = fntAndFiles.files;
    const main_fnt = fntAndFiles.main_fnt;
    const sub_fnt = fntAndFiles.sub_fnt;

    const fnt_buff_size = @sliceToBytes(main_fnt).len + sub_fnt.len;
    const fnt_buff = try allocator.alloc(u8, fnt_buff_size);
    const fnt = try fmt.bufPrint(fnt_buff, "{}{}", @sliceToBytes(main_fnt), sub_fnt);
    var fat = std.ArrayList(FatEntry).init(allocator);

    const test_file = "__nds.fs.test.read.write__";
    defer os.deleteFile(allocator, test_file) catch unreachable;

    {
        var file = try os.File.openWrite(allocator, test_file);
        defer file.close();

        for (files) |f| {
            const pos = @intCast(u32, try file.getPos());
            try writeNitroFile(&file, allocator, f.*);
            fat.append(FatEntry.init(pos, @intCast(u32, try file.getPos()) - pos)) catch unreachable;
        }
    }

    const fs2 = blk: {
        var file = try os.File.openRead(allocator, test_file);
        defer file.close();
        break :blk try readNitro(&file, allocator, fnt, fat.toSlice());
    };

    assert(try fsEqual(allocator, Nitro, root, fs2));
}
