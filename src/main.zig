const std        = @import("std");
const gba        = @import("gba.zig");
const nds        = @import("nds.zig");
const utils      = @import("utils.zig");
const randomizer = @import("randomizer.zig");
const clap       = @import("clap.zig");
const gen3       = @import("pokemon/gen3.zig");

const os    = std.os;
const debug = std.debug;
const mem   = std.mem;
const io    = std.io;
const rand  = std.rand;
const path  = os.path;

var input_file  : []const u8 = undefined;
var output_file : []const u8 = "randomized";

fn setInFile(op: &void, str: []const u8) -> %void { input_file = str; }
fn setOutFile(op: &void, str: []const u8) -> %void { output_file = str; }

const Arg = clap.Arg(void);
const program_arguments = comptime []Arg {
    Arg.init(setInFile)
        .help("The rom to randomize.")
        .required(true),
    Arg.init(setOutFile)
        .help("The place to output the randomized rom.")
        .short("o")
        .long("output")
        .takesValue(true)
};

pub fn main() -> %void {
    const allocator = std.heap.c_allocator;
    var stdout = try io.getStdOut();
    var stdout_file_stream = io.FileOutStream.init(&stdout);
    var stdout_stream = &stdout_file_stream.stream;

    const args = try os.argsAlloc(allocator);
    defer os.argsFree(allocator, args);

    clap.parse(void, args, void{}, program_arguments) catch |err| {
        // TODO: Write useful error message to user
        return err;
    };


    var rom = loadRom(input_file, allocator) catch |err| {
        switch (err) {
            error.NotARom => {
                try stdout_stream.print("{} is not a rom.\n", input_file);
            },
            else => {
                // TODO: This could also be an allocation error.
                //       Follow issue https://github.com/zig-lang/zig/issues/632
                //       and refactor when we can check if error is part of an error set.
                try stdout_stream.print("Unable to open {}.\n", input_file);
            }
        }

        return err;
    };
    defer rom.destroy(allocator);

    var out_file = io.File.openWrite(output_file, null) catch |err| {
        try stdout_stream.print("Couldn't open {}.\n", output_file);
        return err;
    };
    defer out_file.close();

    switch (rom) {
        Rom.Gba => |gen3_rom| {
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

            var file_stream = io.FileOutStream.init(&out_file);
            gen3_rom.writeToStream(&file_stream.stream) catch |err| {
                try stdout_stream.print("Unable to write gba to {}.\n", output_file);
                return err;
            };
        },
        Rom.Nds => |nds_rom| {
            nds_rom.writeToFile(&out_file) catch |err| {
                try stdout_stream.print("Unable to write nds to {}\n", output_file);
                return err;
            };
        },
        else => {
            try stdout_stream.print("Rom type not supported (yet)\n");
        }
    }
}

const Rom = union(enum) {
    Gba: &gen3.Game,
    Nds: &nds.Rom,

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