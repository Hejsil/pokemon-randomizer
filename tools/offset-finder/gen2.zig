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
            const first_group_pointer = indexOfTrainerParties(data, 0, constants.first_trainer_parties) ?? return error.A;
            const last_group_pointer = indexOfTrainerParties(data, first_group_pointer, constants.last_trainer_parties) ?? return error.A;
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

fn indexOfTrainerParties(data: []const u8, start_index: usize, trainer_parties: []const constants.TrainerParty) ?usize {
    const bytes = blk: {
        var res: usize = 0;
        for (trainer_parties) |trainer_party| {
            res += trainer_party.name.len + 1;
            res += switch (trainer_party.party) {
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

    search_loop:
    while (i <= end) : (i += 1) {
        var off = i;
        for (trainer_parties) |trainer_party, j| {
            off += trainer_party.name.len;
            if (!mem.eql(u8, trainer_party.name, data[i..off]))
                continue :search_loop;

            if (data[off] != u8(gen2.PartyType(trainer_party.party)))
                continue :search_loop;

            off += 1;

            // TODO: Each case is a copy paste. The code is the same, but 'party' is of a different type
            //       each time. Idk of a good way to creat a function right now with a proper name, so
            //       i'll just leave this as is.
            switch (trainer_party.party) {
                gen2.PartyType.Standard => |party| {
                    const party_bytes = ([]const u8)(party);
                    const data_bytes = data[off..][0..party_bytes.len];
                    if (!mem.eql(u8, party_bytes, data_bytes))
                        continue :search_loop;

                    off += party_bytes.len;
                },
                gen2.PartyType.WithMoves => |party| {
                    const party_bytes = ([]const u8)(party);
                    const data_bytes = data[off..][0..party_bytes.len];
                    if (!mem.eql(u8, party_bytes, data_bytes))
                        continue :search_loop;

                    off += party_bytes.len;
                },
                gen2.PartyType.WithHeld => |party| {
                    const party_bytes = ([]const u8)(party);
                    const data_bytes = data[off..][0..party_bytes.len];
                    if (!mem.eql(u8, party_bytes, data_bytes))
                        continue :search_loop;

                    off += party_bytes.len;
                },
                gen2.PartyType.WithBoth => |party| {
                    const party_bytes = ([]const u8)(party);
                    const data_bytes = data[off..][0..party_bytes.len];
                    if (!mem.eql(u8, party_bytes, data_bytes))
                        continue :search_loop;

                    off += party_bytes.len;
                },
            }

            if (data[off] != 0xFF)
                continue :search_loop;
            off += 1;
        }

        return i;
    }

    return null;
}
