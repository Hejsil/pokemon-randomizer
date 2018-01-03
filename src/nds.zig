const std = @import("std");
const builtin = @import("builtin");
const utils = @import("utils.zig");
const ascii = @import("ascii.zig");
const debug = std.debug;
const mem = std.mem;
const assert = debug.assert;

/// A data structure representing an Little Endian Integer
pub fn Little(comptime Int: type) -> type {
    comptime debug.assert(@typeId(Int) == builtin.TypeId.Int);

    return packed struct {
        const Self = this;
        bytes: [@sizeOf(Int)]u8,

        pub fn set(self: &const Self, v: Int) {
            mem.writeInt(self.bytes[0..], v, builtin.Endian.Little);
        }

        pub fn get(self: &const Self) -> Int {
            return mem.readIntLE(Int, self.bytes);
        }
    };
}

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
    port_40001A4h_setting_for_normal_commands: [4]u8,
    port_40001A4h_setting_for_key1_commands:   [4]u8,

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
    reserved5: [0x10]u8,

    // New DSi Header Entries
    wram_slots:      [20]u8,
    arm9_wram_areas: [12]u8,
    arm7_wram_areas: [12]u8,
    wram_slot_master: [3]u8,

    // 1AFh 1    ... whatever, rather not 4000247h WRAMCNT ?
    //                (above byte is usually 03h)
    //                (but, it's FCh in System Menu?)
    //                (but, it's 00h in System Settings?)
    unknown: u8,

    region_flags:   [4]u8,
    access_control: [4]u8,

    arm7_scfg_ext_setting: [4]u8,
    
    reserved6: [3]u8,

    // 1BFh 1    Flags? (usually 01h) (DSiware Browser: 0Bh)
    //         bit2: Custom Icon  (0=No/Normal, 1=Use banner.sav)
    unknown_flags: u8,

    arm9i_rom_offset: Little(u32),
    
    reserved7: [4]u8,

    arm9i_ram_load_address: Little(u32),
    arm9i_size:             Little(u32),
    arm7i_rom_offset:       Little(u32),

    device_list_arm7_ram_addr: Little(u32),

    arm7i_ram_load_address: Little(u32),
    arm7i_size:             Little(u32),

    digest_ntr_region_offset:       Little(u32),
    digest_ntr_region_length:       Little(u32),
    digest_twl_region_offset:       Little(u32),
    digest_twl_region_length:       Little(u32),
    digest_sector_hashtable_offset: Little(u32),
    digest_sector_hashtable_length: Little(u32),
    digest_block_hashtable_offset:  Little(u32),
    digest_block_hashtable_length:  Little(u32),
    digest_sector_size:             Little(u32),
    digest_block_sectorcount:       Little(u32),

    icon_title_size: Little(u32),

    reserved8: [4]u8,

    total_used_rom_size_including_dsi_area: Little(u32),

    reserved9:  [4]u8,
    reserved10: [4]u8,
    reserved11: [4]u8,

    modcrypt_area_1_offset: Little(u32),
    modcrypt_area_1_size:   Little(u32),
    modcrypt_area_2_offset: Little(u32),
    modcrypt_area_2_size:   Little(u32),

    title_id_emagcode: [4]u8,
    title_id_filetype: u8,

    // 235h 1    Title ID, Zero     (00h=Normal)
    // 236h 1    Title ID, Three    (03h=Normal, why?)
    // 237h 1    Title ID, Zero     (00h=Normal)
    title_id_rest: [3]u8,

    public_sav_filesize:  Little(u32),
    private_sav_filesize: Little(u32),

    reserved12: [176]u8,

    // Parental Control Age Ratings
    cero_japan: u8,
    esrb_us_canada: u8,

    reserved13: u8,

    usk_germany: u8,
    pegi_pan_europe: u8,

    resereved14: u8,

    pegi_portugal: u8,
    pegi_and_bbfc_uk: u8,
    agcb_australia: u8,
    grb_south_korea: u8,

    reserved15: [6]u8,

    // SHA1-HMACS and RSA-SHA1
    arm9_hash_with_secure_area: [20]u8,
    arm7_hash:                  [20]u8,
    digest_master_hash:         [20]u8,
    icon_title_hash:            [20]u8,
    arm9i_hash:                 [20]u8,
    arm7i_hash:                 [20]u8,

    reserved16: [40]u8,

    arm9_hash_without_secure_area: [20]u8,

    reserved17: [2636]u8,
    reserved18: [0x180]u8,

    signature_across_header_entries: [0x80]u8,

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
            
        
    }
};

