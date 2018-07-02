const std = @import("std");
const pokemon = @import("pokemon");
const utils = @import("utils");
const constants = @import("gen2-constants.zig");
const search = @import("search.zig");
const int = @import("int");

const debug = std.debug;
const mem = std.mem;
const common = pokemon.common;
const gen2 = pokemon.gen2;

const lu16 = int.lu16;

const Offset = struct {
    start: usize,
    len: usize,

    fn fromSlice(start: usize, comptime T: type, slice: []const T) Offset {
        return Offset{
            .start = @ptrToInt(slice.ptr) - start,
            .len = slice.len,
        };
    }
};

const Info = struct {
    base_stats: Offset,
    trainer_group_pointers: Offset,
    trainer_group_lenghts: []u8,
};

pub fn findInfoInFile(data: []const u8, version: pokemon.Version, allocator: *mem.Allocator) !Info {
    // In gen2, trainers are split into groups. Each group have attributes for their items, reward ai and so on.
    // The game does not store the size of each group anywere oviuse, so we have to figure out the size of each
    // group.
    var trainer_group_pointers: []const lu16 = undefined;
    var trainer_group_lenghts: []u8 = undefined;
    switch (version) {
        pokemon.Version.Crystal => {
            // First, we find the first and last group pointers
            const first_group_pointer = indexOfTrainer(data, 0, constants.first_trainers) orelse return error.TrainerGroupsNotFound;
            const last_group_pointer = indexOfTrainer(data, first_group_pointer, constants.last_trainers) orelse return error.TrainerGroupsNotFound;

            // Then, we can find the group pointer table
            const first_group_pointers = []lu16{lu16.init(@intCast(u16, first_group_pointer))};
            const last_group_pointers = []lu16{lu16.init(@intCast(u16, last_group_pointer))};
            trainer_group_pointers = search.findStructs(
                lu16,
                [][]const u8{},
                data,
                first_group_pointers,
                last_group_pointers,
            ) orelse return error.UnableToFindBaseStatsOffset;

            // Ensure that the pointers are in ascending order.
            for (trainer_group_pointers[1..]) |item, i| {
                const prev = trainer_group_pointers[i - 1];
                if (prev.value() > item.value())
                    return error.TrainerGroupsNotFound;
            }

            trainer_group_lenghts = try allocator.alloc(u8, trainer_group_pointers.len);

            // If the pointers are in ascending order, then we will assume that pointers[i]
            // is terminated by pointers[i + 1], so we can just check for all parties between
            // this range to find the group count for each group.
            // For poiners[pointers.len - 1], we will look until we hit an invalid party.
            for (trainer_group_pointers) |_, i| {
                const is_last = i + 1 == trainer_group_pointers.len;
                var curr = trainer_group_pointers[i].value();
                const next = if (!is_last) trainer_group_pointers[i + 1].value() else @maxValue(u16);

                group_loop: while (curr < next) : (trainer_group_lenghts[i] += 1) {
                    // Skip, until we find the string terminator for the trainer name
                    while (data[curr] != '\x50')
                        curr += 1;
                    curr += 1; // Skip terminator

                    const trainer_type = data[curr];
                    const valid_type_bits: u8 = gen2.Party.has_moves | gen2.Party.has_item;
                    if (trainer_type & ~(valid_type_bits) != 0)
                        break :group_loop;

                    curr += 1;

                    // Validate trainers party
                    while (data[curr] != 0xFF) {
                        const level = data[curr];
                        const species = data[curr + 1];

                        if (level > 100)
                            break :group_loop;

                        curr += 2;
                        if (trainer_type & gen2.Party.has_item != 0)
                            curr += 1;
                        if (trainer_type & gen2.Party.has_moves != 0)
                            curr += 4;
                    }
                }
            }

            for (trainer_group_lenghts) |b| {
                debug.warn("{}, ", b);
            }
        },
        else => unreachable,
    }

    const ignored_base_stat_fields = [][]const u8{ "dimension_of_front_sprite", "blank", "tm_hm_learnset", "gender_ratio", "egg_group1_pad", "egg_group2_pad" };
    const base_stats = search.findStructs(
        gen2.BasePokemon,
        ignored_base_stat_fields,
        data,
        constants.first_base_stats,
        constants.last_base_stats,
    ) orelse {
        return error.UnableToFindBaseStatsOffset;
    };

    const start = @ptrToInt(data.ptr);
    return Info{
        .base_stats = Offset.fromSlice(start, gen2.BasePokemon, base_stats),
        .trainer_group_pointers = Offset.fromSlice(start, lu16, trainer_group_pointers),
        .trainer_group_lenghts = trainer_group_lenghts,
    };
}

fn indexOfTrainer(data: []const u8, start_index: usize, trainers: []const constants.Trainer) ?usize {
    const bytes = blk: {
        var res: usize = 0;
        for (trainers) |trainer| {
            res += trainer.name.len;
            res += 2 * trainer.party.len; // level, species
            if (trainer.kind & gen2.Party.has_item != 0)
                res += 1 * trainer.party.len;
            if (trainer.kind & gen2.Party.has_moves != 0)
                res += 4 * trainer.party.len;
            res += 1; // trainer terminator
        }

        break :blk res;
    };
    if (data.len < bytes)
        return null;

    var i = start_index;
    var end = data.len - bytes;

    search_loop: while (i <= end) : (i += 1) {
        var off = i;
        for (trainers) |trainer, j| {
            off += trainer.name.len;
            if (!mem.eql(u8, trainer.name, data[i..off]))
                continue :search_loop;

            if (data[off] != trainer.kind)
                continue :search_loop;

            off += 1;
            for (trainer.party) |member| {
                if (data[off] != member.base.level)
                    continue :search_loop;
                if (data[off + 1] != member.base.species)
                    continue :search_loop;

                off += 2;
                if (trainer.kind & gen2.Party.has_item != 0) {
                    if (data[off] != member.item)
                        continue :search_loop;
                    off += 1;
                }
                if (trainer.kind & gen2.Party.has_moves != 0) {
                    if (!mem.eql(u8, data[off..][0..4], member.moves))
                        continue :search_loop;
                    off += 4;
                }
            }

            if (data[off] != 0xFF)
                continue :search_loop;
            off += 1;
        }

        return i;
    }

    return null;
}
