const fun = @import("../../lib/fun-with-zig/src/index.zig"); // TODO: package stuff
const int = @import("../int.zig");
const utils = @import("../utils/index.zig");

const ascii = fun.ascii;
const generic = fun.generic;
const slice = generic.slice;

const lu16 = int.lu16;

pub const Banner = packed struct {
    pub const Version = enum(u2) {
        Original = 0x01,
        WithChineseTitle = 0x02,
        WithChineseAndKoreanTitle = 0x03,
    };

    version: Version,
    version_padding: u6,

    has_animated_dsi_icon: bool,
    has_animated_dsi_icon_padding: u7,

    crc16_across_0020h_083Fh: lu16,
    crc16_across_0020h_093Fh: lu16,
    crc16_across_0020h_0A3Fh: lu16,
    crc16_across_1240h_23BFh: lu16,

    reserved1: [0x16]u8,

    icon_bitmap: [0x200]u8,
    icon_palette: [0x20]u8,

    title_japanese: [0x100]u8,
    title_english: [0x100]u8,
    title_french: [0x100]u8,
    title_german: [0x100]u8,
    title_italian: [0x100]u8,
    title_spanish: [0x100]u8,
    //title_chinese:  [0x100]u8,
    //title_korean:   [0x100]u8,

    // TODO: Banner is actually a variable size structure.
    //       "original Icon/Title structure rounded to 200h-byte sector boundary (ie. A00h bytes for Version 1 or 2),"
    //       "however, later DSi carts are having a size entry at CartHdr[208h] (usually 23C0h)."
    //reserved2: [0x800]u8,

    //// animated DSi icons only
    //icon_animation_bitmap: [0x1000]u8,
    //icon_animation_palette: [0x100]u8,
    //icon_animation_sequence: [0x80]u8, // Should be [0x40]lu16?

    pub fn validate(banner: Banner) !void {
        if (@enumToInt(banner.version) == 0)
            return error.InvalidVersion;
        if (banner.version_padding != 0)
            return error.InvalidVersionPadding;
        if (banner.has_animated_dsi_icon_padding != 0)
            return error.InvalidHasAnimatedDsiIconPadding;

        if (!slice.all(banner.reserved1[0..], isZero))
            return error.InvalidReserved1;

        //if (!utils.all(u8, banner.reserved2, ascii.isZero))
        //    return error.InvalidReserved2;

        //if (!banner.has_animated_dsi_icon) {
        //    if (!utils.all(u8, banner.icon_animation_bitmap, is0xFF))
        //        return error.InvalidIconAnimationBitmap;
        //    if (!utils.all(u8, banner.icon_animation_palette, is0xFF))
        //        return error.InvalidIconAnimationPalette;
        //    if (!utils.all(u8, banner.icon_animation_sequence, is0xFF))
        //        return error.InvalidIconAnimationSequence;
        //}
    }

    fn isZero(b: u8) bool {
        return b == 0;
    }

    fn is0xFF(char: u8) bool {
        return char == 0xFF;
    }
};
