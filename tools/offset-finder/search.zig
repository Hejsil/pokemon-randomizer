const std = @import("std");

const mem = std.mem;

pub const Offset = struct {
    start: usize,
    end: usize,
};

pub fn findOffsetOfStructArray(comptime Struct: type, comptime ignored_fields: []const []const u8, data: []const u8, start: []const Struct, end: []const Struct) ?Offset {
    const start_index = indexOfStructsInBytes(Struct, ignored_fields, data, 0, start) ?? return null;
    const end_index = indexOfStructsInBytes(Struct, ignored_fields, data, start_index, end) ?? return null;

    return Offset {
        .start = start_index,
        .end = end_index + end.len * @sizeOf(Struct),
    };
}

fn indexOfStructsInBytes(comptime Struct: type, comptime ignored_fields: []const []const u8, data: []const u8, start_index: usize, structs: []const Struct) ?usize {
    const structs_len_in_bytes = structs.len * @sizeOf(Struct);
    if (data.len < structs_len_in_bytes) return null;

    var i : usize = start_index;
    var end = data.len - structs_len_in_bytes;
    while (i <= end) : (i += 1) {
        if (structsMatchesBytes(Struct, ignored_fields, data[i..i + structs_len_in_bytes], structs)) {
            return i;
        }
    }

    return null;
}

fn structsMatchesBytes(comptime Struct: type, comptime ignored_fields: []const []const u8, data: []const u8, structs: []const Struct) bool {
    const structs_len_in_bytes = structs.len * @sizeOf(Struct);
    if (data.len != structs_len_in_bytes) return false;

    for (structs) |s, s_i| {
        const data_bytes = data[s_i * @sizeOf(Struct)..];
        const s_bytes = ([]const u8)((&s)[0..1]);

        comptime var i = 0;
        comptime var byte_offset = 0;
        inline while (i < @memberCount(Struct)) : (i += 1) {
            const member_name = @memberName(Struct, i)[0..];
            if (comptime contains([]const u8, ignored_fields, member_name, strEql)) continue;

            const member_start = @offsetOf(Struct, member_name);
            const member_end = @sizeOf(@memberType(Struct, i)) + member_start;
            if (!mem.eql(u8, data_bytes[member_start..member_end], s_bytes[member_start..member_end])) return false;
        }
    }

    return true;
}

fn strEql(a: &const []const u8, b: &const []const u8) bool {
    return mem.eql(u8, *a, *b);
}

fn contains(comptime T: type, items: []const T, value: &const T, eql: fn(&const T, &const T) bool) bool {
    for (items) |item| {
        if (eql(item, value)) return true;
    }

    return false;
}

/// Finds the start and end index based on a start and end pattern.
pub fn findOffsetUsingPattern(comptime T: type, data: []const T, start: []const ?T, end: []const ?T) ?Offset {
    const start_index = indexOfPattern(T, data, 0, start) ?? return null;
    const end_index = indexOfPattern(T, data, start_index, end) ?? return null;

    return Offset {
        .start = start_index,
        .end = end_index + end.len,
    };
}

/// Finds the start and end index based on a start and end.
pub fn findOffset(comptime T: type, data: []const T, start: []const T, end: []const T) ?Offset {
    const start_index = mem.indexOf(T, data, start) ?? return null;
    const end_index = mem.indexOfPos(T, data, start_index, end) ?? return null;

    return Offset {
        .start = start_index,
        .end = end_index + end.len,
    };
}

fn indexOfPattern(comptime T: type, data: []const T, start_index: usize, pattern: []const ?T) ?usize {
    if (data.len < pattern.len) return null;

    var i : usize = start_index;
    var end = data.len - pattern.len;
    while (i <= end) : (i += 1) {
        if (matchesPattern(T, data[i..i + pattern.len], pattern)) {
            return i;
        }
    }

    return null;
}

/// Given data and a "pattern", returns if the data matches the pattern.
/// For now, a pattern is just data that might contain wild card values, aka
/// values that always match.
fn matchesPattern(comptime T: type, data: []const T, pattern: []const ?T) bool {
    if (data.len != pattern.len) return false;

    for (pattern) |pat, i| {
        if (pat) |value| {
            if (data[i] != value) return false;
        }
    }

    return true;
}
