const std    = @import("std");
const crc    = @import("crc");
const ascii  = @import("../ascii.zig");
const utils  = @import("../utils.zig");
const little = @import("../little.zig");

const debug = std.debug;
const mem   = std.mem;
const io    = std.io;
const sort  = std.sort;

const assert = debug.assert;


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