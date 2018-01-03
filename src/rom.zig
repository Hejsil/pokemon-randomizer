const std = @import("std");
const os = std.os;
const mem = std.mem;
const io = std.io;
const path = os.path;

const File = io.File;
const Allocator = mem.Allocator;
const ChildProcess = os.ChildProcess;
const Version = @import("version.zig").Version;

pub const OpenRomResult = union(enum) {
    Nds: NdsRom,
}

pub fn openRom() -> %OpenRomResult {

}

pub const NdsRom = struct {
    pub fn init(rom: &File, allocator: &Allocator) -> %NdsRom {

    }
};