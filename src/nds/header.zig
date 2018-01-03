const Little = @import("little.zig").Little;
const std = @import("std");
const debug = std.debug;
const assert = debug.assert;
const utils = @import("../utils.zig");
const ascii = @import("../ascii.zig");

fn isUpperAscii(char: u8) -> bool {
    return isUpperAsciiOrZero(char) and char != 0x00;
}

fn isUpperAsciiOrZero(char: u8) -> bool {
    return !ascii.isLower(char);
}

fn isZero(char: u8) -> bool { return char == 0x00; }

error InvalidGameTitle;
error InvalidGamecode;
error InvalidMakercode;
error InvalidUnitcode;
error InvalidEncryptionSeedSelect;
error InvalidReserved1;
error InvalidArm9RomOffset;
error InvalidArm9EntryAddress;
error InvalidArm9RamAddress;
error InvalidArm9Size;
error InvalidArm7RomOffset;
error InvalidArm7EntryAddress;
error InvalidArm7RamAddress;
error InvalidArm7Size;
error InvalidIconTitleOffset;
error InvalidSecureAreaDelay;
error InvalidRomHeaderSize;
error InvalidReserved3;
error InvalidReserved4;
error InvalidReserved5;

// http://problemkaputt.de/gbatek.htm#dscartridgeheader
pub const Header = packed struct {
    game_title: [12]u8,
    gamecode:   [4]u8,
    makercode:  [2]u8,

    unitcode:               u8,
    encryption_seed_select: u8,
    device_capacity:        u8,

    reserved1: [7]u8,
    reserved2: u8, // (except, used on DSi)

    nds_region: u8,
    rom_version: u8,
    autostart:  u8,

    arm9_rom_offset:    Little(u32),
    arm9_entry_address: Little(u32),
    arm9_ram_address:   Little(u32),
    arm9_size:          Little(u32),

    arm7_rom_offset:    Little(u32),
    arm7_entry_address: Little(u32),
    arm7_ram_address:   Little(u32),
    arm7_size:          Little(u32),

    fnt_offset: Little(u32),
    fnt_size:   Little(u32),

    fat_offset: Little(u32),
    fat_size:   Little(u32),

    arm9_overlay_offset: Little(u32),
    arm9_overlay_size:   Little(u32),

    arm7_overlay_offset: Little(u32),
    arm7_overlay_size:   Little(u32),

    // TODO: Rename when I know exactly what his means.
    port_40001A4h_setting_for_normal_commands: Little(u32),
    port_40001A4h_setting_for_key1_commands:   Little(u32),

    icon_title_offset: Little(u32),
    
    secure_area_checksum: Little(u16),
    secure_area_delay:    Little(u16),

    arm9_auto_load_list_ram_address: Little(u32),
    arm7_auto_load_list_ram_address: Little(u32),
    
    secure_area_disable: Little(u64),
    total_used_rom_size: Little(u32),
    rom_header_size:     Little(u32),

    reserved3: [0x38]u8,

    nintendo_logo:          [0x9C]u8,
    nintendo_logo_checksum: Little(u16),

    header_checksum: Little(u16),

    debug_rom_offset:  Little(u32),
    debug_size:        Little(u32),
    debug_ram_address: Little(u32),

    reserved4: [4]u8,
    reserved5: [0x90]u8,

    pub fn validate(self: &const Header) -> %void {
        if (!utils.all(u8, self.game_title, isUpperAsciiOrZero)) 
            return error.InvalidGameTitle;
        if (!utils.all(u8, self.gamecode, isUpperAscii))
            return error.InvalidGamecode;
        if (!utils.all(u8, self.makercode, isUpperAscii))
            return error.InvalidMakercode;
        if (self.unitcode > 0x03)
            return error.InvalidUnitcode;
        if (self.encryption_seed_select > 0x07)
            return error.InvalidEncryptionSeedSelect;
            
        if (!utils.all(u8, self.reserved1, isZero))
            return error.InvalidReserved1;

        // (4000h and up, align 1000h) align 1000h, means we won't have 0x1111 or something?
        if (self.arm9_rom_offset.get() < 0x4000) 
            return error.InvalidArm9RomOffset;
        if (!utils.between(u32, self.arm9_entry_address.get(), 0x2000000, 0x23BFE00)) 
            return error.InvalidArm9EntryAddress;
        if (!utils.between(u32, self.arm9_ram_address.get(), 0x2000000, 0x23BFE00)) 
            return error.InvalidArm9RamAddress;
        if (self.arm9_size.get() > 0x3BFE00) 
            return error.InvalidArm9Size;

        if (self.arm7_rom_offset.get() < 0x8000) 
            return error.InvalidArm7RomOffset;
        if (!utils.between(u32, self.arm7_entry_address.get(), 0x2000000, 0x23BFE00) and
            !utils.between(u32, self.arm7_entry_address.get(), 0x37F8000, 0x3807E00)) 
            return error.InvalidArm7EntryAddress;
        if (!utils.between(u32, self.arm7_ram_address.get(), 0x2000000, 0x23BFE00) and
            !utils.between(u32, self.arm7_ram_address.get(), 0x37F8000, 0x3807E00))
            return error.InvalidArm7RamAddress;
        if (self.arm9_size.get() > 0x3BFE00) 
            return error.InvalidArm9Size;

        if (utils.between(u32, self.icon_title_offset.get(), 0x1, 0x7FFF))
            return error.InvalidIconTitleOffset;

        if (self.secure_area_delay.get() != 0x051E and self.secure_area_delay.get() != 0x0D7E)
            return error.InvalidSecureAreaDelay;

        if (self.rom_header_size.get() != 0x4000)
            return error.InvalidRomHeaderSize;
            
        // 088h 38h Reserved (zero filled) (except, [88h..93h] used on DSi)
        if (!utils.all(u8, self.reserved3[12..], isZero))
            return error.InvalidReserved3;

        if (!utils.all(u8, self.reserved4, isZero))
            return error.InvalidReserved4;
        // TODO: Pokemon Platinum did not uphold this? Since reserved5 is not
        // stored in ram on the ds, then this might not matter then.
        // if (!utils.all(u8, self.reserved5, isZero))
        //     return error.InvalidReserved5;
    }
};

