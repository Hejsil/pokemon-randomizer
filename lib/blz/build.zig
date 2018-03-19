const Builder = @import("std").build.Builder;

// TODO: Move this into main build.zig when I have it working
pub fn build(b: &Builder) void {
    const zig_blz = b.addObject("blz_wrapper", "blz_wrapper.zig");
    const fuzz = b.addCExecutable("fuzz");
    fuzz.addSourceFile("fuzz.c");
    fuzz.addSourceFile("blz.c");
    fuzz.addObject(zig_blz);

    fuzz.addCompileFlags([][]const u8 { "-g", "-fsanitize=fuzzer" });

    const step = b.step("fuzz", "Fuzz test the blz library");
    step.dependOn(&fuzz.step);
}
