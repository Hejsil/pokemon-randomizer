const std = @import("std");
const utils = @import("index.zig");

const io  = std.io;
const os  = std.os;
const mem = std.mem;

pub fn noAllocRead(comptime T: type, file: &os.File) !T {
    var file_stream = io.FileInStream.init(file);
    var stream = &file_stream.stream;

    var result : T = undefined;
    try stream.readNoEof(utils.asBytes(&result));

    return result;
}

pub fn seekToNoAllocRead(comptime T: type, file: &os.File, offset: usize) !T {
    try file.seekTo(offset);
    return noAllocRead(T, file);
}

pub fn seekToAllocAndRead(comptime T: type, file: &os.File, allocator: &mem.Allocator, offset: usize, size: usize) ![]T {
    try file.seekTo(offset);
    return allocAndRead(T, file, allocator, size);
}

pub fn allocAndRead(comptime T: type, file: &os.File, allocator: &mem.Allocator, size: usize) ![]T {
    var file_stream = io.FileInStream.init(file);
    var stream = &file_stream.stream;

    const data = try allocator.alloc(T, size);
    errdefer allocator.free(data);

    try stream.readNoEof(([]u8)(data));

    return data;
}

pub fn seekToCreateAndRead(comptime T: type, file: &os.File, allocator: &mem.Allocator, offset: usize) !&T {
    const res = try seekToAllocAndRead(T, file, allocator, offset, 1);
    return &res[0];
}

pub fn createAndRead(comptime T: type, file: &os.File, allocator: &mem.Allocator) !&T {
    const res = try allocAndRead(T, file, allocator, 1);
    return &res[0];
}
