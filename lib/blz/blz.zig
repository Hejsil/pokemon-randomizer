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
const default_mask = 0x80;

// TODO: Figure out if it's possible to make these encode and decode functions use streams.
pub fn decode(data: []const u8, allocator: &mem.Allocator) ![]u8 {
    const Lengths = struct {
        enc: usize,
        dec: usize,
        pak: usize,
        raw: usize,
    };

    if (data.len < 8) return error.BadHeader;

    const inc_len = mem.readIntLE(u32, data[data.len - 4..]);
    const lengths = blk: {
        if (inc_len == 0) {
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

            const enc_len = mem.readIntLE(usize, data[data.len - 8..]) & 0x00FFFFFF;
            const dec_len = try math.sub(usize, data.len, enc_len);
            const pak_len = try math.sub(usize, enc_len, hdr_len);
            const raw_len = dec_len + enc_len + inc_len;

            if (raw_len > 0x00FFFFFF) return error.BadLength;

            break :blk Lengths {
                .enc = enc_len,
                .dec = dec_len,
                .pak = pak_len,
                .raw = raw_len,
            };
        }
    };


    const result = try allocator.alloc(u8, lengths.raw);
    errdefer allocator.free(result);
    const pak_buffer = try allocator.alloc(u8, data.len + 3);
    defer allocator.free(pak_buffer);

    mem.copy(u8, result, data[0..lengths.dec]);
    mem.copy(u8, pak_buffer, data);
    invert(pak_buffer[lengths.dec..lengths.dec + lengths.pak]);

    const pak_end = lengths.dec + lengths.pak;
    var pak = lengths.dec;
    var raw = lengths.dec;
    var mask = usize(0);
    var flags = usize(0);

    while (raw < lengths.raw) {
        mask = mask >> 1;
        if (mask == 0) {
            if (pak == pak_end) break;

            flags = pak_buffer[pak];
            mask = default_mask;
            pak += 1;
        }

        if (flags & mask == 0) {
            if (pak == pak_end) break;

            result[raw] = pak_buffer[pak];
            raw += 1;
            pak += 1;
        } else {
            if (pak + 1 >= pak_end) break;

            const pos = (usize(pak_buffer[pak]) << 8) | pak_buffer[pak + 1];
            pak += 2;

            const len = (pos >> 12) + threshold + 1;
            if (raw + len > lengths.raw) return error.WrongDecodedLength;

            const new_pos = (pos & 0xFFF) + 3;
            var i = usize(0);
            while (i < len) : (i += 1) {
                result[raw] = result[raw - new_pos];
                raw += 1;
            }
        }

    }

    if (raw != lengths.raw) return error.UnexpectedEnd;

    invert(result[lengths.dec..lengths.raw]);
    return result[0..raw];
}

pub const Mode = enum {
    Normal,
    Best
};

