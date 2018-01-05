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
        var rom = nds.Rom.fromFile(&rom_file, allocator) %% |err| {
            debug.warn("{}\n", @errorName(err));
            break :nds_blk;
        };

        return Rom { .Nds = rom };
    }
    
    return error.NotARom;
}

error UnsupportedGame;

pub fn main() -> %void {
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
                debug.warn("{} is not a rom.\n", inFile);
            },
            else => {
                // TODO: This could also be an allocation error.
                //       Follow issue https://github.com/zig-lang/zig/issues/632
                //       and refactor when we can check if error is part of an error set.
                debug.warn("Unable to open {}.\n", inFile);
            }
        }

        return err;
    };

    switch (rom) {
        Rom.Gba => |*gba_rom| {
            var gen3_game = gen3.Game.fromRom(gba_rom) %% |err| {
                debug.warn("Invalide generation 3 pokemon game.\n");
                return err;
            };
        },
        else => {
            debug.warn("Rom type not supported (yet)\n");
        }
    }
}