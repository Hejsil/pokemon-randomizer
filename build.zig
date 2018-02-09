const Builder = @import("std").build.Builder;

pub fn build(b: &Builder) void {
    const randomizer_step = b.step("randomizer", "Build randomizer");
    const randomizer = b.addExecutable("randomizer", "src/main.zig");
    randomizer.addPackagePath("crc", "lib/zig-crc/crc.zig");
    randomizer_step.dependOn(&randomizer.step);

    const tools_step = b.step("tools", "Build tools");
    const offset_finder = b.addExecutable("gen3-offset-finder", "tools/gen3-offset-finder/main.zig");
    offset_finder.addPackagePath("gba", "src/gba.zig");
    tools_step.dependOn(&offset_finder.step);

    // TODO: We need to be able to addPackagePath to tests, or else
    //       tests wont be aple find "crc".
    const tests = b.addTest("src/test.zig");
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&tests.step);

    b.default_step.dependOn(randomizer_step);
    b.default_step.dependOn(tools_step);
    b.default_step.dependOn(test_step);
}