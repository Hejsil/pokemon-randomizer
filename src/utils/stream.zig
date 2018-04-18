const std = @import("std");
const utils = @import("index.zig");

const io   = std.io;
const mem  = std.mem;
const math = std.math;

pub const MemInStream = struct {
    memory: []const u8,
    stream: Stream,

    pub const Error = error{OutOfMemory};
    pub const Stream = io.InStream(Error);

    pub fn init(memory: []const u8) MemInStream {
        return MemInStream {
            .memory = memory,
            .stream = Stream {
                .readFn = readFn
            }
        };
    }

    fn readFn(in_stream: &Stream, buffer: []u8) Error!usize {
        const self = @fieldParentPtr(MemInStream, "stream", in_stream);
        const bytes_read = math.min(buffer.len, self.memory.len);

        mem.copy(u8, buffer, self.memory[0..bytes_read]);
        self.memory = self.memory[bytes_read..];

        return bytes_read;
    }
};

pub fn read(in_stream: var, comptime T: type) !T {
    var result : T = undefined;
    try in_stream.readNoEof(utils.asBytes(T, &result));

    return result;
}

pub fn allocRead(in_stream: var, allocator: &mem.Allocator, comptime T: type, size: usize) ![]T {
    const data = try allocator.alloc(T, size);
    errdefer allocator.free(data);

    try in_stream.readNoEof(([]u8)(data));
    return data;
}

pub fn createRead(in_stream: var, allocator: &mem.Allocator, comptime T: type) !&T {
    const res = try allocRead(in_stream, allocator, T, 1);
    return &res[0];
}
