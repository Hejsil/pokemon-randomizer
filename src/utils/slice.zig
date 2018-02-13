const std   = @import("std");
const mem   = std.mem;
const debug = std.debug;

pub fn sliceOrNull(slice: var, start: usize, end: usize) ?@typeOf(slice[0..]) {
    if (end < start)     return null;
    if (slice.len < end) return null;

    return slice[start..end];
}

test "utils.sliceOrNull" {
    const slice = "abcde"[0..];
    debug.assert(mem.eql(u8, "abcde", ??sliceOrNull(slice, 0, 5)));
    debug.assert(mem.eql(u8, "cd",    ??sliceOrNull(slice, 2, 4)));
    debug.assert(mem.eql(u8, "",      ??sliceOrNull(slice, 0, 0)));
    debug.assert(mem.eql(u8, "",      ??sliceOrNull(slice, 5, 5)));
    debug.assert(sliceOrNull(slice, 1, 0) == null);
    debug.assert(sliceOrNull(slice, 0, 6) == null);
    debug.assert(sliceOrNull(slice, 6, 6) == null);
}

pub fn atOrNull(slice: var, index: usize) ?@typeOf(slice[0]) {
    const ptr = ptrAtOrNull(slice, index) ?? return null;
    return *ptr;
}

pub fn ptrAtOrNull(slice: var, index: usize) ?@typeOf(&slice[0]) {
    if (slice.len <= index) return null;
    return &slice[index];
}

test "utils.atOrNull" {
    const slice = "abcde"[0..];
    debug.assert(??atOrNull(slice, 0) == 'a');
    debug.assert(??atOrNull(slice, 4) == 'e');
    debug.assert(atOrNull(slice, 5) == null);
}

pub fn all(slice: var, predicate: fn(&const @typeOf(slice[0])) bool) bool {
    for (slice) |v| {
        if (!predicate(v)) return false;
    }

    return true;
}

test "utils.all" {
    const slice = "aaa"[0..];
    debug.assert( all(slice, struct { fn l(c: &const u8) bool { return *c == 'a'; } }.l));
    debug.assert(!all(slice, struct { fn l(c: &const u8) bool { return *c != 'a'; } }.l));
}

pub fn any(slice: var, predicate: fn(&const @typeOf(slice[0])) bool) bool {
    for (slice) |v| {
        if (predicate(v)) return true;
    }

    return false;
}

test "utils.any" {
    const slice = "abc"[0..];
    debug.assert( any(slice, struct { fn l(c: &const u8) bool { return *c == 'a'; } }.l));
    debug.assert(!any(slice, struct { fn l(c: &const u8) bool { return *c == 'd'; } }.l));
}

pub fn populate(slice: var, value: &const @typeOf(slice[0])) void {
    for (slice) |*v| { *v = *value; }
}

test "utils.populate" {
    var arr : [4]u8 = undefined;
    populate(arr[0..], 'a');
    debug.assert(mem.eql(u8, "aaaa", arr));
}

pub fn transform(slice: var, transformer: fn(&const @typeOf(slice[0])) @typeOf(slice[0])) void {
    for (slice) |*v| { *v = transformer(v); }
}

test "utils.transform" {
    var arr = "abcd";
    transform(arr[0..], struct { fn l(c: &const u8) u8 {
        return if ('a' <= *c and *c <= 'z') *c - ('a' - 'A') else *c; }
    }.l);
    debug.assert(mem.eql(u8, "ABCD", arr));
}