test "nds.Header: Offsets" {
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
    assert(@ptrToInt(&header.wram_slots                     ) - base == 0x180);
    assert(@ptrToInt(&header.arm9_wram_areas                ) - base == 0x194);
    assert(@ptrToInt(&header.arm7_wram_areas                ) - base == 0x1A0);
    assert(@ptrToInt(&header.wram_slot_master               ) - base == 0x1AC);
    assert(@ptrToInt(&header.unknown                        ) - base == 0x1AF);
    assert(@ptrToInt(&header.region_flags                   ) - base == 0x1B0);
    assert(@ptrToInt(&header.access_control                 ) - base == 0x1B4);
    assert(@ptrToInt(&header.arm7_scfg_ext_setting          ) - base == 0x1B8);
    assert(@ptrToInt(&header.reserved6                      ) - base == 0x1BC);
    assert(@ptrToInt(&header.unknown_flags                  ) - base == 0x1BF);
    assert(@ptrToInt(&header.arm9i_rom_offset               ) - base == 0x1C0);
    assert(@ptrToInt(&header.reserved7                      ) - base == 0x1C4);
    assert(@ptrToInt(&header.arm9i_ram_load_address         ) - base == 0x1C8);
    assert(@ptrToInt(&header.arm9i_size                     ) - base == 0x1CC);
    assert(@ptrToInt(&header.arm7i_rom_offset               ) - base == 0x1D0);
    assert(@ptrToInt(&header.device_list_arm7_ram_addr      ) - base == 0x1D4);
    assert(@ptrToInt(&header.arm7i_ram_load_address         ) - base == 0x1D8);
    assert(@ptrToInt(&header.arm7i_size                     ) - base == 0x1DC);
    assert(@ptrToInt(&header.digest_ntr_region_offset       ) - base == 0x1E0);
    assert(@ptrToInt(&header.digest_ntr_region_length       ) - base == 0x1E4);
    assert(@ptrToInt(&header.digest_twl_region_offset       ) - base == 0x1E8);
    assert(@ptrToInt(&header.digest_twl_region_length       ) - base == 0x1EC);
    assert(@ptrToInt(&header.digest_sector_hashtable_offset ) - base == 0x1F0);
    assert(@ptrToInt(&header.digest_sector_hashtable_length ) - base == 0x1F4);
    assert(@ptrToInt(&header.digest_block_hashtable_offset  ) - base == 0x1F8);
    assert(@ptrToInt(&header.digest_block_hashtable_length  ) - base == 0x1FC);
    assert(@ptrToInt(&header.digest_sector_size             ) - base == 0x200);
    assert(@ptrToInt(&header.digest_block_sectorcount       ) - base == 0x204);    
    assert(@ptrToInt(&header.icon_title_size                ) - base == 0x208);    
    assert(@ptrToInt(&header.reserved8                      ) - base == 0x20C);   

    assert(@ptrToInt(&header.total_used_rom_size_including_dsi_area) - base == 0x210); 

    assert(@ptrToInt(&header.reserved9                      ) - base == 0x214); 
    assert(@ptrToInt(&header.reserved10                     ) - base == 0x218); 
    assert(@ptrToInt(&header.reserved11                     ) - base == 0x21C);     
    assert(@ptrToInt(&header.modcrypt_area_1_offset         ) - base == 0x220);
    assert(@ptrToInt(&header.modcrypt_area_1_size           ) - base == 0x224);
    assert(@ptrToInt(&header.modcrypt_area_2_offset         ) - base == 0x228);
    assert(@ptrToInt(&header.modcrypt_area_2_size           ) - base == 0x22C);
    assert(@ptrToInt(&header.title_id_emagcode              ) - base == 0x230);
    assert(@ptrToInt(&header.title_id_filetype              ) - base == 0x234);
    assert(@ptrToInt(&header.title_id_rest                  ) - base == 0x235);
    assert(@ptrToInt(&header.public_sav_filesize            ) - base == 0x238);
    assert(@ptrToInt(&header.private_sav_filesize           ) - base == 0x23C);
    assert(@ptrToInt(&header.reserved12                     ) - base == 0x240);

    assert(@ptrToInt(&header.cero_japan                     ) - base == 0x2F0);
    assert(@ptrToInt(&header.esrb_us_canada                 ) - base == 0x2F1);
    assert(@ptrToInt(&header.reserved13                     ) - base == 0x2F2);
    assert(@ptrToInt(&header.usk_germany                    ) - base == 0x2F3);
    assert(@ptrToInt(&header.pegi_pan_europe                ) - base == 0x2F4);
    assert(@ptrToInt(&header.resereved14                    ) - base == 0x2F5);
    assert(@ptrToInt(&header.pegi_portugal                  ) - base == 0x2F6);
    assert(@ptrToInt(&header.pegi_and_bbfc_uk               ) - base == 0x2F7);
    assert(@ptrToInt(&header.agcb_australia                 ) - base == 0x2F8);
    assert(@ptrToInt(&header.grb_south_korea                ) - base == 0x2F9);
    assert(@ptrToInt(&header.reserved15                     ) - base == 0x2FA);

    assert(@ptrToInt(&header.arm9_hash_with_secure_area     ) - base == 0x300);
    assert(@ptrToInt(&header.arm7_hash                      ) - base == 0x314);
    assert(@ptrToInt(&header.digest_master_hash             ) - base == 0x328);
    assert(@ptrToInt(&header.icon_title_hash                ) - base == 0x33C);
    assert(@ptrToInt(&header.arm9i_hash                     ) - base == 0x350);
    assert(@ptrToInt(&header.arm7i_hash                     ) - base == 0x364);
    assert(@ptrToInt(&header.reserved16                     ) - base == 0x378);
    assert(@ptrToInt(&header.arm9_hash_without_secure_area  ) - base == 0x3A0);
    assert(@ptrToInt(&header.reserved17                     ) - base == 0x3B4);
    assert(@ptrToInt(&header.reserved18                     ) - base == 0xE00);
    assert(@ptrToInt(&header.signature_across_header_entries) - base == 0xF80);
    
    assert(@sizeOf(Header) == 0x1000);
}