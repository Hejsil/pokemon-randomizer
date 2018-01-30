const Builder = @import("std").build.Builder;

pub fn build(b: &Builder) %void {
    const randomizer = b.addExecutable("randomizer", "src/main.zig");
    randomizer.addPackagePath("crc", "lib/zig-crc/crc.zig");
    b.default_step.dependOn(&randomizer.step);

    // TODO: We need to be able to addPackagePath to tests, or else
    //       tests wont be aple find "crc".
    const tests = b.addTest("src/test.zig");
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&tests.step);
}