const pokemon   = @import("pokemon");
const search    = @import("search.zig");
const std       = @import("std");
const gba       = @import("gba");
const utils     = @import("utils");
const little    = @import("little");
const constants = @import("gen3-constants.zig");

const os     = std.os;
const debug  = std.debug;
const mem    = std.mem;
const math   = std.math;
const io     = std.io;

const gen3 = pokemon.gen3;
const common = pokemon.common;

const Little = little.Little;
const toLittle = little.toLittle;

const Info = struct {
    gamecode:                   []const u8,
    trainers:                   search.Offset,
    moves:                      search.Offset,
    tm_hm_learnset:             search.Offset,
    base_stats:                 search.Offset,
    evolution_table:            search.Offset,
    level_up_learnset_pointers: search.Offset,
    hms:                        search.Offset,
    tms:                        search.Offset,
    items:                      search.Offset,
};

pub fn findInfoInFile(file: &os.File, allocator: &mem.Allocator) !Info {
    var file_stream = io.FileInStream.init(file);
    var stream = &file_stream.stream;
    var header : gba.Header = undefined;
    try stream.readNoEof(utils.asBytes(gba.Header, &header));
    try file.seekTo(0);

    const version = if (mem.eql(u8, header.game_title, "POKEMON EMER")) blk: {
        break :blk common.Version.Emerald;
    } else if (mem.eql(u8, header.game_title, "POKEMON RUBY")) blk: {
        break :blk common.Version.Ruby;
    } else if (mem.eql(u8, header.game_title, "POKEMON SAPP")) blk: {
        break :blk common.Version.Sapphire;
    } else if (mem.eql(u8, header.game_title, "POKEMON FIRE")) blk: {
        break :blk common.Version.FireRed;
    } else if (mem.eql(u8, header.game_title, "POKEMON LEAF")) blk: {
        break :blk common.Version.LeafGreen;
    } else blk: {
        return error.UnknownPokemonVersion;
    };

    const data = try stream.readAllAlloc(allocator, @maxValue(usize));
    defer allocator.free(data);

    const ignored_trainer_fields = [][]const u8 { "party_offset", "name" };
    const trainers = switch (version) {
        common.Version.Emerald => search.findOffsetOfStructArray(gen3.Trainer, ignored_trainer_fields, data,
            constants.em_first_trainers,
            constants.em_last_trainers),
        common.Version.Ruby, common.Version.Sapphire => search.findOffsetOfStructArray(gen3.Trainer, ignored_trainer_fields, data,
            constants.rs_first_trainers,
            constants.rs_last_trainers),
        common.Version.FireRed, common.Version.LeafGreen => search.findOffsetOfStructArray(gen3.Trainer, ignored_trainer_fields, data,
            constants.frls_first_trainers,
            constants.frls_last_trainers),
        else => null,
    } ?? {
        return error.UnableToFindTrainerOffset;
    };

    const moves = search.findOffsetOfStructArray(gen3.Move, [][]const u8 { }, data,
        constants.first_moves,
        constants.last_moves) ?? {
        return error.UnableToFindMoveOffset;
    };

    const tm_hm_learnset = search.findOffset(u8, data,
        constants.first_tm_hm_learnsets,
        constants.last_tm_hm_learnsets) ?? {
        return error.UnableToFindTmHmLearnsetOffset;
    };

    const ignored_base_stat_fields = [][]const u8 { "padding", "egg_group1_pad", "egg_group2_pad" };
    const base_stats = search.findOffsetOfStructArray(gen3.BasePokemon, ignored_base_stat_fields, data,
        constants.first_base_stats,
        constants.last_base_stats) ?? {
        return error.UnableToFindBaseStatsOffset;
    };

    const ignored_evolution_fields = [][]const u8 { "padding" };
    const evolution_table = search.findOffsetOfStructArray(common.Evolution, ignored_evolution_fields, data,
        constants.first_evolutions,
        constants.last_evolutions) ?? {
        return error.UnableToFindEvolutionTableOffset;
    };

    const level_up_learnset_pointers = blk: {
        var first_pointers = []?u8{null} ** (constants.first_levelup_learnsets.len * 4);
        for (constants.first_levelup_learnsets) |maybe_learnset, i| {
            if (maybe_learnset) |learnset| {
                const p = mem.indexOf(u8, data, learnset) ?? return error.UnableToFindLevelUpLearnsetOffset;
                const l = toLittle(u32(p) + 0x8000000);
                for (first_pointers[i * 4..][0..4]) |*b, j| {
                    *b = l.bytes[j];
                }
            }
        }

        var last_pointers = []?u8{null} ** (constants.last_levelup_learnsets.len * 4);
        for (constants.last_levelup_learnsets) |maybe_learnset, i| {
            if (maybe_learnset) |learnset| {
                const p = mem.indexOf(u8, data, learnset) ?? return error.UnableToFindLevelUpLearnsetOffset;
                const l = toLittle(u32(p) + 0x8000000);
                for (last_pointers[i * 4..][0..4]) |*b, j| {
                    *b = l.bytes[j];
                }
            }
        }

        break :blk search.findOffsetUsingPattern(u8, data, first_pointers, last_pointers) ?? return error.UnableToFindLevelUpLearnsetOffset;
    };

    const hms_start = mem.indexOf(u8, data, constants.hms) ?? return error.UnableToFindHmOffset;
    const hms_offsets = search.Offset { .start = hms_start, .end = hms_start + constants.hms.len };

    // TODO: Pokémon Emerald have 2 tm tables. I'll figure out some hack for that
    //       if it turns out that both tables are actually used. For now, I'll
    //       assume that the first table is the only one used.
    const tms_start = mem.indexOf(u8, data, constants.tms) ?? return error.UnableToFindTmOffset;
    const tms_offsets = search.Offset { .start = tms_start, .end = tms_start + constants.tms.len };

    const ignored_item_fields = [][]const u8 { "name", "description_offset", "field_use_func", "battle_use_func" };
    const items = switch (version) {
        common.Version.Emerald => search.findOffsetOfStructArray(gen3.Item, ignored_item_fields, data,
            constants.em_first_items,
            constants.em_last_items),
        common.Version.Ruby, common.Version.Sapphire => search.findOffsetOfStructArray(gen3.Item, ignored_item_fields, data,
            constants.rs_first_items,
            constants.rs_last_items),
        common.Version.FireRed, common.Version.LeafGreen => search.findOffsetOfStructArray(gen3.Item, ignored_item_fields, data,
            constants.frlg_first_items,
            constants.frlg_last_items),
        else => null,
    } ?? {
        return error.UnableToFindItemsOffset;
    };

    return Info {
        .gamecode                   = try mem.dupe(allocator, u8, header.gamecode),
        .trainers                   = trainers,
        .moves                      = moves,
        .tm_hm_learnset             = tm_hm_learnset,
        .base_stats                 = base_stats,
        .evolution_table            = evolution_table,
        .level_up_learnset_pointers = level_up_learnset_pointers,
        .hms                        = hms_offsets,
        .tms                        = tms_offsets,
        .items                      = items,
    };
}
