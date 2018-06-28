const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const randomizer = b.addExecutable("randomizer", "src/main.zig");
    randomizer.setBuildMode(mode);
    randomizer.addPackagePath("crc", "lib/zig-crc/crc.zig");
    randomizer.addPackagePath("fun", "lib/fun-with-zig/src/index.zig");
    randomizer.addPackagePath("blz", "lib/blz/blz.zig");

    const randomizer_step = b.step("randomizer", "Build randomizer");
    randomizer_step.dependOn(&randomizer.step);

    const offset_finder = b.addExecutable("offset-finder", "tools/offset-finder/main.zig");
    offset_finder.setBuildMode(mode);
    offset_finder.addPackagePath("gba", "src/gba.zig");
    offset_finder.addPackagePath("gb", "src/gb.zig");
    offset_finder.addPackagePath("int", "src/int.zig");
    offset_finder.addPackagePath("utils", "src/utils/index.zig");
    offset_finder.addPackagePath("pokemon", "src/pokemon/index.zig");
    offset_finder.addPackagePath("fun", "lib/fun-with-zig/src/index.zig");

    const nds_util = b.addExecutable("nds-util", "tools/nds-util/main.zig");
    nds_util.setBuildMode(mode);
    nds_util.addPackagePath("crc", "lib/zig-crc/crc.zig");
    nds_util.addPackagePath("fun", "lib/fun-with-zig/src/index.zig");
    nds_util.addPackagePath("blz", "lib/blz/blz.zig");
    nds_util.addPackagePath("utils", "src/utils/index.zig");

    // TODO: When https://github.com/zig-lang/zig/issues/855 is fixed. Add this line.
    // nds_util.addPackagePath("nds", "src/nds/index.zig");

    const tools_step = b.step("tools", "Build tools");
    tools_step.dependOn(&offset_finder.step);
    tools_step.dependOn(&nds_util.step);

    const src_tests = b.addTest("src/test.zig");
    const test_tests = b.addTest("test/index.zig");

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&src_tests.step);
    test_step.dependOn(&test_tests.step);

    const all_step = b.step("all", "Build everything and runs all tests");
    all_step.dependOn(randomizer_step);
    all_step.dependOn(tools_step);
    all_step.dependOn(test_step);

    b.default_step.dependOn(randomizer_step);
}
