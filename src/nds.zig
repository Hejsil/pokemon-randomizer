const std    = @import("std");
const utils  = @import("utils.zig");
const ascii  = @import("ascii.zig");
const little = @import("little.zig");

const debug = std.debug;
const mem   = std.mem;
const io    = std.io;
const sort  = std.sort;

const assert = debug.assert;

const toLittle = little.toLittle;
const Little   = little.Little;

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
error InvalidReserved3Dsi;
error InvalidReserved4;
error InvalidReserved5;
error InvalidReserved6;
error InvalidReserved7;
error InvalidReserved8;
error InvalidReserved9;
error InvalidReserved10;
error InvalidReserved11;
error InvalidReserved12;
error InvalidReserved16;
error InvalidReserved17;
error InvalidReserved18;
error InvalidDigestNtrRegionOffset;
error InvalidTitleIdRest;

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

    pub fn isDsi(self: &const Header) -> bool {
        return (self.unitcode & 0x02) != 0;
    }

    pub fn validate(self: &const Header) -> %void {
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

        if (utils.between(u32, self.icon_title_offset.get(), 0x1, 0x7FFF))
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

    fn isUpperAsciiOrZero(char: u8) -> bool {
        return ascii.isUpperAscii(char) or char == 0;
    }

    pub fn prettyPrint(self: &const Header, stream: &io.OutStream) -> %void {
        // game_title might be \0 terminated, but we don't want to print that
        const zero_index = mem.indexOfScalar(u8, self.game_title, 0) ?? self.game_title.len;
        try stream.print("game_title: {}\n", self.game_title[0..zero_index]);
        try stream.print("gamecode: {}\n", self.gamecode);
        try stream.print("makercode: {}\n", self.makercode);

        try stream.print("unitcode: {x}\n", self.unitcode);
        try stream.print("encryption_seed_select: {x}\n", self.encryption_seed_select);
        try stream.print("encryption_seed_select: {x}\n", self.device_capacity);

        try stream.print("encryption_seed_select: {x}\n", self.device_capacity);

        try prettyPrintSliceField(u8, "reserved1", "{x}", stream, self.reserved1);

        try stream.print("reserved2: {x}\n", self.reserved2);
        
        try stream.print("nds_region: {x}\n", self.nds_region);
        try stream.print("rom_version: {x}\n", self.rom_version);
        try stream.print("autostart: {x}\n", self.autostart);

        try stream.print("arm9_rom_offset: {x}\n", self.arm9_rom_offset.get());
        try stream.print("arm9_entry_address: {x}\n", self.arm9_entry_address.get());
        try stream.print("arm9_ram_address: {x}\n", self.arm9_ram_address.get());
        try stream.print("arm9_size: {x}\n", self.arm9_size.get());

        try stream.print("arm7_rom_offset: {x}\n", self.arm7_rom_offset.get());
        try stream.print("arm7_entry_address: {x}\n", self.arm7_entry_address.get());
        try stream.print("arm7_ram_address: {x}\n", self.arm7_ram_address.get());
        try stream.print("arm7_size: {x}\n", self.arm7_size.get());

        try stream.print("fnt_offset: {x}\n", self.fnt_offset.get());
        try stream.print("fnt_size: {x}\n", self.fnt_size.get());

        try stream.print("fat_offset: {x}\n", self.fat_offset.get());
        try stream.print("fat_size: {x}\n", self.fat_size.get());

        try stream.print("arm9_overlay_offset: {x}\n", self.arm9_overlay_offset.get());
        try stream.print("arm9_overlay_size: {x}\n", self.arm9_overlay_size.get());

        try stream.print("arm7_overlay_offset: {x}\n", self.arm7_overlay_offset.get());
        try stream.print("arm7_overlay_size: {x}\n", self.arm7_overlay_size.get());

        try prettyPrintSliceField(u8, "port_40001A4h_setting_for_normal_commands", "{x}", stream, self.port_40001A4h_setting_for_normal_commands);
        try prettyPrintSliceField(u8, "port_40001A4h_setting_for_key1_commands", "{x}", stream, self.port_40001A4h_setting_for_key1_commands);

        try stream.print("icon_title_offset: {x}\n", self.icon_title_offset.get());

        try stream.print("secure_area_checksum: {x}\n", self.secure_area_checksum.get());
        try stream.print("secure_area_delay: {x}\n", self.secure_area_delay.get());

        try stream.print("arm9_auto_load_list_ram_address: {x}\n", self.arm9_auto_load_list_ram_address.get());
        try stream.print("arm7_auto_load_list_ram_address: {x}\n", self.arm7_auto_load_list_ram_address.get());

        try stream.print("secure_area_disable: {x}\n", self.secure_area_disable.get());
        try stream.print("total_used_rom_size: {x}\n", self.total_used_rom_size.get());
        try stream.print("rom_header_size: {x}\n", self.rom_header_size.get());

        try prettyPrintSliceField(u8, "reserved3", "{x}", stream, self.reserved3);
        try prettyPrintSliceField(u8, "nintendo_logo", "{x}", stream, self.nintendo_logo);

        try stream.print("nintendo_logo_checksum: {x}\n", self.nintendo_logo_checksum.get());
        try stream.print("header_checksum: {x}\n", self.header_checksum.get());

        try stream.print("debug_rom_offset: {x}\n", self.debug_rom_offset.get());
        try stream.print("debug_size: {x}\n", self.debug_size.get());
        try stream.print("debug_ram_address: {x}\n", self.debug_ram_address.get());

        try prettyPrintSliceField(u8, "reserved4", "{x}", stream, self.reserved4);
        try prettyPrintSliceField(u8, "reserved5", "{x}", stream, self.reserved5);


        try prettyPrintSliceField(u8, "wram_slots", "{x}", stream, self.wram_slots);
        try prettyPrintSliceField(u8, "arm9_wram_areas", "{x}", stream, self.arm9_wram_areas);
        try prettyPrintSliceField(u8, "arm7_wram_areas", "{x}", stream, self.arm7_wram_areas);
        try prettyPrintSliceField(u8, "wram_slot_master", "{x}", stream, self.wram_slot_master);

        try stream.print("unknown: {x}\n", self.unknown);

        try prettyPrintSliceField(u8, "region_flags", "{x}", stream, self.region_flags);
        try prettyPrintSliceField(u8, "access_control", "{x}", stream, self.access_control);
        try prettyPrintSliceField(u8, "arm7_scfg_ext_setting", "{x}", stream, self.arm7_scfg_ext_setting);
        try prettyPrintSliceField(u8, "reserved6", "{x}", stream, self.reserved6);

        try stream.print("unknown: {x}\n", self.unknown_flags);
        try stream.print("arm9i_rom_offset: {x}\n", self.arm9i_rom_offset.get());

        try prettyPrintSliceField(u8, "reserved7", "{x}", stream, self.reserved7);

        try stream.print("arm9i_ram_load_address: {x}\n", self.arm9i_ram_load_address.get());
        try stream.print("arm9i_size: {x}\n", self.arm9i_size.get());
        try stream.print("arm7i_rom_offset: {x}\n", self.arm7i_rom_offset.get());

        try stream.print("device_list_arm7_ram_addr: {x}\n", self.device_list_arm7_ram_addr.get());

        try stream.print("arm7i_ram_load_address: {x}\n", self.arm7i_ram_load_address.get());
        try stream.print("arm7i_size: {x}\n", self.arm7i_size.get());
        
        try stream.print("digest_ntr_region_offset: {x}\n", self.digest_ntr_region_offset.get());

        try stream.print("digest_ntr_region_offset: {x}\n",       self.digest_ntr_region_offset.get()      );
        try stream.print("digest_ntr_region_length: {x}\n",       self.digest_ntr_region_length.get()      );
        try stream.print("digest_twl_region_offset: {x}\n",       self.digest_twl_region_offset.get()      );
        try stream.print("digest_twl_region_length: {x}\n",       self.digest_twl_region_length.get()      );
        try stream.print("digest_sector_hashtable_offset: {x}\n", self.digest_sector_hashtable_offset.get());
        try stream.print("digest_sector_hashtable_length: {x}\n", self.digest_sector_hashtable_length.get()); 
        try stream.print("digest_block_hashtable_offset: {x}\n",  self.digest_block_hashtable_offset.get() );   
        try stream.print("digest_block_hashtable_length: {x}\n",  self.digest_block_hashtable_length.get() );    
        try stream.print("digest_sector_size: {x}\n",             self.digest_sector_size.get()            );             
        try stream.print("digest_block_sectorcount: {x}\n",       self.digest_block_sectorcount.get()      ); 

        try stream.print("icon_title_size: {x}\n", self.icon_title_size.get());

        try prettyPrintSliceField(u8, "reserved8", "{x}\n", stream, self.reserved8);

        try stream.print("total_used_rom_size_including_dsi_area: {x}\n", self.total_used_rom_size_including_dsi_area.get());

        try prettyPrintSliceField(u8, "reserved9", "{x}", stream, self.reserved9);
        try prettyPrintSliceField(u8, "reserved10", "{x}", stream, self.reserved10);
        try prettyPrintSliceField(u8, "reserved11", "{x}", stream, self.reserved11);

        try stream.print("modcrypt_area_1_offset: {x}\n", self.modcrypt_area_1_offset.get());
        try stream.print("modcrypt_area_1_size: {x}\n", self.modcrypt_area_1_size.get());
        try stream.print("modcrypt_area_2_offset: {x}\n", self.modcrypt_area_2_offset.get());
        try stream.print("modcrypt_area_2_size: {x}\n", self.modcrypt_area_2_size.get());

        try prettyPrintSliceField(u8, "title_id_emagcode", "{x}", stream, self.title_id_emagcode);

        try stream.print("title_id_filetype: {x}\n", self.title_id_filetype);

        try prettyPrintSliceField(u8, "title_id_rest", "{x}", stream, self.title_id_rest);

        try stream.print("public_sav_filesize: {x}\n", self.public_sav_filesize.get());
        try stream.print("private_sav_filesize: {x}\n", self.private_sav_filesize.get());

        try prettyPrintSliceField(u8, "reserved12", "{x}", stream, self.reserved12);

        try stream.print("cero_japan: {x}\n", self.cero_japan);
        try stream.print("esrb_us_canada: {x}\n", self.esrb_us_canada);

        try stream.print("reserved13: {x}\n", self.reserved13);

        try stream.print("usk_germany: {x}\n", self.usk_germany);
        try stream.print("pegi_pan_europe: {x}\n", self.pegi_pan_europe);

        try stream.print("resereved14: {x}\n", self.resereved14);

        try stream.print("pegi_portugal: {x}\n", self.pegi_portugal);
        try stream.print("pegi_and_bbfc_uk: {x}\n", self.pegi_and_bbfc_uk);
        try stream.print("agcb_australia: {x}\n", self.agcb_australia);
        try stream.print("grb_south_korea: {x}\n", self.grb_south_korea);

        try prettyPrintSliceField(u8, "reserved15", "{x}", stream, self.reserved15);

        try prettyPrintSliceField(u8, "arm9_hash_with_secure_area", "{x}", stream, self.arm9_hash_with_secure_area);
        try prettyPrintSliceField(u8, "arm7_hash", "{x}", stream, self.arm7_hash);
        try prettyPrintSliceField(u8, "digest_master_hash", "{x}", stream, self.digest_master_hash);
        try prettyPrintSliceField(u8, "icon_title_hash", "{x}", stream, self.icon_title_hash);
        try prettyPrintSliceField(u8, "arm9i_hash", "{x}", stream, self.arm9i_hash);
        try prettyPrintSliceField(u8, "arm7i_hash", "{x}", stream, self.arm7i_hash);

        try prettyPrintSliceField(u8, "reserved16", "{x}", stream, self.reserved16);

        try prettyPrintSliceField(u8, "arm9_hash_without_secure_area", "{x}", stream, self.arm9_hash_without_secure_area);

        try prettyPrintSliceField(u8, "reserved17", "{x}", stream, self.reserved17);
        try prettyPrintSliceField(u8, "reserved18", "{x}", stream, self.reserved18);

        try prettyPrintSliceField(u8, "signature_across_header_entries", "{x}", stream, self.signature_across_header_entries);
    }

    fn prettyPrintSliceField(comptime T: type, comptime field_name: []const u8, comptime format: []const u8, stream: &io.OutStream, slice: []const T) -> %void {
        try stream.print(field_name ++ ": ");
        try prettyPrintSlice(T, format, stream, slice);
        try stream.print("\n");
    }

    fn prettyPrintSlice(comptime T: type, comptime format: []const u8, stream: &io.OutStream, slice: []const T) -> %void {
        try stream.write("{ ");
        
        for (slice) |item, i| {
            try stream.print(format, item);

            if (i != slice.len - 1) 
                try stream.print(", ");
        }

        try stream.write(" }");
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

error InvalidVersion;
error InvalidHasAnimatedDsiIcon;
error InvalidReserved1;
error InvalidReserved2;
error InvalidChinese;
error InvalidKorean;
error InvalidIconAnimationBitmap;
error InvalidIconAnimationPalette;
error InvalidIconAnimationSequence;

pub const IconTitle = packed struct {
    pub const Version = enum(u8) {
        Original                  = toLittle(u16, 0x0001).get(),
        WithChineseTitle          = toLittle(u16, 0x0002).get(),
        WithChineseAndKoreanTitle = toLittle(u16, 0x0003).get(),
    };

    version: Version,
    has_animated_dsi_icon: bool,

    crc16_across_0020h_083Fh: Little(u16),
    crc16_across_0020h_093Fh: Little(u16),
    crc16_across_0020h_0A3Fh: Little(u16),
    crc16_across_1240h_23BFh: Little(u16),

    reserved1: [0x16]u8,

    icon_bitmap: [0x200]u8,
    icon_palette: [0x20]u8,

    title_japanese: [0x100]u8,
    title_english:  [0x100]u8,
    title_french:   [0x100]u8,
    title_german:   [0x100]u8,
    title_italian:  [0x100]u8,
    title_spanish:  [0x100]u8,
    title_chinese:  [0x100]u8,
    title_korean:   [0x100]u8,

    reserved2: [0x800]u8,

    // animated DSi icons only
    icon_animation_bitmap: [0x1000]u8,
    icon_animation_palette: [0x100]u8,
    icon_animation_sequence: [0x80]u8, // Should be [0x40]Little(u16)?

    pub fn validate(self: &const IconTitle) -> %void {
        if (!utils.between(u8, u8(self.version), 1, 3))
            return error.InvalidVersion;
        if (!utils.between(u8, u8(self.has_animated_dsi_icon), 0, 1))
            return error.InvalidHasAnimatedDsiIcon;

        if (!utils.all(u8, self.reserved1, ascii.isZero))
            return error.InvalidReserved1;

        if (self.version < Version.WithChineseTitle) {
            if (!utils.all(u8, self.chinese, ascii.isZero))
                return error.InvalidChinese;
        }

        if (self.version < Version.WithChineseAndKoreanTitle) {
            if (!utils.all(u8, self.korean, ascii.isZero))
                return error.InvalidKorean;
        }

        if (!utils.all(u8, self.reserved2, ascii.isZero))
            return error.InvalidReserved2;

        if (self.version != Version.WithChineseAndKoreanTitle) {
            if (!utils.all(u8, self.icon_animation_bitmap, ascii.is0xFF))
                return error.InvalidIconAnimationBitmap;
            if (!utils.all(u8, self.icon_animation_palette, ascii.is0xFF))
                return error.InvalidIconAnimationPalette;
            if (!utils.all(u8, self.icon_animation_sequence, ascii.is0xFF))
                return error.InvalidIconAnimationSequence;
        }
    }

    fn is0xFF(char: u8) -> bool { return char == 0xFF; }
};

test "nds.IconTitle: Offsets" {
    const icontitle : IconTitle = undefined;
    const base = @ptrToInt(&icontitle);

    assert(@ptrToInt(&icontitle.version                 ) - base == 0x0000);

    assert(@ptrToInt(&icontitle.crc16_across_0020h_083Fh) - base == 0x0002);
    assert(@ptrToInt(&icontitle.crc16_across_0020h_093Fh) - base == 0x0004);
    assert(@ptrToInt(&icontitle.crc16_across_0020h_0A3Fh) - base == 0x0006);
    assert(@ptrToInt(&icontitle.crc16_across_1240h_23BFh) - base == 0x0008);
    assert(@ptrToInt(&icontitle.reserved1               ) - base == 0x000A);

    assert(@ptrToInt(&icontitle.icon_bitmap             ) - base == 0x0020);
    assert(@ptrToInt(&icontitle.icon_palette            ) - base == 0x0220);

    assert(@ptrToInt(&icontitle.title_japanese          ) - base == 0x0240);
    assert(@ptrToInt(&icontitle.title_english           ) - base == 0x0340);
    assert(@ptrToInt(&icontitle.title_french            ) - base == 0x0440);
    assert(@ptrToInt(&icontitle.title_german            ) - base == 0x0540);
    assert(@ptrToInt(&icontitle.title_italian           ) - base == 0x0640);
    assert(@ptrToInt(&icontitle.title_spanish           ) - base == 0x0740);
    assert(@ptrToInt(&icontitle.title_chinese           ) - base == 0x0840);
    assert(@ptrToInt(&icontitle.title_korean            ) - base == 0x0940);
    assert(@ptrToInt(&icontitle.reserved2               ) - base == 0x0A40);

    assert(@ptrToInt(&icontitle.icon_animation_bitmap   ) - base == 0x1240);
    assert(@ptrToInt(&icontitle.icon_animation_palette  ) - base == 0x2240);
    assert(@ptrToInt(&icontitle.icon_animation_sequence ) - base == 0x2340);
    
    assert(@sizeOf(IconTitle) == 0x23C0);
}

error AddressesOverlap;

pub const Narc = struct {
    pub fn destroy(self: &const Narc, allocator: &mem.Allocator) {
    }
};

pub const Nitro = struct {
    pub const File = union(enum) {
        Narc: Narc,
        Other: []u8,

        pub fn destroy(self: &const File, allocator: &mem.Allocator) {
            switch (*self) {
                File.Narc => |narc| narc.destroy(allocator),
                File.Other => |data| allocator.free(data),
            }
        }
    };

    pub const Folder = struct {
        files: []Nitro,

        pub fn destroy(self: &const Folder, allocator: &mem.Allocator) {
            for (self.files) |file| file.destroy(allocator);
            allocator.free(self.files);
        }
    };

    pub const Kind = enum { Folder, File };
    pub const Data = union(Kind) { 
        Folder: Folder, 
        File: File 
    };

    name: []u8,
    data: Data,

    pub fn initFile(name: []u8, file: &const File) -> Nitro {
        return Nitro {
            .name = name,
            .data = Data {
                .File = *file
            }
        };
    }

    pub fn initFolder(name: []u8, folder: &const Folder) -> Nitro {
        return Nitro {
            .name = name,
            .data = Data {
                .Folder = *folder
            }
        };
    }

    pub fn destroy(self: &const Nitro, allocator: &mem.Allocator) {
        allocator.free(self.name);
        switch (self.data) {
            Data.Folder => |folder| folder.destroy(allocator),
            Data.File   => |file| file.destroy(allocator)
        }
    }

    pub fn tree(self: &const Nitro, stream: &io.OutStream, indent: usize) -> %void {
        var i : usize = 0;
        while (i < indent) : (i += 1) {
            try stream.write("    ");
        }

        switch (self.data) {
            Data.Folder => |folder| {
                try stream.print("{}/\n", self.name);
                for (folder.files) |file| {
                    try file.tree(stream, indent + 1);
                }
            },
            Data.File => {
                try stream.print("{}\n", self.name);
            }
        }
    }
};

error InvalidFatSize;
error InvalidFntMainTableSize;
error InvalidFntRootDirectoryId;
error InvalidFntSubDirectoryId;
error InvalidSubTableTypeLength;
error InvalidSubDirectoryId;
error InvalidFileId;
error InvalidNameLength;
error InvalidSizeInHeader;
error FailedToWriteNitroToFnt;
error FailedToWriteNitroToFat;

pub const Rom = struct {
    header: &Header,
    arm9: []u8,
    arm7: []u8,
    arm9_overlay: []u8,
    arm7_overlay: []u8,
    icon_title: &IconTitle,
    root: Nitro,

    pub fn fromFile(file: &io.File, allocator: &mem.Allocator) -> %Rom {
        const header = try utils.createAndReadNoEof(Header, file, allocator);
        %defer allocator.destroy(header);

        try header.validate();

        var arm9 = try utils.seekToAllocAndReadNoEof(u8, file, allocator, header.arm9_rom_offset.get(), header.arm9_size.get());
        %defer allocator.free(arm9);

        var arm7 = try utils.seekToAllocAndReadNoEof(u8, file, allocator, header.arm7_rom_offset.get(), header.arm7_size.get());
        %defer allocator.free(arm7);

        var arm9_overlay = try utils.seekToAllocAndReadNoEof(u8, file, allocator, header.arm9_overlay_offset.get(), header.arm9_overlay_size.get());
        %defer allocator.free(arm9_overlay);

        var arm7_overlay = try utils.seekToAllocAndReadNoEof(u8, file, allocator, header.arm7_overlay_offset.get(), header.arm7_overlay_size.get());
        %defer allocator.free(arm7_overlay);

        // TODO: On dsi, this can be of different sizes
        const icon_title = try utils.seekToCreateAndReadNoEof(IconTitle, file, allocator, header.icon_title_offset.get());
        %defer allocator.destroy(icon_title);

        try icon_title.validate();

        var root = try readFileSystem(
            file, 
            allocator, 
            header.fnt_offset.get(),
            header.fnt_size.get(),
            header.fat_offset.get(),
            header.fat_size.get());
        %defer root.destroy(allocator);

        return Rom {
            .header = header,
            .arm9 = arm9,
            .arm7 = arm7,
            .arm9_overlay = arm9_overlay,
            .arm7_overlay = arm7_overlay,
            .icon_title = icon_title,
            .root = root,
        };
    }
        
    const FatEntry = packed struct {
        start: Little(u32),
        end: Little(u32),
    };
    
    const FntMainEntry = packed struct {
        offset_to_subtable: Little(u32),
        first_id_in_subtable: Little(u16),

        // For the first entry in main-table, the parent id is actually,
        // the total number of directories (See FNT Directory Main-Table): 
        // http://problemkaputt.de/gbatek.htm#dscartridgenitroromandnitroarcfilesystems
        parent_id: Little(u16), 
    };

    fn readFileSystem(file: &io.File, allocator: &mem.Allocator, fnt_offset: usize, fnt_size: usize, fat_offset: usize, fat_size: usize) -> %Nitro {
        if (fat_size % @sizeOf(FatEntry) != 0)       return error.InvalidFatSize;
        if (fat_size > 61440 * @sizeOf(FatEntry))    return error.InvalidFatSize;
        var file_stream = io.FileInStream.init(file);
        var stream = &file_stream.stream;
        
        try file.seekTo(fnt_offset + 0x06);
        var count : Little(u16) = undefined;
        try stream.readNoEof(utils.asBytes(Little(u16), &count));

        const fnt_main_table = try utils.seekToAllocAndReadNoEof(FntMainEntry, file, allocator, fnt_offset, count.get());
        defer allocator.free(fnt_main_table);
        
        if (!utils.between(usize, fnt_main_table.len, 1, 4096))    return error.InvalidFntMainTableSize;
        if (fnt_size < fnt_main_table.len * @sizeOf(FntMainEntry)) return error.InvalidFntMainTableSize;

        const fat = try utils.seekToAllocAndReadNoEof(FatEntry, file, allocator, fat_offset, fat_size / @sizeOf(FatEntry));
        defer allocator.free(fat);

        const root_name = try allocator.alloc(u8, 0);
        %defer allocator.free(root_name);

        return buildFolderFromFntMainEntry(
            file, 
            allocator, 
            fat, 
            fnt_main_table, 
            fnt_main_table[0], 
            fnt_offset, 
            root_name
        );
    }

    fn buildFolderFromFntMainEntry(
        file: &io.File,
        allocator: &mem.Allocator,
        fat: []const FatEntry,
        fnt_main_table: []const FntMainEntry,
        fnt_entry: &const FntMainEntry,
        fnt_offset: usize,
        name: []u8) -> %Nitro {

        try file.seekTo(fnt_entry.offset_to_subtable.get() + fnt_offset);
        var file_stream = io.FileInStream.init(file);
        var stream = &file_stream.stream;

        var nitro_files = std.ArrayList(Nitro).init(allocator);
        %defer {
            for (nitro_files.toSlice()) |nitro_file| {
                nitro_file.destroy(allocator);
            }

            nitro_files.deinit();   
        }

        // See FNT Sub-Tables:
        // http://problemkaputt.de/gbatek.htm#dscartridgenitroromandnitroarcfilesystems
        var file_id = fnt_entry.first_id_in_subtable.get();
        while (true) {
            const type_length = try stream.readByte();

            if (type_length == 0x80) return error.InvalidSubTableTypeLength;
            if (type_length == 0x00) break;

            const type_length_pair = blk: {
                const Pair = utils.Pair(Nitro.Kind, u8);
                if (utils.between(u8, type_length, 0x01, 0x7F))
                    break :blk Pair.init(Nitro.Kind.File, type_length);
                if (utils.between(u8, type_length, 0x81, 0xFF))
                    break :blk Pair.init(Nitro.Kind.Folder, type_length - 0x80);

                unreachable;
            };

            const kind = type_length_pair.first;
            const length = type_length_pair.second;
            const child_name = try utils.allocAndReadNoEof(u8, file, allocator, length);
            %defer allocator.free(child_name);

            switch (kind) {
                Nitro.Kind.File => {
                    if (fat.len <= file_id) return error.InvalidFileId;
                    const entry = fat[file_id];

                    // If entries start or end address are 0, then the entry is unused.
                    // (See File Allocation Table (FAT))
                    // http://problemkaputt.de/gbatek.htm#dscartridgenitroromandnitroarcfilesystems
                    if (entry.start.get() == 0 or entry.end.get() == 0) continue;
                    const current_pos = try file.getPos();

                    // TODO: Doc doesn't seem to be sure where entry.end actually is:                       (Start+Len...-1?)
                    var file_data = try utils.seekToAllocAndReadNoEof(u8, file, allocator, entry.start.get(), (entry.end.get() - entry.start.get()) + 1);
                    %defer allocator.free(file_data);
                    
                    try file.seekTo(current_pos);
                    try nitro_files.append(
                        Nitro.initFile(
                            child_name,
                            Nitro.File { .Other = file_data }
                        )
                    );

                    file_id += 1;
                },
                Nitro.Kind.Folder => { 
                    var id : Little(u16) = undefined;
                    try stream.readNoEof(utils.asBytes(Little(u16), &id));

                    if (!utils.between(u16, id.get(), 0xF001, 0xFFFF))
                        return error.InvalidSubDirectoryId;
                    if (fnt_main_table.len <= id.get() & 0x0FFF)
                        return error.InvalidSubDirectoryId;
                    const current_pos = try file.getPos();

                    try nitro_files.append(
                        try buildFolderFromFntMainEntry(
                            file,
                            allocator,
                            fat,
                            fnt_main_table,
                            fnt_main_table[id.get() & 0x0FFF],
                            fnt_offset,
                            child_name
                        )
                    );

                    try file.seekTo(current_pos);
                }
            }

        }

        return Nitro.initFolder(
            name,
            Nitro.Folder { .files = nitro_files.toOwnedSlice() }
        );
    }

    const FSInfo = struct {
        files: u32,
        folders: u16,
        fnt_sub_size: u32,

        fn fromNitro(nitro: &const Nitro, root: bool) -> FSInfo {
            var result = FSInfo {
                .files = 0,
                .folders = 0,
                .fnt_sub_size = 0,
            };

            // If we are not root, then we are part of a folder, 
            // aka, we have an entry one of the sub fnt
            if (!root) {
                // TODO: Handle if nitro.name.len is > @maxValue(u16)?
                result.fnt_sub_size += u16(nitro.name.len) + 1;
            }

            switch (nitro.data) {
                Nitro.Kind.Folder => |folder| {
                    // Directories have an id in their sub fnt entry
                    if (!root) {
                        result.fnt_sub_size += 2;
                    }

                    // Each folder have a sub fnt, which is terminated by 0x00
                    result.fnt_sub_size += 1;
                    result.folders      += 1;

                    for (folder.files) |sub_file| {
                        const sizes = fromNitro(sub_file, false);
                        result.files         += sizes.files;
                        result.folders       += sizes.folders;
                        result.fnt_sub_size  += sizes.fnt_sub_size;
                    }
                },
                Nitro.Kind.File => {
                    result.files += 1;
                }
            }

            return result;
        }
    };

    const NitroWriter = struct {
        file: &io.File, 
        fat_offset: usize,
        fnt_main_start: u32,
        fnt_main_offset: usize,
        fnt_sub_offset: u32,
        fnt_first_file_id: u16,
        fnt_sub_table_folder_id: u16,
        folder_id: u16,
        file_offset: u32,
        
        fn writeToFile(self: &NitroWriter, nitro: &const Nitro, parent_id: u16) -> %void {
            switch (nitro.data) {
                Nitro.Kind.Folder => |folder| {
                    try self.file.seekTo(self.fnt_main_offset);
                    try self.file.write(utils.asConstBytes(
                        FntMainEntry,
                        FntMainEntry {
                            .offset_to_subtable   = Little(u32).init(self.fnt_sub_offset - self.fnt_main_start),
                            .first_id_in_subtable = Little(u16).init(self.fnt_first_file_id),
                            .parent_id            = Little(u16).init(parent_id), 
                        }));

                    self.fnt_main_offset = try self.file.getPos();
                    try self.file.seekTo(self.fnt_sub_offset);

                    // Writing sub-table
                    for (folder.files) |file| {
                        if (file.name.len < 1 or 127 < file.name.len) return error.InvalidNameLength;

                        switch (file.data) {
                            Nitro.Kind.Folder => |sub_folder| {
                                try self.file.write([]u8 { u8(file.name.len) });
                                try self.file.write(file.name);
                                try self.file.write(utils.asConstBytes(Little(u16), Little(u16).init(self.fnt_sub_table_folder_id)));
                                self.fnt_sub_table_folder_id += 1;
                            },
                            Nitro.Kind.File => |sub_file| {
                                try self.file.write([]u8 { u8(file.name.len + 0x80) });
                                try self.file.write(file.name);
                            }
                        }
                    }

                    // Write sub-table null terminator
                    try self.file.write([]u8 { 0x00 });
                    self.fnt_sub_offset = u32(try self.file.getPos());
                    
                    const id = self.folder_id;  
                    self.folder_id += 1;

                    for (folder.files) |file| {
                        try self.writeToFile(file, id);
                    }
                },
                Nitro.Kind.File => |file| {
                    const start = self.file_offset;
                    try self.file.seekTo(start);

                    switch (file) {
                        Nitro.File.Other => |other| {
                            try self.file.write(other);
                        },
                        else => @panic("TODO: Write code for writing other file types"),
                    }

                    self.file_offset = u32(try self.file.getPos());
                    const end = self.file_offset - 1;

                    try self.file.seekTo(self.fat_offset);
                    try self.file.write(
                        utils.asConstBytes(
                            FatEntry,
                            FatEntry {
                                .start = toLittle(u32, start),
                                .end   = toLittle(u32, end),
                            }
                        )
                    );    
                    self.fat_offset = try self.file.getPos();
                }
            }
        }
    };

    pub fn writeToFile(self: &const Rom, file: &io.File) -> %void {
        if (@maxValue(u32) < self.arm9.len)         return error.InvalidSizeInHeader;
        if (@maxValue(u32) < self.arm7.len)         return error.InvalidSizeInHeader;
        if (@maxValue(u32) < self.arm9_overlay.len) return error.InvalidSizeInHeader;

        try self.icon_title.validate();

        var header = self.header;
        var fs_info = FSInfo.fromNitro(self.root, true);

        if (@maxValue(u16) < fs_info.folders * @sizeOf(FntMainEntry)) return error.InvalidSizeInHeader;
        if (@maxValue(u16) < fs_info.files   * @sizeOf(FatEntry))     return error.InvalidSizeInHeader;

        const alignment = 0x200;

        try file.seekTo(0x4000);
        header.arm9_rom_offset = toLittle(u32, u32(try file.getPos()));
        header.arm9_size = toLittle(u32, u32(self.arm9.len));
        try file.write(self.arm9);

        try file.seekTo(toAlignment(try file.getPos(), alignment));
        header.arm9_overlay_offset = toLittle(u32, u32(try file.getPos()));
        header.arm9_overlay_size = toLittle(u32, u32(self.arm9_overlay.len));
        try file.write(self.arm9_overlay);

        try file.seekTo(toAlignment(try file.getPos(), alignment));
        header.arm7_rom_offset = toLittle(u32, u32(try file.getPos()));
        header.arm7_size = toLittle(u32, u32(self.arm7.len));
        try file.write(self.arm7);

        try file.seekTo(toAlignment(try file.getPos(), alignment));
        header.arm7_overlay_offset = toLittle(u32, u32(try file.getPos()));
        header.arm7_overlay_size = toLittle(u32, u32(self.arm7_overlay.len));
        try file.write(self.arm7_overlay);

        try file.seekTo(toAlignment(try file.getPos(), alignment));
        header.icon_title_offset = toLittle(u32, u32(try file.getPos()));

        if (header.isDsi()) {
            // TODO: On dsi, this can be of different sizes
            header.icon_title_size = toLittle(u32, @sizeOf(IconTitle));
        }
        
        try file.write(utils.asBytes(IconTitle, self.icon_title));

        header.fnt_offset = toLittle(u32, u32(toAlignment(try file.getPos(), alignment)));
        header.fnt_size = toLittle(u32, u32(fs_info.folders * @sizeOf(FntMainEntry)));

        header.fat_offset = toLittle(u32, u32(toAlignment(header.fnt_offset.get() + header.fnt_size.get(), alignment)));
        header.fat_size = toLittle(u32, u32(fs_info.files * @sizeOf(FatEntry)));

        if (header.arm9_overlay_size.get() == 0x00)
            header.arm9_overlay_offset = toLittle(u32, 0x00);

        if (header.arm7_overlay_size.get() == 0x00)
            header.arm7_overlay_offset = toLittle(u32, 0x00);

        if (header.fnt_size.get() == 0x00)
            header.fnt_offset = toLittle(u32, 0x00);

        if (header.fat_size.get() == 0x00)
            header.fat_offset = toLittle(u32, 0x00);

        try header.validate();

        // 00h  4    Offset to Sub-table             (originated at FNT base)
        const fnt_sub_offset = header.fat_offset.get() + header.fat_size.get();
        const file_offset = fs_info.fnt_sub_size + fnt_sub_offset;

        var writer = NitroWriter {
            .file = file,
            .fat_offset = header.fat_offset.get(),
            .fnt_main_start = header.fnt_offset.get(),
            .fnt_main_offset = header.fnt_offset.get(),
            .fnt_sub_offset = fnt_sub_offset,
            .fnt_first_file_id = 0,
            .fnt_sub_table_folder_id = 1,
            .folder_id = 0xF000,
            .file_offset = file_offset,
        };

        debug.warn("folders: {}\n", fs_info.folders);
        try writer.writeToFile(self.root, fs_info.folders);
        
        try file.seekTo(0x00);
        try file.write(utils.asBytes(Header, header));
    }

    fn toAlignment(address: usize, alignment: usize) -> usize {
        const res = address % alignment;
        const result = address + (alignment - res);

        assert(result % alignment == 0);
        assert(address <= result);

        return result;
    }

    pub fn destroy(self: &const Rom, allocator: &mem.Allocator) {
        allocator.destroy(self.header);
        allocator.free(self.arm9);
        allocator.free(self.arm7);
        allocator.free(self.arm9_overlay);
        allocator.free(self.arm7_overlay);
        self.root.destroy(allocator);
    }

    
};