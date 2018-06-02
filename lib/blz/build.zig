const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const cblz = b.addCObject("cblz", "blz.c");
    cblz.setBuildMode(mode);

    const zblz = b.addExecutable("blz_test", "main.zig");
    zblz.setBuildMode(mode);
    zblz.addObject(cblz);

    b.addCIncludePath(".");
    b.default_step.dependOn(&zblz.step);
}
