const little = @import("../little.zig");
const Little   = little.Little;
const toLittle = little.toLittle;

pub const Header = packed struct {
    chunk_name: [4]u8,
    byte_order: Little(u16),
    version: Little(u16),
    file_size: Little(u32),
    chunk_size: Little(u16),
    following_chunks: Little(u16),

    pub fn init(file_size: u32) Header {
        return Header {
            .chunk_name       = Chunk.names.narc,
            .byte_order       = toLittle(u16(0xFFFE)),
            .version          = toLittle(u16(0x0100)),
            .file_size        = toLittle(file_size),
            .chunk_size       = toLittle(u16(@sizeOf(Header))),
            .following_chunks = toLittle(u16(0x0003)),
        };
    }
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