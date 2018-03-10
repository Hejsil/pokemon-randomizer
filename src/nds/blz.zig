// blz.c - Bottom LZ coding for Nintendo GBA/DS
// Copyright (C) 2011 CUE
//
// Ported to Zig by Jimmi Holst Christensen
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.

const std = @import("std");

const mem  = std.mem;
const math = std.math;

const threshold = 2;

fn decode(data: []const u8, allocator: &mem.Allocator) !void {
    const Lengths = struct {
        enc: u32,
        dec: u32,
        pak: u32,
        raw: u32,
    }

    if (data.len < 8) return error.BadHeader;

    const inc_len = mem.readIntLE(u32, data[data.len - 4..]);
    const lengths = if (inc_len == 0) blk: {
        break :blk Lengths {
            .enc = 0,
            .dec = data.len,
            .pak = 0,
            .raw = data.len,
        };
    } else {
        const hdr_len = data[data.len - 5];
        if (hdr_len < 8 or hdr_len > 0xB) return error.BadHeaderLength;
        if (data.len <= hdr_len)          return error.BadLength;

        const enc_len = mem.readIntLE(u32, data[data.len - 8..]) & 0x00FFFFFF;
        const dec_len = try math.sub(u32, data.len, enc_len);
        const pak_len = try math.sub(u32, enc_len, hdr_len);
        const raw_len = dec_len + enc_len + inc_len;

        if (raw_len > 0x00FFFFFF) return error.BadLength;

        const res = Lengths {
            .enc = enc_len,
            .dec = dec_len,
            .pak = pak_len,
            .raw = raw_len,
        };
    }


    const result     = try allocator.alloc(u8, lengths.raw);
    const pak_buffer = try allocator.alloc(u8, data.len + 3);
    defer allocator.free(pak_buffer);

    mem.copy(u8, result, data[0..lengths.dec]);
    mem.copy(u8, pak_buffer, data);
    invert(pak_buffer, lengths.dec, lengths.pak);

    const pak_end = lengths.dec + lengths.pak;
    var pak = lengths.dec;
    var raw = lengths.dec;
    var mask = u32(0);
    var flags = u32(0);

    while (raw < lengths.raw) {
        mask = mask >> 1;
        if (mask == 0) {
            if (pak == pak_end) break;

            flags = pak_buffer[pak];
            mask = 0x80;
            pak += 1;
        }

        if (flags & mask == 0) {
            if (pak == pak_end) break;

            raw_buffer[raw] = pak_buffer[pak];
            raw += 1;
            pak += 1;
        } else {
            if (pak + 1 >= pak_end) break;

            const pos = (u32(pak_buffer[pak]) << 8) | pak_buffer[pak + 1];
            pak += 2;

            const len = (pos >> 12) + threshold + 1;
            if (raw + len > lengths.raw) return error.WrongDecodedLength;

            const new_pos = (pos & 0xFFF) + 3;
            var i = 0;
            while (i < len) : (i += 1) {
                raw_buffer[raw] = raw_buffer[raw - new_pos];
                raw += 1;
            }
        }

    }

    if (raw != lengths.raw) return error.UnexpectedEnd;

    invert(raw_buffer, lengths.dec, lengths.raw - lengths.dec);
    return raw_buffer[0..raw];
}
