const std = @import("std");
const gba = @import("gba.zig");
const utils = @import("utils.zig");
const gen3 = @import("pokemon/gen3.zig");
const os = std.os;
const debug = std.debug;
const mem = std.mem;
const io = std.io;
const path = os.path;

const Version = @import("version.zig").Version;
const File = io.File;
const FileInStream = io.FileInStream;

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

    const exeFile = %return utils.first([]const u8, argsWithExe);
    const inFile  = %return utils.first([]const u8, argsWithExe[1..]);
    const outFile = %return utils.first([]const u8, argsWithExe[2..]);
    const args = argsWithExe[3..];

    var rom_file = File.openRead(inFile, null) %% |err| {
        debug.warn("Could not open file.\n");
        return err;
    };
    defer rom_file.close();

    var file_stream = FileInStream.init(&rom_file);
    var rom = gba.Rom.fromStream(&file_stream.stream, allocator) %% |err| {
        debug.warn("Unable to load gba rom.\n");
        return err;
    };

    var gen3_game = gen3.Game.fromRom(&rom) %% |err| {
        debug.warn("Invalide generation 3 pokemon game.\n");
        return err;
    };
}