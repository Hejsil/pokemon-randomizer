const std = @import("std");
const os = std.os;
const path = os.path;
const debug = std.debug;
const ChildProcess = os.ChildProcess;

error NoFirst;

fn first(args: []const []const u8) -> %[]const u8 {
    if (args.len > 0) {
        return args[0];
    } else {
        return error.NoFirst;
    }
}

pub fn main() -> %void {
    const allocator = std.heap.c_allocator;

    const argsWithExe = %return os.argsAlloc(allocator);
    defer os.argsFree(allocator, argsWithExe);

    const exeFile = %return first(argsWithExe);
    const inFile  = %return first(argsWithExe[1..]);
    const outFile = %return first(argsWithExe[2..]);
    const args = argsWithExe[3..];

    const exeDir = path.dirname(exeFile);
    const outDir = %return path.join(allocator, exeDir, "out");
    defer allocator.free(outDir);
    
    const ndstoolFile = %return path.join(allocator, exeDir, "ndstool.exe");
    defer allocator.free(ndstoolFile);

    const arm9File = %return path.join(allocator, outDir, "arm9.bin");
    defer allocator.free(arm9File);

    const arm7File = %return path.join(allocator, outDir, "arm7.bin");
    defer allocator.free(arm7File);

    const y9File = %return path.join(allocator, outDir, "y9.bin");
    defer allocator.free(y9File);

    const y7File = %return path.join(allocator, outDir, "y7.bin");
    defer allocator.free(y7File);

    const dataDir = %return path.join(allocator, outDir, "data");
    defer allocator.free(dataDir);

    const overlayDir = %return path.join(allocator, outDir, "overlay");
    defer allocator.free(overlayDir);

    const bannerFile = %return path.join(allocator, outDir, "banner.bin");
    defer allocator.free(bannerFile);

    const headerFile = %return path.join(allocator, outDir, "header.bin");
    defer allocator.free(headerFile);

    const extractProc = %%ChildProcess.init(
        [][]const u8 {
            ndstoolFile,
            "-x", inFile,
            "-9", arm9File, 
            "-7", arm7File, 
            "-y9", y9File, 
            "-y7", y7File, 
            "-d", dataDir,
            "-y", overlayDir,
            "-t", bannerFile,
            "-h", headerFile
        }, allocator);
    defer extractProc.deinit();

    _ = %%extractProc.spawnAndWait();

    // TODO: Modify files

    const createProc = %%ChildProcess.init(
        [][]const u8 {
            ndstoolFile,
            "-c", outFile,
            "-9", arm9File, 
            "-7", arm7File, 
            "-y9", y9File, 
            "-y7", y7File, 
            "-d", dataDir,
            "-y", overlayDir,
            "-t", bannerFile,
            "-h", headerFile
        }, allocator);
    defer createProc.deinit();
    
    _ = %%createProc.spawnAndWait();
}