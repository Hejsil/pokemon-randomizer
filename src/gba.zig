const std   = @import("std");
const utils = @import("utils.zig");
const ascii = @import("ascii.zig");

const debug = std.debug;
const mem   = std.mem;
const io    = std.io;

const assert = debug.assert;

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

comptime {
    assert(@offsetOf(Header, "rom_entry_point")  == 0x000);
    assert(@offsetOf(Header, "nintendo_logo")    == 0x004);
    assert(@offsetOf(Header, "game_title")       == 0x0A0);
    assert(@offsetOf(Header, "gamecode")         == 0x0AC);
    assert(@offsetOf(Header, "makercode")        == 0x0B0);
    assert(@offsetOf(Header, "fixed_value")      == 0x0B2);
    assert(@offsetOf(Header, "main_unit_code")   == 0x0B3);
    assert(@offsetOf(Header, "device_type")      == 0x0B4);
    assert(@offsetOf(Header, "reserved1")        == 0x0B5);
    assert(@offsetOf(Header, "software_version") == 0x0BC);
    assert(@offsetOf(Header, "complement_check") == 0x0BD);
    assert(@offsetOf(Header, "reserved2")        == 0x0BE);

    assert(@sizeOf(Header) == 192);
}