pub fn encode(data: []const u8, mode: Mode, arm9: bool, allocator: &mem.Allocator) ![]u8 {
    var pak_tmp = usize(0);
    var raw_tmp = data.len;
    var pak_len = data.len + ((data.len + 7) / 8) + 11;
    var pos_best = usize(0);
    var pos_next = usize(0);
    var pos_post = usize(0);
    var pak = usize(0);
    var raw = usize(0);
    var mask = usize(0);
    var flag = usize(0);
    var raw_end = blk: {
        var res = data.len;
        if (arm9) {
            res -= 0x4000;
        }

        break :blk res;
    };

    const result = try allocator.alloc(u8, pak_len);
    const raw_buffer = try allocator.alloc(u8, data.len + 3);
    defer allocator.free(raw_buffer);
    mem.copy(u8, raw_buffer, data);

    invert(raw_buffer[0..data.len]);

    while (raw < raw_end) {
        mask = mask >> 1;
        if (mask == 0) {
            result[pak] = 0;
            mask = default_mask;
            flag = pak;
            pak += 1;
        }

        const bests = search(pos_best, raw_buffer[0..raw_end], raw);
        pos_best = bests.p;

        const len_best = blk: {
            if (mode == Mode.Best) {
                if (bests.l > threshold) {
                    if (raw + bests.l < raw_end) {
                        raw += bests.l;

                        const nexts = search(pos_next, raw_buffer[0..raw_end], raw);
                        raw -= bests.l - 1;
                        const posts = search(pos_post, raw_buffer[0..raw_end], raw);

                        pos_next = nexts.p;
                        pos_post = posts.p;
                        raw -= 1;

                        const len_next = if (nexts.l <= threshold) 1 else nexts.l;
                        const len_post = if (posts.l <= threshold) 1 else posts.l;

                        if (bests.l + len_next <= 1 + len_post)
                            break :blk 1;
                    }
                }
            }

            break :blk bests.l;
        };

        result[flag] = result[flag] << 1;
        if (len_best > threshold) {
            raw += len_best;
            result[flag] |= 1;
            result[pak] = @truncate(u8, ((len_best - (threshold + 1)) << 4) | ((pos_best - 3) >> 8));
            result[pak + 1] = @truncate(u8, (pos_best - 3));
            pak += 2;
        } else {
            result[pak] = raw_buffer[raw];
            pak += 1;
            raw += 1;
        }

        if (pak + data.len - raw < pak_tmp + raw_tmp) {
            pak_tmp = pak;
            raw_tmp = data.len - raw;
        }
    }

    while (mask > 0 and mask != 0) {
        mask = mask >> 1;
        result[flag] = result[flag] << 1;
    }

    pak_len = pak;

    invert(raw_buffer[0..data.len]);
    invert(result[0..pak_len]);

    if (pak_tmp == 0 or data.len + 4 < ((pak_tmp + raw_tmp + 3) & 0xFFFFFFFC) + 8) {
        pak = 0;
        raw = 0;
        raw_end = data.len;

        while (raw < raw_end) : ({ pak += 1; raw += 1; }) {
            result[pak] = raw_buffer[raw];
        }

        while ((pak & 3) > 0) : (pak += 1) {
            result[pak] = 0;
        }

        result[pak] = 0;
        result[pak + 1] = 0;
        result[pak + 2] = 0;
        result[pak + 3] = 0;
        pak += 4;

        return result[0..pak];
    } else {
        defer allocator.free(result);
        const new_result = try allocator.alloc(u8, raw_tmp + pak_tmp + 11);

        mem.copy(u8, new_result[0..raw_tmp], raw_buffer[0..raw_tmp]);
        mem.copy(u8, new_result[raw_tmp..][0..pak_tmp], result[pak_len - pak_tmp..][0..pak_tmp]);

        pak = raw_tmp + pak_tmp;

        const enc_len = pak_tmp;
        const inc_len = data.len - pak_tmp - raw_tmp;
        var hdr_len = usize(8);

        while ((pak & 3) != 0) {
            new_result[pak] = 0xFF;
            pak += 1;
            hdr_len += 1;
        }

        mem.writeInt(new_result[pak..], u32(enc_len + hdr_len), @import("builtin").Endian.Little);
        pak += 3;
        new_result[pak] = @truncate(u8, hdr_len);
        pak += 1;
        mem.writeInt(new_result[pak..], u32(inc_len - hdr_len), @import("builtin").Endian.Little);
        pak += 4;

        return new_result[0..pak];
    }
}

const SearchResult = struct {
    l: usize,
    p: usize,
};

fn search(p: usize, data: []const u8, raw: usize) SearchResult {
    const max = math.min(raw, usize(0x1002));

    var new_p = p;
    var l = usize(threshold);
    var pos = usize(3);
    while (pos <= max) : (pos += 1) {
        var len = usize(0);
        while (len < 0x12) : (len += 1) {
            if (raw + len == data.len) break;
            if (len >= pos) break;
            if (data[raw + len] != data[raw + len - pos]) break;
        }

        if (len > l) {
            new_p = pos;
            l = len;
            if (l == 0x12) break;
        }
    }

    return SearchResult {
        .l = l,
        .p = new_p,
    };
}

fn invert(data: []u8) void {
    var bottom = data.len - 1;
    var i = usize(0);
    while (i < bottom) : ({ i += 1; bottom -= 1; }) {
        const tmp = data[i];
        data[i] = data[bottom];
        data[bottom] = tmp;
    }
}
