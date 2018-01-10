const std        = @import("std");
const gba        = @import("gba.zig");
const nds        = @import("nds.zig");
const utils      = @import("utils.zig");
const randomizer = @import("randomizer.zig");
const gen3       = @import("pokemon/gen3.zig");

const os    = std.os;
const debug = std.debug;
const mem   = std.mem;
const io    = std.io;
const rand  = std.rand;
const path  = os.path;

const Rom = union(enum) {
    Gba: gen3.Game,
    Nds: nds.Rom,

    pub fn destroy(self: &const Rom, allocator: &mem.Allocator) {
        switch (*self) {
            Rom.Gba => |gen3_rom| gen3_rom.destroy(allocator),
            Rom.Nds => |nds_rom|  nds_rom.destroy(allocator),
        }
    }
};

error NotARom;

fn loadRom(file_path: []const u8, allocator: &mem.Allocator) -> %Rom {
    gba_blk: {
        var rom_file = try io.File.openRead(file_path, null);
        var rom = gen3.Game.fromFile(&rom_file, allocator) catch {
            rom_file.close();
            break :gba_blk;
        };
        rom_file.close();

        return Rom { .Gba = rom };
    }

    nds_blk: {
        var rom_file = try io.File.openRead(file_path, null);
        var rom = nds.Rom.fromFile(&rom_file, allocator) catch {
            rom_file.close();
            break :nds_blk;
        };
        rom_file.close();

        return Rom { .Nds = rom };
    }

    return error.NotARom;
}

error UnsupportedGame;

pub fn main() -> %void {
    var stdout = try io.getStdOut();
    var stdout_file_stream = io.FileOutStream.init(&stdout);
    var stdout_stream = &stdout_file_stream.stream;
    const allocator = std.heap.c_allocator;

    const argsWithExe = try os.argsAlloc(allocator);
    defer os.argsFree(allocator, argsWithExe);

    const exe_path = try utils.first([]const u8, argsWithExe);
    const in_path  = try utils.first([]const u8, argsWithExe[1..]);
    const out_path = try utils.first([]const u8, argsWithExe[2..]);
    const args = argsWithExe[3..];

    var rom = loadRom(in_path, allocator) catch |err| {
        switch (err) {
            error.NotARom => {
                try stdout_stream.print("{} is not a rom.\n", in_path);
            },
            else => {
                // TODO: This could also be an allocation error.
                //       Follow issue https://github.com/zig-lang/zig/issues/632
                //       and refactor when we can check if error is part of an error set.
                try stdout_stream.print("Unable to open {}.\n", in_path);
            }
        }

        return err;
    };
    defer rom.destroy(allocator);

    switch (rom) {
        Rom.Gba => |*gen3_rom| {
            gen3_rom.validateData() catch |err| {
                try stdout_stream.print("Warning: Invalid Pokemon game data. The rom will still be randomized, but there is no garenties that the rom will work as indented.\n");

                switch (err) {
                    error.NoBulbasaurFound => {
                        try stdout_stream.print("Note: Pokemon 001 (Bulbasaur) did not have expected stats.\n");
                        try stdout_stream.print("Note: If you are randomizing a hacked version, then .\n");
                    },
                    else => {}
                }
            };

            var adapter = gen3.GameAdapter.init(gen3_rom);
            var random = rand.Rand.init(0);
            randomizer.randomizeStats(&adapter.base, &random) catch |err| {
                try stdout_stream.print("Couldn't randomize stats.\n");
                return err;
            };

            var out_file = io.File.openWrite(out_path, null) catch |err| {
                try stdout_stream.print("Couldn't open {}.\n", out_path);
                return err;
            };
            defer out_file.close();

            var file_stream = io.FileOutStream.init(&out_file);
            gen3_rom.writeToStream(&file_stream.stream) catch |err| {
                try stdout_stream.print("Unable to write gba to {}.\n", out_path);
                return err;
            };
        },
        Rom.Nds => |*nds_rom| {
            var out_file = io.File.openWrite(out_path, null) catch |err| {
                try stdout_stream.print("Couldn't open {}.\n", out_path);
                return err;
            };
            defer out_file.close();

            nds_rom.writeToFile(&out_file) catch |err| {
                try stdout_stream.print("Unable to write nds to {}: {}\n", out_path, @errorName(err));
                return err;
            };
        },
        else => {
            try stdout_stream.print("Rom type not supported (yet)\n");
        }
    }
}