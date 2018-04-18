const std   = @import("std");
const mem   = std.mem;
const debug = std.debug;

pub const slice  = @import("slice.zig");
pub const file   = @import("file.zig");
pub const stream = @import("stream.zig");

test "utils" {
    _ = @import("slice.zig");
    _ = @import("file.zig");
}

/// Returns a mutable byte slice of ::value.
pub fn asBytes(comptime T: type, value: &T) []u8 {
    return ([]u8)(value[0..1]);
}

/// Converts ::value to a byte array of size @sizeOf(::T).
pub fn toBytes(comptime T: type, value: &const T) [@sizeOf(T)]u8 {
    var res : [@sizeOf(T)]u8 = undefined;
    mem.copy(u8, res[0..], ([]const u8)(value[0..1]));
    return res;
}

test "utils.asBytes" {
    const Str = packed struct { a: u8, b: u8 };
    var str = Str{ .a = 0x01, .b = 0x02 };
    debug.assert(mem.eql(u8, []u8 { 0x01, 0x02 }, asBytes(Str, &str)));
}

test "utils.toBytes" {
    const Str = packed struct { a: u8, b: u8 };
    const str = Str{ .a = 0x01, .b = 0x02 };
    debug.assert(mem.eql(u8, []u8 { 0x01, 0x02 }, toBytes(Str, str)));
}
