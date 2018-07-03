const std = @import("std");
const fs = @import("fs.zig");

const debug = std.debug;
const heap = std.heap;
const mem = std.mem;
const fmt = std.fmt;
const os = std.os;
const rand = std.rand;

fn countParents(comptime Folder: type, folder: *Folder) usize {
    var res: usize = 0;
    var tmp = folder;
    while (tmp.parent) |par| {
        tmp = par;
        res += 1;
    }

    return res;
}

fn randomFs(allocator: *mem.Allocator, random: *rand.Random, comptime Folder: type) !*Folder {
    comptime debug.assert(Folder == fs.Nitro or Folder == fs.Narc);

    const root = try Folder.create(allocator);
    var unique: u64 = 0;
    var curr: ?*Folder = root;
    while (curr) |folder| {
        const parents = countParents(Folder, folder);
        const choice = random.range(usize, 0, 255);
        if (choice < parents + folder.nodes.len) {
            curr = folder.parent;
            break;
        }

        const is_file = random.scalar(bool);
        var name_buf: [50]u8 = undefined;
        const name = try fmt.bufPrint(name_buf[0..], "{}", unique);
        unique += 1;

        if (is_file) {
            switch (Folder) {
                fs.Nitro => {
                    _ = try folder.createFile(name, blk: {
                        const is_narc = random.scalar(bool);

                        if (is_narc) {
                            break :blk fs.Nitro.File{
                                .Narc = try randomFs(allocator, random, fs.Narc),
                            };
                        }

                        const data = try allocator.alloc(u8, random.range(usize, 10, 100));
                        random.bytes(data);
                        break :blk fs.Nitro.File{
                            .Binary = fs.Nitro.File.Binary{
                                .allocator = allocator,
                                .data = data,
                            },
                        };
                    });
                },
                fs.Narc => {
                    const data = try allocator.alloc(u8, random.range(usize, 10, 100));
                    random.bytes(data);
                    _ = try folder.createFile(name, fs.Narc.File{
                        .allocator = allocator,
                        .data = data,
                    });
                },
                else => comptime unreachable,
            }
        } else {
            curr = try folder.createFolder(name);
        }
    }

    return root;
}

fn fsEqual(allocator: *mem.Allocator, comptime Folder: type, fs1: *Folder, fs2: *Folder) !bool {
    comptime debug.assert(Folder == fs.Nitro or Folder == fs.Narc);

    const FolderPair = struct {
        f1: *Folder,
        f2: *Folder,
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
                Folder.Node.Kind.File => |f1| {
                    const f2 = pair.f2.getFile(n1.name) orelse return false;
                    switch (Folder) {
                        fs.Nitro => {
                            const Tag = @TagType(fs.Nitro.File);
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
                                    if (!try fsEqual(allocator, fs.Narc, f1.Narc, f2.Narc))
                                        return false;
                                },
                            }
                        },
                        fs.Narc => {
                            if (!mem.eql(u8, f1.data, f2.data))
                                return false;
                        },
                        else => comptime unreachable,
                    }
                },
                Folder.Node.Kind.Folder => |f1| {
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

test "nds.fs.read/writeNitro" {
    var buf: [1024 * 1024]u8 = undefined;
    var fix_buf_alloc = heap.FixedBufferAllocator.init(buf[0..]);
    var random = rand.DefaultPrng.init(0);

    const allocator = &fix_buf_alloc.allocator;
    const root = try randomFs(allocator, &random.random, fs.Nitro);
    const fntAndFiles = try fs.getFntAndFiles(fs.Nitro, root, allocator);
    const files = fntAndFiles.files;
    const main_fnt = fntAndFiles.main_fnt;
    const sub_fnt = fntAndFiles.sub_fnt;

    const fnt_buff_size = @sliceToBytes(main_fnt).len + sub_fnt.len;
    const fnt_buff = try allocator.alloc(u8, fnt_buff_size);
    const fnt = try fmt.bufPrint(fnt_buff, "{}{}", @sliceToBytes(main_fnt), sub_fnt);
    var fat = std.ArrayList(fs.FatEntry).init(allocator);

    const test_file = "__nds.fs.test.read.write__";
    defer os.deleteFile(allocator, test_file) catch unreachable;

    {
        var file = try os.File.openWrite(allocator, test_file);
        defer file.close();

        for (files) |f| {
            const pos = @intCast(u32, try file.getPos());
            try fs.writeNitroFile(&file, allocator, f.*);
            fat.append(fs.FatEntry.init(pos, @intCast(u32, try file.getPos()) - pos)) catch unreachable;
        }
    }

    const fs2 = blk: {
        var file = try os.File.openRead(allocator, test_file);
        defer file.close();
        break :blk try fs.readNitro(&file, allocator, fnt, fat.toSlice());
    };

    debug.assert(try fsEqual(allocator, fs.Nitro, root, fs2));
}
