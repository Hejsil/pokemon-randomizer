const std   = @import("std");
const mem   = std.mem;
const debug = std.debug;

pub const slice = @import("slice.zig");
pub const file  = @import("file.zig");

test "utils" {
    _ = @import("slice.zig");
    _ = @import("file.zig");
}

fn isConstPtr(comptime T: type) bool {
    comptime debug.assert(@typeId(T) == @import("builtin").TypeId.Pointer);
    return &const T.Child == T;
}

fn ByteSliceFromPtr(comptime T: type) type {
    if (isConstPtr(T)) {
        return []const u8;
    } else {
        return []u8;
    }
}

pub fn asBytes(value: var) blk: { break :blk comptime ByteSliceFromPtr(@typeOf(value)); } {
    const Slice = comptime ByteSliceFromPtr(@typeOf(value));
    return Slice(value[0..1]);
}

test "utils.asBytes" {
    const Str = packed struct { a: u8, b: u8 };
    const constStr = Str{ .a = 0x01, .b = 0x02 };
    var str = Str{ .a = 0x01, .b = 0x02 };
    debug.assert(mem.eql(u8, []u8 { 0x01, 0x02 }, asBytes(constStr)));
    debug.assert(mem.eql(u8, []u8 { 0x01, 0x02 }, asBytes(str)));
    debug.assert(@typeOf(asBytes(constStr)) == []const u8);
    debug.assert(@typeOf(asBytes(str)) == []u8);
}
