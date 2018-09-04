const std = @import("std");
const utils = @import("index.zig");

const io = std.io;
const mem = std.mem;
const math = std.math;

pub fn read(in_stream: var, comptime T: type) !T {
    var result: T = undefined;
    try in_stream.readNoEof(utils.asBytes(T, &result)[0..]);

    return result;
}

pub fn allocRead(in_stream: var, allocator: *mem.Allocator, comptime T: type, size: usize) ![]T {
    const data = try allocator.alloc(T, size);
    errdefer allocator.free(data);

    try in_stream.readNoEof(@sliceToBytes(data));
    return data;
}

pub fn createRead(in_stream: var, allocator: *mem.Allocator, comptime T: type) !*T {
    const res = try allocRead(in_stream, allocator, T, 1);
    return *res[0];
}
