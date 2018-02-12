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

        pub fn set(little: &Self, v: Int) void {
            mem.writeInt(little.bytes[0..], v, builtin.Endian.Little);
        }

        pub fn get(little: &const Self) Int {
            return mem.readIntLE(Int, little.bytes);
        }
    };
}

pub fn add(comptime T: type, l: &const Little(T), r: &const Little(T)) Little(T) {
    return toLittle(l.get() + r.get());
}

pub fn toLittle(v: var) Little(@typeOf(v)) {
    return Little(@typeOf(v)).init(v);
}

test "little.Little" {
    const value = 0x12345678;
    const num = Little(u32).init(value);
    assert(num.get() == value);
    assert(mem.eql(u8, []u8 { 0x78, 0x56, 0x34, 0x12 }, num.bytes));
}
