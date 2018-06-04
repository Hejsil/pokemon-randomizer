const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const debug = std.debug;

pub fn ISlice(comptime Item: type, comptime Errors: type) type {
    const VTable = struct {
        const Self = this;

        at: fn (*const u8, usize) Errors!Item,
        length: fn (*const u8) usize,

        fn init(comptime Functions: type, comptime Context: type) Self {
            return Self{
                .at = struct {
                    fn at(d: *const u8, i: usize) Errors!Item {
                        return Functions.at(cast(Context, d), i);
                    }
                }.at,

                .length = struct {
                    fn length(d: *const u8) usize {
                        return Functions.length(cast(Context, d));
                    }
                }.length,
            };
        }

        fn cast(comptime Context: type, ptr: *const u8) *const Context {
            return @ptrCast(*const Context, @alignCast(@alignOf(Context), ptr));
        }
    };

    return struct {
        const Self = this;

        data: *const u8,
        vtable: *const VTable,

        pub fn init(comptime T: type, data: *const T) Self {
            return switch (@typeInfo()) {
                builtin.TypeId.Slice => |info| initFunctions(T, data, struct {
                    fn at(s: *const T, index: usize) (Errors!@typeOf(&T[0])) {
                        return &(s.*)[index];
                    }
                    fn length(s: *const T) usize {
                        return s.len;
                    }
                }),
                else => initFunctions(T, data, T),
            };
        }

        pub fn initFunctions(comptime T: type, data: *const T, comptime Functions: type) Self {
            return Self{
                .data = @ptrCast(*const u8, data),
                .vtable = &comptime VTable.init(Functions, T),
            };
        }

        pub fn at(slice: *const Self, index: usize) Errors!Item {
            return slice.vtable.at(slice.data, index);
        }

        pub fn length(slice: *const Self) usize {
            return slice.vtable.length(slice.data);
        }

        pub fn iterator(slice: *const Self) Iterator {
            return Iterator{
                .current = 0,
                .slice = slice,
            };
        }

        const Iterator = struct {
            current: usize,
            slice: *const Self,

            const Pair = struct {
                value: Item,
                index: usize,
            };

            pub fn next(it: *Iterator) ?Pair {
                while (true) {
                    const res = it.nextWithErrors() catch continue;
                    return res;
                }
            }

            pub fn nextWithErrors(it: *Iterator) Errors!?Pair {
                const l = it.slice.length();
                if (l <= it.current) return null;

                defer it.current += 1;
                return Pair{
                    .value = try it.slice.at(it.current),
                    .index = it.current,
                };
            }
        };
    };
}

pub fn all(slice: var, predicate: fn (*const @typeOf(slice[0])) bool) bool {
    for (slice) |v| {
        if (!predicate(v)) return false;
    }

    return true;
}

test "utils.all" {
    const slice = "aaa"[0..];
    debug.assert(all(slice, struct {
        fn l(c: *const u8) bool {
            return c.* == 'a';
        }
    }.l));
    debug.assert(!all(slice, struct {
        fn l(c: *const u8) bool {
            return c.* != 'a';
        }
    }.l));
}

pub fn any(slice: var, predicate: fn (*const @typeOf(slice[0])) bool) bool {
    for (slice) |v| {
        if (predicate(v)) return true;
    }

    return false;
}

test "utils.any" {
    const slice = "abc"[0..];
    debug.assert(any(slice, struct {
        fn l(c: *const u8) bool {
            return c.* == 'a';
        }
    }.l));
    debug.assert(!any(slice, struct {
        fn l(c: *const u8) bool {
            return c.* == 'd';
        }
    }.l));
}

pub fn populate(slice: var, value: *const @typeOf(slice[0])) void {
    for (slice) |*v| {
        v.* = value.*;
    }
}

test "utils.populate" {
    var arr: [4]u8 = undefined;
    populate(arr[0..], 'a');
    debug.assert(mem.eql(u8, "aaaa", arr));
}

pub fn transform(slice: var, transformer: fn (*const @typeOf(slice[0])) @typeOf(slice[0])) void {
    for (slice) |*v| {
        v.* = transformer(v);
    }
}

test "utils.transform" {
    var arr = "abcd";
    transform(arr[0..], struct {
        fn l(c: *const u8) u8 {
            return if ('a' <= c.* and c.* <= 'z') c.* - ('a' - 'A') else c.*;
        }
    }.l);
    debug.assert(mem.eql(u8, "ABCD", arr));
}
