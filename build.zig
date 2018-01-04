const Builder = @import("std").build.Builder;

pub fn build(b: &Builder) {
    const randomizer = b.addExecutable("randomizer", "src/main.zig");
    randomizer.linkSystemLibrary("c");
    
    b.default_step.dependOn(&randomizer.step);
}