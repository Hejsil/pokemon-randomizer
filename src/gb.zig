
pub const Header = packed struct {
    prefix: [0x100]u8,
    entry_point: [4]u8,
    logo: [0x30]u8,
    title: packed union {
        full: [16]u8,
        split: packed struct {
            title: [11]u8,
            gamecode: [4]u8,
            cgb_flag: u8,
        },
    },
    new_licensee_code: [2]u8,
    sgb_flag: u8,
    cartridge_type: u8,
    rom_size: u8,
    ram_size: u8,
    destination_code: u8,
    old_licensee_code: u8,
    rom_version_number: u8,
    header_checksum: u8,
    global_checksum: [2]u8,
};
