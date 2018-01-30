const Builder = @import("std").build.Builder;

pub fn build(b: &Builder) %void {
    const offset_finder = b.addExecutable("gen3-offset-finder", "main.zig");
    offset_finder.addPackagePath("gba", "../../src/gba.zig");
    b.default_step.dependOn(&offset_finder.step);
}