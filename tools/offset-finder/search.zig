const std = @import("std");
const builtin = @import("builtin");
const fun = @import("fun");

const mem = std.mem;
const compare = fun.generic.compare;

pub const Offset = struct {
    start: usize,
    end: usize,
};

pub fn findStructs(comptime Struct: type, comptime ignored_fields: []const []const u8, data: []const u8, start: []const Struct, end: []const Struct) ?[]const Struct {
    const start_index = indexOfStructs(Struct, ignored_fields, data, 0, start) ?? return null;
    const end_index = indexOfStructs(Struct, ignored_fields, data, start_index, end) ?? return null;

    // TODO: This can fail
    return ([]const Struct)(data[start_index..end_index + end.len * @sizeOf(Struct)]);
}

fn indexOfStructs(comptime Struct: type, comptime ignored_fields: []const []const u8, data: []const u8, start_index: usize, structs: []const Struct) ?usize {
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
        const data_bytes = data[s_i * @sizeOf(Struct)..][0..@sizeOf(Struct)];
        const data_s = ([]const Struct)(data_bytes)[0];

        switch (@typeInfo(Struct)) {
            builtin.TypeId.Array => |arr| {
                for (s) |child, i| {
                    if (!structsMatchesBytes(arr.child, ignored_fields, data_bytes, s))
                        return false;
                }
            },
            builtin.TypeId.Struct => |str| {
                inline for (str.fields) |field, i| {
                    if (comptime contains([]const u8, ignored_fields, field.name, strEql))
                        continue;

                    if (!fieldsEql(field.name, Struct, s, data_s))
                        return false;
                }
            },
            else => comptime unreachable,
        }
    }

    return true;
}

fn fieldsEql(comptime field: []const u8, comptime T: type, a: &const T, b: &const T) bool {
    const af = @field(a, field);
    const bf = @field(b, field);
    return compare.equal(@typeOf(af))(af, bf);
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
pub fn findPattern(comptime T: type, data: []const T, start: []const ?T, end: []const ?T) ?[]const u8 {
    const start_index = indexOfPattern(T, data, 0, start) ?? return null;
    const end_index = indexOfPattern(T, data, start_index, end) ?? return null;

    return data[start_index..end_index + end.len];
}

/// Finds the start and end index based on a start and end.
pub fn findBytes(comptime T: type, data: []const T, start: []const T, end: []const T) ?[]const u8 {
    const start_index = mem.indexOf(T, data, start) ?? return null;
    const end_index = mem.indexOfPos(T, data, start_index, end) ?? return null;

    return data[start_index..end_index + end.len];
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
