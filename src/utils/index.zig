const std = @import("std");
const mem = std.mem;
const debug = std.debug;

pub const stream = @import("stream.zig");

test "utils" {
    _ = @import("stream.zig");
}

/// Returns a mutable byte slice of ::value.
pub fn asBytes(comptime T: type, value: *T) *[@sizeOf(T)]u8 {
    return @ptrCast(*[@sizeOf(T)]u8, value);
}

/// Converts ::value to a byte array of size @sizeOf(::T).
pub fn toBytes(comptime T: type, value: T) [@sizeOf(T)]u8 {
    return @ptrCast(*const [@sizeOf(T)]u8, &value).*;
}

test "utils.asBytes" {
    const Str = packed struct {
        a: u8,
        b: u8,
    };
    var str = Str{ .a = 0x01, .b = 0x02 };
    debug.assert(mem.eql(u8, []u8{ 0x01, 0x02 }, asBytes(Str, &str)[0..]));
}

test "utils.toBytes" {
    const Str = packed struct {
        a: u8,
        b: u8,
    };
    const str = Str{ .a = 0x01, .b = 0x02 };
    debug.assert(mem.eql(u8, []u8{ 0x01, 0x02 }, toBytes(Str, str)));
}
