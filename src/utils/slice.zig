const std   = @import("std");
const mem   = std.mem;
const debug = std.debug;

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
