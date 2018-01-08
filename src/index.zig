pub const pokemon    = @import("pokemon/index.zig");
pub const ascii      = @import("ascii.zig");
pub const gba        = @import("gba.zig");
pub const little     = @import("little.zig");
pub const nds        = @import("nds.zig");
pub const randomizer = @import("randomizer.zig");
pub const utils      = @import("utils.zig");

test "" {
    _ = @import("pokemon/index.zig");
    _ = @import("ascii.zig");
    _ = @import("gba.zig");
    _ = @import("little.zig");
    _ = @import("nds.zig");
    _ = @import("randomizer.zig");
    _ = @import("utils.zig");
}