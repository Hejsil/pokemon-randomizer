const blz = @import("blz.zig");
const heap = @import("std").heap;

pub const BlzMode = extern enum {
    Normal = @TagType(blz.Mode)(blz.Mode.Normal),
    Best = @TagType(blz.Mode)(blz.Mode.Best)
};

pub export fn blzDecode(data: &const u8, len: usize, new_len: &usize) ?&u8 {
    const res = blz.decode(data[0..len], heap.c_allocator) catch return null;
    *new_len = res.len;
    return &res[0];
}

pub export fn blzEncode(data: &const u8, len: usize, mode: BlzMode, new_len: &usize) ?&u8 {
    const res = blz.encode(data[0..len], blz.Mode(@TagType(BlzMode)(mode)), heap.c_allocator) catch return null;
    *new_len = res.len;
    return &res[0];
}
