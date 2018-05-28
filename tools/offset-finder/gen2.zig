const std = @import("std");
const pokemon = @import("pokemon");
const utils = @import("utils");
const constants = @import("gen2-constants.zig");
const search = @import("search.zig");

const debug = std.debug;
const mem = std.mem;
const common = pokemon.common;
const gen2 = pokemon.gen2;

const Offset = struct {
    start: usize,
    len: usize,

    fn fromSlice(start: usize, comptime T: type, slice: []const T) Offset {
        return Offset {
            .start = @ptrToInt(slice.ptr) - start,
            .len = slice.len,
        };
    }
};

const Info = struct {
    base_stats: Offset,
};

pub fn findInfoInFile(data: []const u8, version: common.Version) !Info {
    var trainer_group_pointers: Offset = undefined;
    var trainer_group_lenghts: []u8 = undefined;
    switch (version) {
        common.Version.Crystal => {
            const first_group_pointer = indexOfTrainerGroups(data, 0, constants.first_trainer_groups) ?? return error.A;
            const last_group_pointer = indexOfTrainerGroups(data, first_group_pointer, constants.last_trainer_groups) ?? return error.A;
            debug.warn("{} {}\n", first_group_pointer, last_group_pointer);
        },
        else => unreachable,
    }

    const ignored_base_stat_fields = [][]const u8 { "dimension_of_front_sprite", "blank", "tm_hm_learnset", "gender_ratio", "egg_group1_pad", "egg_group2_pad" };
    const base_stats = search.findStructs(gen2.BasePokemon, ignored_base_stat_fields, data,
        constants.first_base_stats,
        constants.last_base_stats) ?? {
        return error.UnableToFindBaseStatsOffset;
    };

    const start = @ptrToInt(data.ptr);
    return Info{
        .base_stats = Offset.fromSlice(start, gen2.BasePokemon, base_stats)
    };
}

fn indexOfTrainerGroups(data: []const u8, start_index: usize, trainer_groups: []const constants.TrainerGroup) ?usize {
    const bytes = blk: {
        var res: usize = 0;
        for (trainer_groups) |group| {
            res += group.name.len + 1;
            res += switch (group.party) {
                gen2.PartyType.Standard => |party| @sizeOf(@typeOf(party[0])) * party.len,
                gen2.PartyType.WithMoves => |party| @sizeOf(@typeOf(party[0])) * party.len,
                gen2.PartyType.WithHeld => |party| @sizeOf(@typeOf(party[0])) * party.len,
                gen2.PartyType.WithBoth => |party| @sizeOf(@typeOf(party[0])) * party.len,
            };
        }

        break :blk res;
    };
    if (data.len < bytes)
        return null;

    var i = start_index;
    var end = data.len - bytes;
    while (i <= end) : (i += 1) {
        var off = i;
        for (trainer_groups) |group| {
            if (!mem.eql(u8, group.name, data[off..][0..group.name.len]))
                return null;

            @breakpoint();
            off += group.name.len;

            if (data[off] != u8(gen2.PartyType(group.party)))
                return null;

            off += 1;
            const party_data = data[off..];
            off += switch (group.party) {
                gen2.PartyType.Standard => |party| skipIfMatch(@typeOf(party[0]), party, off, party_data),
                gen2.PartyType.WithMoves => |party| skipIfMatch(@typeOf(party[0]), party, off, party_data),
                gen2.PartyType.WithHeld => |party| skipIfMatch(@typeOf(party[0]), party, off, party_data),
                gen2.PartyType.WithBoth => |party| skipIfMatch(@typeOf(party[0]), party, off, party_data),
            } ?? return null;

            // Parties are terminated with 0xFF
            if (data[off] != 0xFF)
                return null;

            off += 1;
        }
    }

    return null;
}

fn skipIfMatch(comptime Member: type, party: []const Member, offset: usize, data: []const u8) ?usize {
    for (party) |member, i| {
        const member_bytes = utils.toBytes(Member, member);
        const data_bytes = data[offset + i * @sizeOf(Member)..][0..@sizeOf(Member)];
        if (!mem.eql(u8, member_bytes, data_bytes))
            return null;
    }

    return offset + party.len * @sizeOf(Member);
}
