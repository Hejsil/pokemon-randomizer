const std = @import("std");
const gba = @import("gba.zig");
const nds = @import("nds.zig");
const utils = @import("utils.zig");
const gen3 = @import("pokemon/gen3.zig");
const os = std.os;
const debug = std.debug;
const mem = std.mem;
const io = std.io;
const path = os.path;

const Rom = union(enum) {
    Gba: gba.Rom,
    Nds: nds.Rom,

    pub fn destroy(self: &const Rom, allocator: &mem.Allocator) {
        switch (*self) {
            Rom.Gba => |gba_rom| gba_rom.destroy(allocator),
            Rom.Nds => |nds_rom| nds_rom.destroy(allocator),
        }
    }
};

error NotARom;

fn loadRom(file_path: []const u8, allocator: &mem.Allocator) -> %Rom {
    gba_blk: {
        var rom_file = %return io.File.openRead(file_path, null);
        var file_stream = io.FileInStream.init(&rom_file);
        var rom = gba.Rom.fromStream(&file_stream.stream, allocator) %% break :gba_blk;

        return Rom { .Gba = rom };
    }

    nds_blk: {
        var rom_file = %return io.File.openRead(file_path, null);
        var rom = nds.Rom.fromFile(&rom_file, allocator) %% break :nds_blk;

        return Rom { .Nds = rom };
    }
    
    return error.NotARom;
}

error UnsupportedGame;

pub fn main() -> %void {
    var stdout = %return io.getStdOut();
    var stdout_file_stream = io.FileOutStream.init(&stdout);
    var stdout_stream = &stdout_file_stream.stream;
    const allocator = std.heap.c_allocator;

    const argsWithExe = %return os.argsAlloc(allocator);
    defer os.argsFree(allocator, argsWithExe);

    const exeFile = %return utils.first([]const u8, argsWithExe);
    const inFile  = %return utils.first([]const u8, argsWithExe[1..]);
    const outFile = %return utils.first([]const u8, argsWithExe[2..]);
    const args = argsWithExe[3..];

    var rom = loadRom(inFile, allocator) %% |err| {
        switch (err) {
            error.NotARom => {
                %return stdout_stream.print("{} is not a rom.\n", inFile);
            },
            else => {
                // TODO: This could also be an allocation error.
                //       Follow issue https://github.com/zig-lang/zig/issues/632
                //       and refactor when we can check if error is part of an error set.
                %return stdout_stream.print("Unable to open {}.\n", inFile);
            }
        }

        return err;
    };
    defer rom.destroy(allocator);

    switch (rom) {
        Rom.Gba => |*gba_rom| {
            var gen3_game = gen3.Game.fromRom(gba_rom) %% |err| {
                %return stdout_stream.print("Invalide generation 3 pokemon game.\n");
                return err;
            };
        },
        Rom.Nds => |*nds_rom| {
            %return nds_rom.root.tree(stdout_stream, 0);
            %return stdout_stream.print("Rom type not supported (yet)\n");
        },
        else => {
            %return stdout_stream.print("Rom type not supported (yet)\n");
        }
    }
}