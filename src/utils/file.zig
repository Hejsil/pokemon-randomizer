const std = @import("std");
const utils = @import("index.zig");

const io  = std.io;
const os  = std.os;
const mem = std.mem;

pub fn read(file: &os.File, comptime T: type) !T {
    var file_stream = io.FileInStream.init(file);
    var stream = &file_stream.stream;

    var result : T = undefined;
    try stream.readNoEof(utils.asBytes(&result));

    return result;
}

pub fn seekToRead(file: &os.File, offset: usize, comptime T: type) !T {
    try file.seekTo(offset);
    return read(file, T);
}

pub fn seekToAllocRead(file: &os.File, offset: usize, allocator: &mem.Allocator, comptime T: type, size: usize) ![]T {
    try file.seekTo(offset);
    return allocRead(file, allocator, T, size);
}

pub fn allocRead(file: &os.File, allocator: &mem.Allocator, comptime T: type, size: usize) ![]T {
    var file_stream = io.FileInStream.init(file);
    var stream = &file_stream.stream;

    const data = try allocator.alloc(T, size);
    errdefer allocator.free(data);

    try stream.readNoEof(([]u8)(data));
    return data;
}

pub fn seekToCreateRead(file: &os.File, offset: usize, allocator: &mem.Allocator, comptime T: type) !&T {
    const res = try seekToAllocRead(T, file, allocator, offset, 1);
    return &res[0];
}

pub fn createRead(file: &os.File, allocator: &mem.Allocator, comptime T: type) !&T {
    const res = try allocRead(T, file, allocator, 1);
    return &res[0];
}
