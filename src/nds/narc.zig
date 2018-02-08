const little = @import("../little.zig");
const Little   = little.Little;

pub const Header = packed struct {
    chunk_name: [4]u8,
    byte_order: Little(u16),
    version: Little(u16),
    file_size: Little(u32),
    chunk_size: Little(u16),
    following_chunks: Little(u16),
};

pub const Chunk = packed struct {
    name: [4]u8,
    size: Little(u32),

    const names = struct {
        const narc      = "NARC";
        const fat       = "BTAF";
        const fnt       = "BTNF";
        const file_data = "GMIF";
    };
};