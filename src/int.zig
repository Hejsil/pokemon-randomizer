const std = @import("std");
const builtin = @import("builtin");
const utils = @import("utils.zig");

const debug = std.debug;
const mem = std.mem;

const assert = debug.assert;

pub const lu16 = Int(u16, builtin.Endian.Little);
pub const lu32 = Int(u32, builtin.Endian.Little);
pub const lu64 = Int(u64, builtin.Endian.Little);
pub const lu128 = Int(u128, builtin.Endian.Little);
pub const li16 = Int(i16, builtin.Endian.Little);
pub const li32 = Int(i32, builtin.Endian.Little);
pub const li64 = Int(i64, builtin.Endian.Little);
pub const li128 = Int(i128, builtin.Endian.Little);

pub const bu16 = Int(u16, builtin.Endian.Big);
pub const bu32 = Int(u32, builtin.Endian.Big);
pub const bu64 = Int(u64, builtin.Endian.Big);
pub const bu128 = Int(u128, builtin.Endian.Big);
pub const bi16 = Int(i16, builtin.Endian.Big);
pub const bi32 = Int(i32, builtin.Endian.Big);
pub const bi128 = Int(i128, builtin.Endian.Big);

/// A data structure representing an integer of a specific endianess
pub fn Int(comptime Inner: type, comptime endian: builtin.Endian) type {
    comptime debug.assert(@typeId(Inner) == builtin.TypeId.Int);

    return packed struct {
        const Self = @This();

        bytes: [@sizeOf(Inner)]u8,

        pub fn init(v: Inner) Self {
            var res: Self = undefined;
            mem.writeInt(res.bytes[0..], v, endian);

            return res;
        }

        pub fn value(int: Self) Inner {
            return mem.readInt(int.bytes[0..], Inner, endian);
        }
    };
}

test "int.Int" {
    const value = 0x12345678;
    const numLittle = Int(u32, builtin.Endian.Little).init(value);
    const numBig = Int(u32, builtin.Endian.Big).init(value);
    assert(numLittle.value() == value);
    assert(numBig.value() == value);
    assert(mem.eql(u8, []u8{ 0x78, 0x56, 0x34, 0x12 }, numLittle.bytes));
    assert(mem.eql(u8, []u8{ 0x12, 0x34, 0x56, 0x78 }, numBig.bytes));
}