test "header.Header" {
    const header : Header = undefined;
    const base = @ptrToInt(&header);

    assert(@ptrToInt(&header.game_title                     ) - base == 0x000);
    assert(@ptrToInt(&header.gamecode                       ) - base == 0x00C);
    assert(@ptrToInt(&header.makercode                      ) - base == 0x010);
    assert(@ptrToInt(&header.unitcode                       ) - base == 0x012);
    assert(@ptrToInt(&header.encryption_seed_select         ) - base == 0x013);
    assert(@ptrToInt(&header.device_capacity                ) - base == 0x014);
    assert(@ptrToInt(&header.reserved1                      ) - base == 0x015);
    assert(@ptrToInt(&header.reserved2                      ) - base == 0x01C);
    assert(@ptrToInt(&header.nds_region                     ) - base == 0x01D);
    assert(@ptrToInt(&header.rom_version                    ) - base == 0x01E);
    assert(@ptrToInt(&header.autostart                      ) - base == 0x01F);
    assert(@ptrToInt(&header.arm9_rom_offset                ) - base == 0x020);
    assert(@ptrToInt(&header.arm9_entry_address             ) - base == 0x024);
    assert(@ptrToInt(&header.arm9_size                      ) - base == 0x02C);
    assert(@ptrToInt(&header.arm7_rom_offset                ) - base == 0x030);
    assert(@ptrToInt(&header.arm7_entry_address             ) - base == 0x034);
    assert(@ptrToInt(&header.arm7_size                      ) - base == 0x03C);
    assert(@ptrToInt(&header.fnt_offset                     ) - base == 0x040);
    assert(@ptrToInt(&header.fnt_size                       ) - base == 0x044);
    assert(@ptrToInt(&header.fat_offset                     ) - base == 0x048);
    assert(@ptrToInt(&header.fat_size                       ) - base == 0x04C);
    assert(@ptrToInt(&header.arm9_overlay_offset            ) - base == 0x050);
    assert(@ptrToInt(&header.arm9_overlay_size              ) - base == 0x054);
    assert(@ptrToInt(&header.arm7_overlay_offset            ) - base == 0x058);
    assert(@ptrToInt(&header.arm7_overlay_size              ) - base == 0x05C);
    assert(@ptrToInt(&header.port_40001A4h_setting_for_normal_commands) - base == 0x060);
    assert(@ptrToInt(&header.port_40001A4h_setting_for_key1_commands  ) - base == 0x064);
    assert(@ptrToInt(&header.icon_title_offset              ) - base == 0x068);
    assert(@ptrToInt(&header.secure_area_checksum           ) - base == 0x06C);
    assert(@ptrToInt(&header.secure_area_delay              ) - base == 0x06E);
    assert(@ptrToInt(&header.arm9_auto_load_list_ram_address) - base == 0x070);
    assert(@ptrToInt(&header.arm7_auto_load_list_ram_address) - base == 0x074);
    assert(@ptrToInt(&header.secure_area_disable            ) - base == 0x078);
    assert(@ptrToInt(&header.total_used_rom_size            ) - base == 0x080);
    assert(@ptrToInt(&header.rom_header_size                ) - base == 0x084);
    assert(@ptrToInt(&header.reserved3                      ) - base == 0x088);
    assert(@ptrToInt(&header.nintendo_logo                  ) - base == 0x0C0);
    assert(@ptrToInt(&header.nintendo_logo_checksum         ) - base == 0x15C);
    assert(@ptrToInt(&header.header_checksum                ) - base == 0x15E);
    assert(@ptrToInt(&header.debug_rom_offset               ) - base == 0x160);
    assert(@ptrToInt(&header.debug_size                     ) - base == 0x164);
    assert(@ptrToInt(&header.debug_ram_address              ) - base == 0x168);
    assert(@ptrToInt(&header.reserved4                      ) - base == 0x16C);
    assert(@ptrToInt(&header.reserved5                      ) - base == 0x170);
    assert(@sizeOf(Header) == 0x170 + 0x90);
}