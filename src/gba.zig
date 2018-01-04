const std = @import("std");
const utils = @import("utils.zig");
const ascii = @import("ascii.zig");
const debug = std.debug;
const mem = std.mem;
const assert = debug.assert;

pub const nintendo_logo = []u8 {
    0x24, 0xff, 0xae, 0x51, 0x69, 0x9a, 0xa2, 0x21, 0x3d, 0x84,
    0x82, 0x0a, 0x84, 0xe4, 0x09, 0xad, 0x11, 0x24, 0x8b, 0x98,
    0xc0, 0x81, 0x7f, 0x21, 0xa3, 0x52, 0xbe, 0x19, 0x93, 0x09,
    0xce, 0x20, 0x10, 0x46, 0x4a, 0x4a, 0xf8, 0x27, 0x31, 0xec,
    0x58, 0xc7, 0xe8, 0x33, 0x82, 0xe3, 0xce, 0xbf, 0x85, 0xf4,
    0xdf, 0x94, 0xce, 0x4b, 0x09, 0xc1, 0x94, 0x56, 0x8a, 0xc0,
    0x13, 0x72, 0xa7, 0xfc, 0x9f, 0x84, 0x4d, 0x73, 0xa3, 0xca,
    0x9a, 0x61, 0x58, 0x97, 0xa3, 0x27, 0xfc, 0x03, 0x98, 0x76,
    0x23, 0x1d, 0xc7, 0x61, 0x03, 0x04, 0xae, 0x56, 0xbf, 0x38,
    0x84, 0x00, 0x40, 0xa7, 0x0e, 0xfd, 0xff, 0x52, 0xfe, 0x03,
    0x6f, 0x95, 0x30, 0xf1, 0x97, 0xfb, 0xc0, 0x85, 0x60, 0xd6,
    0x80, 0x25, 0xa9, 0x63, 0xbe, 0x03, 0x01, 0x4e, 0x38, 0xe2,
    0xf9, 0xa2, 0x34, 0xff, 0xbb, 0x3e, 0x03, 0x44, 0x78, 0x00,
    0x90, 0xcb, 0x88, 0x11, 0x3a, 0x94, 0x65, 0xc0, 0x7c, 0x63,
    0x87, 0xf0, 0x3c, 0xaf, 0xd6, 0x25, 0xe4, 0x8b, 0x38, 0x0a,
    0xac, 0x72, 0x21, 0xd4, 0xf8, 0x07,
};

error InvalidNintentoLogo;
error InvalidGameTitle;
error InvalidGamecode;
error InvalidMakercode;
error InvalidFixedValue;
error InvalidReserved1;
error InvalidReserved2;

pub const Header = packed struct {
    rom_entry_point: [4]u8,
    nintendo_logo: [156]u8,
    game_title: [12]u8,
    gamecode:   [4]u8,
    makercode:  [2]u8,
    
    fixed_value:    u8,
    main_unit_code: u8,
    device_type:    u8,

    reserved1: [7]u8,

    software_version: u8,
    complement_check: u8,

    reserved2: [2]u8,

    pub fn validate(self: &const Header) -> %void {
        if (!mem.eql(u8, self.nintendo_logo, nintendo_logo))
            return error.InvalidNintentoLogo;
        if (!utils.all(u8, self.game_title, ascii.isUpperOrSpace)) 
            return error.InvalidGameTitle;
        if (!utils.all(u8, self.gamecode, ascii.isUpperOrSpace))
            return error.InvalidGamecode;
        if (!utils.all(u8, self.makercode, ascii.isUpperOrSpace))
            return error.InvalidMakercode;
        if (self.fixed_value != 0x96)
            return error.InvalidFixedValue;
            
        if (!utils.all(u8, self.reserved1, ascii.isZero))
            return error.InvalidReserved1;
        if (!utils.all(u8, self.reserved2, ascii.isZero))
            return error.InvalidReserved2;
    }
};

test "gba.Header.validate" {
    const header : Header = undefined;

    // TODO: We should probably test this function properly, but for now,
    //       this will ensure that the function is compiled when testing.
    header.validate() %% {};
}

test "gba.Header: Offsets" {
    const header : Header = undefined;
    const base = @ptrToInt(&header);

    assert(@ptrToInt(&header.rom_entry_point ) - base == 0x000);
    assert(@ptrToInt(&header.nintendo_logo   ) - base == 0x004);
    assert(@ptrToInt(&header.game_title      ) - base == 0x0A0);
    assert(@ptrToInt(&header.gamecode        ) - base == 0x0AC);
    assert(@ptrToInt(&header.makercode       ) - base == 0x0B0);
    assert(@ptrToInt(&header.fixed_value     ) - base == 0x0B2);
    assert(@ptrToInt(&header.main_unit_code  ) - base == 0x0B3);
    assert(@ptrToInt(&header.device_type     ) - base == 0x0B4);
    assert(@ptrToInt(&header.reserved1       ) - base == 0x0B5);
    assert(@ptrToInt(&header.software_version) - base == 0x0BC);
    assert(@ptrToInt(&header.complement_check) - base == 0x0BD);
    assert(@ptrToInt(&header.reserved2       ) - base == 0x0BE);
    
    assert(@sizeOf(Header) == 192);
}