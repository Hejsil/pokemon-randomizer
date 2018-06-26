const pokemon = @import("pokemon");
const search = @import("search.zig");
const std = @import("std");
const utils = @import("utils");
const little = @import("little");
const constants = @import("gen3-constants.zig");

const os = std.os;
const debug = std.debug;
const mem = std.mem;
const math = std.math;
const io = std.io;

const gen3 = pokemon.gen3;
const common = pokemon.common;

const Little = little.Little;
const toLittle = little.toLittle;

const Info = gen3.constants.Info;
const TrainerSection = gen3.constants.TrainerSection;
const MoveSection = gen3.constants.MoveSection;
const MachineLearnsetSection = gen3.constants.MachineLearnsetSection;
const BaseStatsSection = gen3.constants.BaseStatsSection;
const EvolutionSection = gen3.constants.EvolutionSection;
const LevelUpLearnsetPointerSection = gen3.constants.LevelUpLearnsetPointerSection;
const HmSection = gen3.constants.HmSection;
const TmSection = gen3.constants.TmSection;
const ItemSection = gen3.constants.ItemSection;

pub fn findInfoInFile(data: []const u8, version: pokemon.Version) !Info {
    const ignored_trainer_fields = [][]const u8{ "party_offset", "name" };
    const maybe_trainers = switch (version) {
        pokemon.Version.Emerald => search.findStructs(
            gen3.Trainer,
            ignored_trainer_fields,
            data,
            constants.em_first_trainers,
            constants.em_last_trainers,
        ),
        pokemon.Version.Ruby, pokemon.Version.Sapphire => search.findStructs(
            gen3.Trainer,
            ignored_trainer_fields,
            data,
            constants.rs_first_trainers,
            constants.rs_last_trainers,
        ),
        pokemon.Version.FireRed, pokemon.Version.LeafGreen => search.findStructs(
            gen3.Trainer,
            ignored_trainer_fields,
            data,
            constants.frls_first_trainers,
            constants.frls_last_trainers,
        ),
        else => null,
    };
    const trainers = maybe_trainers orelse return error.UnableToFindTrainerOffset;

    const moves = search.findStructs(
        gen3.Move,
        [][]const u8{},
        data,
        constants.first_moves,
        constants.last_moves,
    ) orelse {
        return error.UnableToFindMoveOffset;
    };

    const machine_learnset = search.findStructs(
        Little(u64),
        [][]const u8{},
        data,
        constants.first_machine_learnsets,
        constants.last_machine_learnsets,
    ) orelse {
        return error.UnableToFindTmHmLearnsetOffset;
    };

    const ignored_base_stat_fields = [][]const u8{ "padding", "egg_group1_pad", "egg_group2_pad" };
    const base_stats = search.findStructs(
        gen3.BasePokemon,
        ignored_base_stat_fields,
        data,
        constants.first_base_stats,
        constants.last_base_stats,
    ) orelse {
        return error.UnableToFindBaseStatsOffset;
    };

    const evolution_table = search.findStructs(
        [5]common.Evolution,
        [][]const u8{"padding"},
        data,
        constants.first_evolutions,
        constants.last_evolutions,
    ) orelse {
        return error.UnableToFindEvolutionTableOffset;
    };

    const level_up_learnset_pointers = blk: {
        var first_pointers = []?u8{null} ** (constants.first_levelup_learnsets.len * 4);
        for (constants.first_levelup_learnsets) |maybe_learnset, i| {
            if (maybe_learnset) |learnset| {
                const p = mem.indexOf(u8, data, learnset) orelse return error.UnableToFindLevelUpLearnsetOffset;
                const l = toLittle(@intCast(u32, p) + 0x8000000);
                for (first_pointers[i * 4 ..][0..4]) |*b, j| {
                    b.* = l.bytes[j];
                }
            }
        }

        var last_pointers = []?u8{null} ** (constants.last_levelup_learnsets.len * 4);
        for (constants.last_levelup_learnsets) |maybe_learnset, i| {
            if (maybe_learnset) |learnset| {
                const p = mem.indexOf(u8, data, learnset) orelse return error.UnableToFindLevelUpLearnsetOffset;
                const l = toLittle(@intCast(u32, p) + 0x8000000);
                for (last_pointers[i * 4 ..][0..4]) |*b, j| {
                    b.* = l.bytes[j];
                }
            }
        }

        const pointers = search.findPattern(u8, data, first_pointers, last_pointers) orelse return error.UnableToFindLevelUpLearnsetOffset;
        break :blk @bytesToSlice(Little(u32), pointers);
    };

    const hms_start = mem.indexOf(u8, data, constants.hms) orelse return error.UnableToFindHmOffset;
    const hms = @bytesToSlice(Little(u16), data[hms_start..][0..constants.hms.len]);

    // TODO: Pokémon Emerald have 2 tm tables. I'll figure out some hack for that
    //       if it turns out that both tables are actually used. For now, I'll
    //       assume that the first table is the only one used.
    const tms_start = mem.indexOf(u8, data, constants.tms) orelse return error.UnableToFindTmOffset;
    const tms = @bytesToSlice(Little(u16), data[tms_start..][0..constants.tms.len]);

    const ignored_item_fields = [][]const u8{ "name", "description_offset", "field_use_func", "battle_use_func" };
    const maybe_items = switch (version) {
        pokemon.Version.Emerald => search.findStructs(
            gen3.Item,
            ignored_item_fields,
            data,
            constants.em_first_items,
            constants.em_last_items,
        ),
        pokemon.Version.Ruby, pokemon.Version.Sapphire => search.findStructs(
            gen3.Item,
            ignored_item_fields,
            data,
            constants.rs_first_items,
            constants.rs_last_items,
        ),
        pokemon.Version.FireRed, pokemon.Version.LeafGreen => search.findStructs(
            gen3.Item,
            ignored_item_fields,
            data,
            constants.frlg_first_items,
            constants.frlg_last_items,
        ),
        else => null,
    };
    const items = maybe_items orelse return error.UnableToFindItemsOffset;

    return Info{
        .game_title = undefined,
        .gamecode = undefined,
        .version = version,
        .trainers = TrainerSection.init(data, trainers),
        .moves = MoveSection.init(data, moves),
        .machine_learnsets = MachineLearnsetSection.init(data, machine_learnset),
        .base_stats = BaseStatsSection.init(data, base_stats),
        .evolutions = EvolutionSection.init(data, evolution_table),
        .level_up_learnset_pointers = LevelUpLearnsetPointerSection.init(data, level_up_learnset_pointers),
        .hms = HmSection.init(data, hms),
        .tms = TmSection.init(data, tms),
        .items = ItemSection.init(data, items),
    };
}
