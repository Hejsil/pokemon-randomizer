const std   = @import("std");
const utils = @import("utils.zig");
const ascii = @import("ascii.zig");

const debug = std.debug;
const mem   = std.mem;
const io    = std.io;

const assert = debug.assert;

pub const nintendo_logo = @embedFile("logo/gba.logo");

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
        if (!utils.all(u8, self.game_title, ascii.isUpperAscii)) 
            return error.InvalidGameTitle;
        if (!utils.all(u8, self.gamecode, ascii.isUpperAscii))
            return error.InvalidGamecode;

        if (!utils.all(u8, self.makercode, ascii.isUpperAscii))
            return error.InvalidMakercode;
        if (self.fixed_value != 0x96)
            return error.InvalidFixedValue;
            
        if (!utils.all(u8, self.reserved1, ascii.isZero))
            return error.InvalidReserved1;
        if (!utils.all(u8, self.reserved2, ascii.isZero))
            return error.InvalidReserved2;
    }
};

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