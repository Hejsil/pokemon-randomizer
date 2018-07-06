const std = @import("std");
const debug = std.debug;

pub fn to(n: usize) []void {
    return ([*]void)(undefined)[0..n];
}

test "utils.loop.to" {
    var j: usize = 0;
    for (to(10)) |_, i| {
        debug.assert(j == i);
        j += 1;
    }
}
