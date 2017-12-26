const Builder = @import("std").build.Builder;

pub fn build(b: &Builder) {
    const ndstool = b.addCExecutable("ndstool.exe");
    ndstool.linkSystemLibrary("stdc++");
    ndstool.addCompileFlags([][]const u8 { "-DPACKAGE_VERSION=\"2.1.0\"" });

    const files = [][]const u8 {
        "banner.cpp",
        "bigint.cpp",
        "compile_date.c",
        "crc.cpp",
        "default_icon.c",
        "elf.cpp",
        "encryption.cpp",
        "header.cpp",
        "hook.cpp",
        "loadme.c",
        "logo.cpp",
        "ndscodes.cpp",
        "ndscreate.cpp",
        "ndsextract.cpp",
        "ndstool.cpp",
        "ndstree.cpp",
        "raster.cpp",
        "sha1.cpp"
    };

    inline for (files) |file| {
        ndstool.addSourceFile("ndstool/source/" ++ file);
    }

    const randomizer = b.addExecutable("randomizer", "src/main.zig");
    randomizer.linkSystemLibrary("c");

    b.default_step.dependOn(&ndstool.step);
    b.default_step.dependOn(&randomizer.step);
}