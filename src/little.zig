const std = @import("std");
const builtin = @import("builtin");
const debug = std.debug;
const mem = std.mem;

/// A data structure representing an Little Endian Integer
pub fn Little(comptime Int: type) -> type {
    comptime debug.assert(@typeId(Int) == builtin.TypeId.Int);

    return packed struct {
        const Self = this;
        bytes: [@sizeOf(Int)]u8,

        pub fn init(v: Int) -> Self {
            var res : Self = undefined;
            res.set(v);

            return res;
        }

        pub fn set(self: &const Self, v: Int) {
            mem.writeInt(self.bytes[0..], v, builtin.Endian.Little);
        }

        pub fn get(self: &const Self) -> Int {
            return mem.readIntLE(Int, self.bytes);
        }
    };
}