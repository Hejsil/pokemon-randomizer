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
        var rom_file = %return io.File.openRead(file_path, null);
        var rom = gen3.Game.fromFile(&rom_file, allocator) catch {
            rom_file.close();
            break :gba_blk;
        };
        rom_file.close();

        return Rom { .Gba = rom };
    }

    nds_blk: {
        var rom_file = %return io.File.openRead(file_path, null);
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
    var stdout = %return io.getStdOut();
    var stdout_file_stream = io.FileOutStream.init(&stdout);
    var stdout_stream = &stdout_file_stream.stream;
    const allocator = std.heap.c_allocator;

    const argsWithExe = %return os.argsAlloc(allocator);
    defer os.argsFree(allocator, argsWithExe);

    const exe_path = %return utils.first([]const u8, argsWithExe);
    const in_path  = %return utils.first([]const u8, argsWithExe[1..]);
    const out_path = %return utils.first([]const u8, argsWithExe[2..]);
    const args = argsWithExe[3..];

    var rom = loadRom(in_path, allocator) catch |err| {
        switch (err) {
            error.NotARom => {
                %return stdout_stream.print("{} is not a rom.\n", in_path);
            },
            else => {
                // TODO: This could also be an allocation error.
                //       Follow issue https://github.com/zig-lang/zig/issues/632
                //       and refactor when we can check if error is part of an error set.
                %return stdout_stream.print("Unable to open {}.\n", in_path);
            }
        }

        return err;
    };
    defer rom.destroy(allocator);

    switch (rom) {
        Rom.Gba => |*gen3_rom| {
            var adapter = gen3.GameAdapter.init(gen3_rom);
            var random = rand.Rand.init(0);
            randomizer.randomizeStats(&adapter.base, &random) catch |err| {
                %return stdout_stream.print("Couldn't randomize stats.\n");
                return err;
            };

            var out_file = io.File.openWrite(out_path, null) catch |err| {
                %return stdout_stream.print("Couldn't open {}.\n", out_path);
                return err;
            };
            defer out_file.close();

            var file_stream = io.FileOutStream.init(&out_file);
            gen3_rom.writeToStream(&file_stream.stream) catch |err| {
                %return stdout_stream.print("Unable to write gba to {}.\n", out_path);
                return err;
            };
        },
        Rom.Nds => |*nds_rom| {
            var before = io.File.openWrite("before", null) catch |err| {
                %return stdout_stream.print("Couldn't open {}.\n", out_path);
                return err;
            };
            defer before.close();

            var before_file_stream = io.FileOutStream.init(&before);
            var before_stream = &before_file_stream.stream;
            %return nds_rom.header.prettyPrint(before_stream);

            var out_file = io.File.openWrite(out_path, null) catch |err| {
                %return stdout_stream.print("Couldn't open {}.\n", out_path);
                return err;
            };
            defer out_file.close();

            nds_rom.writeToFile(&out_file) catch |err| {
                %return stdout_stream.print("Unable to write nds to {}: {}\n", out_path, @errorName(err));
                return err;
            };

            var after = io.File.openWrite("after", null) catch |err| {
                %return stdout_stream.print("Couldn't open {}.\n", out_path);
                return err;
            };
            defer after.close();
            var after_file_stream = io.FileOutStream.init(&after);
            var after_stream = &after_file_stream.stream;
            %return nds_rom.header.prettyPrint(after_stream);
        },
        else => {
            %return stdout_stream.print("Rom type not supported (yet)\n");
        }
    }
}