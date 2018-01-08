const std = @import("std");

const io  = std.io;
const mem = std.mem;

pub fn Pair(comptime F: type, comptime S: type) -> type {
    return struct {
        const Self = this;
        first: F, second: S,

        pub fn init(f: &const F, s: &const S) -> Self {
            return Self { .first = *f, .second = *s };
        }
    };
}

pub fn asConstBytes(comptime T: type, value: &const T) -> []const u8 {
    return ([]const u8)(value[0..1]); 
}

pub fn asBytes(comptime T: type, value: &T) -> []u8 {
    return ([]u8)(value[0..1]); 
}

// TODO: Let's see what the answer is for this issue: https://github.com/zig-lang/zig/issues/670
pub fn all(comptime T: type, slice: []const T, predicate: fn(T) -> bool) -> bool {
    for (slice) |v| {
        if (!predicate(v)) return false;
    }

    return true;
}

pub fn between(comptime T: type, v: T, min: T, max: T) -> bool {
    return min <= v and v <= max;
}

error EmptySlice;

pub fn first(comptime T: type, args: []const T) -> %T {
    if (args.len > 0) {
        return args[0];
    } else {
        return error.EmptySlice;
    }
}

pub fn seekToAllocAndReadNoEof(comptime T: type, file: &io.File, allocator: &mem.Allocator, offset: usize, size: usize) -> %[]T {
    try file.seekTo(offset);

    return allocAndReadNoEof(T, file, allocator, size);
}  

pub fn allocAndReadNoEof(comptime T: type, file: &io.File, allocator: &mem.Allocator, size: usize) -> %[]T {
    var file_stream = io.FileInStream.init(file);
    var stream = &file_stream.stream;

    var data = try allocator.alloc(T, size);
    %defer allocator.free(data);

    try stream.readNoEof(([]u8)(data));

    return data;
}  

pub fn seekToCreateAndReadNoEof(comptime T: type, file: &io.File, allocator: &mem.Allocator, offset: usize) -> %&T {
    try file.seekTo(offset);

    return createAndReadNoEof(T, file, allocator);
}  

pub fn createAndReadNoEof(comptime T: type, file: &io.File, allocator: &mem.Allocator) -> %&T {
    const res = try allocAndReadNoEof(T, file, allocator, 1);
    return &res[0];
}  