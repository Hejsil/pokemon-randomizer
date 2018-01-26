const Builder = @import("std").build.Builder;

pub fn build(b: &Builder) %void {
    const randomizer = b.addExecutable("randomizer", "src/main.zig");
    randomizer.addPackagePath("crc", "lib/zig-crc/crc.zig");
    b.default_step.dependOn(&randomizer.step);
}