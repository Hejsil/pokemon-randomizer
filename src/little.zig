const std     = @import("std");
const builtin = @import("builtin");
const utils   = @import("utils.zig");

const debug = std.debug;
const mem   = std.mem;

const assert = debug.assert;

/// A data structure representing an Little Endian Integer
pub fn Little(comptime Int: type) type {
    comptime debug.assert(@typeId(Int) == builtin.TypeId.Int);

    return packed struct {
        const Self = this;
        bytes: [@sizeOf(Int)]u8,

        pub fn init(v: Int) Self {
            var res : Self = undefined;
            res.set(v);

            return res;
        }

        pub fn set(self: &Self, v: Int) void {
            mem.writeInt(self.bytes[0..], v, builtin.Endian.Little);
        }

        pub fn get(self: &const Self) Int {
            return mem.readIntLE(Int, self.bytes);
        }
    };
}

pub fn add(comptime T: type, l: &const Little(T), r: &const Little(T)) Little(T) {
    return toLittle(T, l.get() + r.get());
}

pub fn toLittle(comptime Int: type, v: Int) Little(Int) {
    return Little(Int).init(v);
}

test "little.Little" {
    const value = 0x12345678;
    const num = Little(u32).init(value);
    assert(num.get() == value);
    assert(mem.eql(u8, []u8 { 0x78, 0x56, 0x34, 0x12 }, num.bytes));
}