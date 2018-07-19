const std = @import("std");

const math = std.math;
const debug = std.debug;

const assert = debug.assert;

pub fn set(comptime Int: type, num: Int, bit: math.Log2Int(Int), value: bool) Int {
    return (num & ~(Int(1) << bit)) | (Int(@boolToInt(value)) << bit);
}

test "bits.set" {
    const v = u8(0b10);
    assert(set(u8, v, 0, true) == 0b11);
    assert(set(u8, v, 1, true) == 0b10);
    assert(set(u8, v, 0, false) == 0b10);
    assert(set(u8, v, 1, false) == 0b00);
}

pub fn get(comptime Int: type, num: Int, bit: math.Log2Int(Int)) bool {
    return ((num >> bit) & 1) != 0;
}

test "bits.get" {
    const v = u8(0b10);
    assert(get(u8, v, 0) == false);
    assert(get(u8, v, 1) == true);
}

pub fn toggle(comptime Int: type, num: Int, bit: math.Log2Int(Int)) Int {
    return num ^ (Int(1) << bit);
}

test "bits.toggle" {
    const v = u8(0b10);
    assert(toggle(u8, v, 0) == 0b11);
    assert(toggle(u8, v, 1) == 0b00);
}

pub fn count(comptime Int: type, num: Int) usize {
    var tmp = num;
    var res: usize = 0;
    while (tmp != 0) : (res += 1)
        tmp &= tmp - 1;

    return res;
}

test "bits.count" {
    assert(count(u8, 0b0) == 0);
    assert(count(u8, 0b1) == 1);
    assert(count(u8, 0b101) == 2);
    assert(count(u8, 0b11011) == 4);
}
