const std   = @import("std");
const utils = @import("utils.zig");
const ascii = @import("ascii.zig");

const debug = std.debug;
const mem   = std.mem;
const io    = std.io;

const assert = debug.assert;








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

    pub fn validate(self: &const Header) !void {
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