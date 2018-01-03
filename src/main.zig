const std = @import("std");
const os = std.os;
const debug = std.debug;
const path = os.path;

const Version = @import("version.zig").Version;
const ChildProcess = os.ChildProcess;
const File = std.io.File;

error NoFirst;

fn first(args: []const []const u8) -> %[]const u8 {
    if (args.len > 0) {
        return args[0];
    } else {
        return error.NoFirst;
    }
}

pub fn readableVersion(version: Version) -> []const u8 {
    const V = Version;
    return switch (version) {
        V.Red, V.Blue, V.Yellow, V.Gold, 
        V.Silver, V.Crystal, V.Ruby, V.Sapphire, 
        V.Emerald, V.Diamond, V.Pearl, V.Platinum, 
        V.Black, V.White, V.X, V.Y, V.Sun, V.Moon, => @tagName(version),

        V.FireRed,      => "Fire Red",
        V.LeafGreen     => "Leaf Green",
        V.HeartGold     => "Heart Gold", 
        V.SoulSilver    => "Soul Silver",
        V.Black2        => "Black 2", 
        V.White2        => "White 2",
        V.OmegaRuby     => "Omega Ruby", 
        V.AlphaSapphire => "Alpha Sapphire",
        V.UltraSun      => "Ultra Sun",
        V.UltraMoon     => "Ultra Moon", 
        else            => unreachable
    };
}

error UnsupportedGame;

pub fn main() -> %void {
    const allocator = std.heap.c_allocator;

    const argsWithExe = %return os.argsAlloc(allocator);
    defer os.argsFree(allocator, argsWithExe);

    const exeFile = %return first(argsWithExe);
    const inFile  = %return first(argsWithExe[1..]);
    const outFile = %return first(argsWithExe[2..]);
    const args = argsWithExe[3..];

    var rom = File.openRead(inFile, null) %% |err| {
        debug.warn("Could not open file.\n");
        return err;
    };

    const version = Version.fromFile(&rom) %% |err| {
        rom.close();
        debug.warn("Unable to determin the pokémon version of {}.\n", inFile);
        return err;
    };
    rom.close();

    switch (version.gen()) {
        4, 5 => {
            
        },
        else => {
            debug.warn("Randomizing Pokémon {} is not supported yet.", readableVersion(version));
            return error.UnsupportedGame;
        }
    }
}