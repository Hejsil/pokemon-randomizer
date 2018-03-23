const std    = @import("std");
const crc    = @import("crc");
const ascii  = @import("../ascii.zig");
const little = @import("../little.zig");
const utils  = @import("../utils/index.zig");

const debug = std.debug;
const mem   = std.mem;
const io    = std.io;
const slice = utils.slice;

const assert = debug.assert;

const toLittle = little.toLittle;
const Little   = little.Little;


pub const crc_modbus = comptime blk: {
    @setEvalBranchQuota(crc.crcspec_init_backward_cycles);
    break :blk crc.CrcSpec(u16).init(0x8005, 0xFFFF, 0x0000, true, true);
};

test "nds.crc_modbus" {
    assert(crc_modbus.checksum("123456789") == 0x4B37);
}

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

    banner_offset: Little(u32),

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

    banner_size: Little(u32),

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

    pub fn isDsi(header: &const Header) bool {
        return (header.unitcode & 0x02) != 0;
    }

    pub fn calcChecksum(header: &const Header) u16 {
        return crc_modbus.checksum(utils.toBytes(Header, header)[0..0x15E]);
    }

    pub fn validate(header: &const Header) !void {
        if (header.header_checksum.get() != header.calcChecksum())
            return error.InvalidHeaderChecksum;

        if (!slice.all(header.game_title[0..], isUpperAsciiOrZero))
            return error.InvalidGameTitle;
        if (!slice.all(header.gamecode[0..], ascii.isUpperAscii))
            return error.InvalidGamecode;
        if (!slice.all(header.makercode[0..], ascii.isUpperAscii))
            return error.InvalidMakercode;
        if (header.unitcode > 0x03)
            return error.InvalidUnitcode;
        if (header.encryption_seed_select > 0x07)
            return error.InvalidEncryptionSeedSelect;

        if (!slice.all(header.reserved1[0..], ascii.isZero))
            return error.InvalidReserved1;

        // It seems that arm9 (secure area) is always at 0x4000
        // http://problemkaputt.de/gbatek.htm#dscartridgesecurearea
        if (header.arm9_rom_offset.get() != 0x4000)
            return error.InvalidArm9RomOffset;
        if (!(0x2000000 <= header.arm9_entry_address.get() and header.arm9_entry_address.get() <= 0x23BFE00))
            return error.InvalidArm9EntryAddress;
        if (!(0x2000000 <= header.arm9_ram_address.get() and header.arm9_ram_address.get() <= 0x23BFE00))
            return error.InvalidArm9RamAddress;
        if (header.arm9_size.get() > 0x3BFE00)
            return error.InvalidArm9Size;

        if (header.arm7_rom_offset.get() < 0x8000)
            return error.InvalidArm7RomOffset;
        if (!(0x2000000 <= header.arm7_entry_address.get() and header.arm7_entry_address.get() <= 0x23BFE00) and
            !(0x37F8000 <= header.arm7_entry_address.get() and  header.arm7_entry_address.get() <= 0x3807E00))
            return error.InvalidArm7EntryAddress;
        if (!(0x2000000 <= header.arm7_ram_address.get() and header.arm7_ram_address.get() <= 0x23BFE00) and
            !(0x37F8000 <= header.arm7_ram_address.get() and header.arm7_ram_address.get() <= 0x3807E00))
            return error.InvalidArm7RamAddress;
        if (header.arm7_size.get() > 0x3BFE00)
            return error.InvalidArm7Size;

        if ((0x1 <= header.banner_offset.get() and header.banner_offset.get() <= 0x7FFF))
            return error.InvalidIconTitleOffset;

        if (header.secure_area_delay.get() != 0x051E and header.secure_area_delay.get() != 0x0D7E)
            return error.InvalidSecureAreaDelay;

        if (header.rom_header_size.get() != 0x4000)
            return error.InvalidRomHeaderSize;

        if (!slice.all(header.reserved3[12..], ascii.isZero))
            return error.InvalidReserved3;

        if (!slice.all(header.reserved4[0..], ascii.isZero))
            return error.InvalidReserved4;
        if (!slice.all(header.reserved5[0..], ascii.isZero))
            return error.InvalidReserved5;

        if (header.isDsi()) {
            if (!slice.all(header.reserved6[0..], ascii.isZero))
                return error.InvalidReserved6;
            if (!slice.all(header.reserved7[0..], ascii.isZero))
                return error.InvalidReserved7;

            // TODO: (usually same as ARM9 rom offs, 0004000h)
            //       Does that mean that it also always 0x4000?
            if (header.digest_ntr_region_offset.get() != 0x4000)
                return error.InvalidDigestNtrRegionOffset;
            if (!mem.eql(u8, header.reserved8, []u8 { 0x00, 0x00, 0x01, 0x00 }))
                return error.InvalidReserved8;
            if (!slice.all(header.reserved9[0..], ascii.isZero))
                return error.InvalidReserved9;
            if (!mem.eql(u8, header.title_id_rest, []u8 { 0x00, 0x03, 0x00 }))
                return error.InvalidTitleIdRest;
            if (!slice.all(header.reserved12[0..], ascii.isZero))
                return error.InvalidReserved12;
            if (!slice.all(header.reserved16[0..], ascii.isZero))
                return error.InvalidReserved16;
            if (!slice.all(header.reserved17[0..], ascii.isZero))
                return error.InvalidReserved17;
            if (!slice.all(header.reserved18[0..], ascii.isZero))
                return error.InvalidReserved18;
        }
    }

    fn isUpperAsciiOrZero(char: &const u8) bool {
        return ascii.isUpperAscii(char) or *char == 0;
    }
};
