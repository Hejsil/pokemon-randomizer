const std = @import("std");

const math  = std.math;
const debug = std.debug;

const assert = debug.assert;

pub const u1 = @IntType(false, 1);

pub fn set(comptime T: type, num: T, bit: math.Log2Int(T), value: u1) T {
    return (num & ~(T(1) << bit)) | (T(value) << bit);
}

test "bits.set" {
    const v = u8(0b10);
    assert(set(u8, v, 0, 1) == 0b11);
    assert(set(u8, v, 1, 1) == 0b10);
    assert(set(u8, v, 0, 0) == 0b10);
    assert(set(u8, v, 1, 0) == 0b00);
}

pub fn get(comptime T: type, num: T, bit: math.Log2Int(T)) u1 {
    return u1((num >> bit) & 1);
}

test "bits.get" {
    const v = u8(0b10);
    assert(get(u8, v, 0) == 0);
    assert(get(u8, v, 1) == 1);
}

pub fn toggle(comptime T: type, num: T, bit: math.Log2Int(T)) T {
    return num ^ (T(1) << bit);
}

test "bits.toggle" {
    const v = u8(0b10);
    assert(toggle(u8, v, 0) == 0b11);
    assert(toggle(u8, v, 1) == 0b00);
}