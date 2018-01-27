const std = @import("std");

const math  = std.math;
const debug = std.debug;

const assert = debug.assert;

pub const u1 = @IntType(false, 1);

pub fn set(comptime T: type, num: T, bit: math.Log2Int(T), value: bool) T {
    return (num & ~(T(1) << bit)) | (T(value) << bit);
}

test "bits.set" {
    const v = u8(0b10);
    assert(set(u8, v, 0, true ) == 0b11);
    assert(set(u8, v, 1, true ) == 0b10);
    assert(set(u8, v, 0, false) == 0b10);
    assert(set(u8, v, 1, false) == 0b00);
}

pub fn get(comptime T: type, num: T, bit: math.Log2Int(T)) bool {
    return ((num >> bit) & 1) != 0;
}

test "bits.get" {
    const v = u8(0b10);
    assert(get(u8, v, 0) == false);
    assert(get(u8, v, 1) == true);
}

pub fn toggle(comptime T: type, num: T, bit: math.Log2Int(T)) T {
    return num ^ (T(1) << bit);
}

test "bits.toggle" {
    const v = u8(0b10);
    assert(toggle(u8, v, 0) == 0b11);
    assert(toggle(u8, v, 1) == 0b00);
}

pub fn count(comptime T: type, num: T) usize {
    var tmp = num;
    var res : usize = 0;
    while (tmp != 0) : (res += 1)
        tmp &= tmp - 1;

    return res;
}

test "bits.count" {
    assert(count(u8, 0b0)     == 0);
    assert(count(u8, 0b1)     == 1);
    assert(count(u8, 0b101)   == 2);
    assert(count(u8, 0b11011) == 4);
}