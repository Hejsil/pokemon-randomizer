const std  = @import("std");
const zblz = @import("blz.zig");
const cblz = @cImport(@cInclude("blz.h"));

const heap  = std.heap;
const debug = std.debug;
const mem   = std.mem;
const io    = std.io;
const os    = std.os;

pub fn main() !void {
    var direct_allocator = heap.DirectAllocator.init();
    defer direct_allocator.deinit();
    var global = heap.ArenaAllocator.init(&direct_allocator.allocator);
    defer global.deinit();

    var stdout_handle = try io.getStdOut();
    var stdout_file_stream = io.FileOutStream.init(&stdout_handle);
    var stdout = &stdout_file_stream.stream;

    var stderr_handle = try io.getStdErr();
    var stderr_file_stream = io.FileOutStream.init(&stderr_handle);
    var stderr = &stderr_file_stream.stream;

    // NOTE: Do we want to use another allocator for arguments? Does it matter? Idk.
    const args = try os.argsAlloc(&global.allocator);
    defer os.argsFree(&global.allocator, args);

    if (args.len < 2) {
        try stderr.print("No file was provided.\n");
        return error.NoFileInArguments;
    }

    for (args[1..]) |arg| {
        var arena = heap.ArenaAllocator.init(&direct_allocator.allocator);
        defer arena.deinit();

        const allocator = &arena.allocator;

        var file = os.File.openRead(allocator, arg) catch |err| {
            try stderr.print("Couldn't open {}.\n", arg);
            return err;
        };
        defer file.close();
        const bytes = try allocator.alloc(u8, try file.getEndPos());
        const read = try file.read(bytes);
        const bytes2 = try mem.dupe(allocator, u8, bytes);
        debug.assert(read == bytes.len);

        const zdecoded = try zblz.decode(bytes2, allocator);
        const cdecoded = blk: {
            var out_len : c_uint = undefined;
            const res = ??cblz.BLZ_Decode(&bytes[0], c_uint(bytes.len), &out_len);
            break :blk res[0..out_len];
        };
        defer heap.c_allocator.free(cdecoded);
        debug.assert(mem.eql(u8, zdecoded, cdecoded));

        const zencoded_best = try zblz.encode(cdecoded, zblz.Mode.Best, false, allocator);
        const cencoded_best = blk: {
            var out_len : c_uint = undefined;
            const res = ??cblz.BLZ_Encode(&cdecoded[0], c_uint(cdecoded.len), &out_len, cblz.BLZ_BEST);
            break :blk res[0..out_len];
        };
        defer heap.c_allocator.free(cencoded_best);
        debug.assert(mem.eql(u8, zencoded_best, cencoded_best));

        const zencoded_normal = try zblz.encode(cdecoded, zblz.Mode.Normal, allocator);
        const cencoded_normal = blk: {
            var out_len : c_uint = undefined;
            const res = ??cblz.BLZ_Encode(&cdecoded[0], c_uint(cdecoded.len), &out_len, cblz.BLZ_NORMAL);
            break :blk res[0..out_len];
        };
        defer heap.c_allocator.free(cencoded_normal);
        debug.assert(mem.eql(u8, zencoded_normal, cencoded_normal));
    }
}
