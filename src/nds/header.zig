const std    = @import("std");
const crc    = @import("crc");
const ascii  = @import("../ascii.zig");
const utils  = @import("../utils.zig");
const little = @import("../little.zig");

const debug = std.debug;
const mem   = std.mem;
const io    = std.io;

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

    pub fn isDsi(self: &const Header) bool {
        return (self.unitcode & 0x02) != 0;
    }

    pub fn calcChecksum(header: &const Header) u16 {
        return crc_modbus.checksum(utils.asConstBytes(Header, header)[0..0x15E]);
    }

    pub fn validate(self: &const Header) !void {
        if (self.header_checksum.get() != self.calcChecksum())
            return error.InvalidHeaderChecksum;

        if (!utils.all(u8, self.game_title, isUpperAsciiOrZero))
            return error.InvalidGameTitle;
        if (!utils.all(u8, self.gamecode, ascii.isUpperAscii))
            return error.InvalidGamecode;
        if (!utils.all(u8, self.makercode, ascii.isUpperAscii))
            return error.InvalidMakercode;
        if (self.unitcode > 0x03)
            return error.InvalidUnitcode;
        if (self.encryption_seed_select > 0x07)
            return error.InvalidEncryptionSeedSelect;

        if (!utils.all(u8, self.reserved1, ascii.isZero))
            return error.InvalidReserved1;

        // It seems that arm9 (secure area) is always at 0x4000
        // http://problemkaputt.de/gbatek.htm#dscartridgesecurearea
        if (self.arm9_rom_offset.get() != 0x4000)
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
        if (self.arm7_size.get() > 0x3BFE00)
            return error.InvalidArm7Size;

        if (utils.between(u32, self.banner_offset.get(), 0x1, 0x7FFF))
            return error.InvalidIconTitleOffset;

        if (self.secure_area_delay.get() != 0x051E and self.secure_area_delay.get() != 0x0D7E)
            return error.InvalidSecureAreaDelay;

        if (self.rom_header_size.get() != 0x4000)
            return error.InvalidRomHeaderSize;

        if (self.isDsi()) {
            const dsi_reserved = []u8 {
                0xB8, 0xD0, 0x04, 0x00,
                0x44, 0x05, 0x00, 0x00,
                0x16, 0x00, 0x16, 0x00
            };

            if (!mem.eql(u8, self.reserved3[0..12], dsi_reserved))
                return error.InvalidReserved3;
            if (!utils.all(u8, self.reserved3[12..], ascii.isZero))
                return error.InvalidReserved3;
        } else {
            if (!utils.all(u8, self.reserved3[12..], ascii.isZero))
                return error.InvalidReserved3;
        }

        if (!utils.all(u8, self.reserved4, ascii.isZero))
            return error.InvalidReserved4;
        if (!utils.all(u8, self.reserved5, ascii.isZero))
            return error.InvalidReserved5;

        if (self.isDsi()) {
            if (!utils.all(u8, self.reserved6, ascii.isZero))
                return error.InvalidReserved6;
            if (!utils.all(u8, self.reserved7, ascii.isZero))
                return error.InvalidReserved7;

            // TODO: (usually same as ARM9 rom offs, 0004000h)
            //       Does that mean that it also always 0x4000?
            if (self.digest_ntr_region_offset.get() != 0x4000)
                return error.InvalidDigestNtrRegionOffset;
            if (!mem.eql(u8, self.reserved8, []u8 { 0x00, 0x00, 0x01, 0x00 }))
                return error.InvalidReserved8;
            if (!utils.all(u8, self.reserved9, ascii.isZero))
                return error.InvalidReserved9;
            if (!mem.eql(u8, self.reserved10, []u8 { 0x84, 0xD0, 0x04, 0x00 }))
                return error.InvalidReserved10;
            if (!mem.eql(u8, self.reserved11, []u8 { 0x2C, 0x05, 0x00, 0x00 }))
                return error.InvalidReserved11;
            if (!mem.eql(u8, self.title_id_rest, []u8 { 0x00, 0x03, 0x00 }))
                return error.InvalidTitleIdRest;
            if (!utils.all(u8, self.reserved12, ascii.isZero))
                return error.InvalidReserved12;
            if (!utils.all(u8, self.reserved16, ascii.isZero))
                return error.InvalidReserved16;
            if (!utils.all(u8, self.reserved17, ascii.isZero))
                return error.InvalidReserved17;
            if (!utils.all(u8, self.reserved18, ascii.isZero))
                return error.InvalidReserved18;
        }
    }

    fn isUpperAsciiOrZero(char: u8) bool {
        return ascii.isUpperAscii(char) or char == 0;
    }
};