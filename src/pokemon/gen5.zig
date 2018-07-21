const std = @import("std");
const pokemon = @import("index.zig");
const int = @import("../int.zig");
const nds = @import("../nds/index.zig");
const utils = @import("../utils/index.zig");
const common = @import("common.zig");

const mem = std.mem;

const Narc = nds.fs.Narc;
const Nitro = nds.fs.Nitro;

const lu16 = int.lu16;
const lu32 = int.lu32;
const lu128 = int.lu128;

pub const constants = @import("gen5-constants.zig");

pub const BasePokemon = packed struct {
    stats: common.Stats,
    types: [2]Type,

    catch_rate: u8,

    evs: [3]u8, // TODO: Figure out if common.EvYield fits in these 3 bytes
    items: [3]lu16,

    gender_ratio: u8,
    egg_cycles: u8,
    base_friendship: u8,

    growth_rate: common.GrowthRate,

    egg_group1: common.EggGroup,
    egg_group1_pad: u4,
    egg_group2: common.EggGroup,
    egg_group2_pad: u4,

    abilities: [3]u8,

    // TODO: The three fields below are kinda unknown
    flee_rate: u8,
    form_stats_start: [2]u8,
    form_sprites_start: [2]u8,

    form_count: u8,

    color: common.Color,
    color_padding: bool,

    base_exp_yield: u8,

    height: lu16,
    weight: lu16,

    // Memory layout
    // TMS 01-92, HMS 01-06, TMS 93-95
    tm_hm_learnset: lu128,

    // TODO: Tutor data only exists in BW2
    //special_tutors: lu32,
    //driftveil_tutor: lu32,
    //lentimas_tutor: lu32,
    //humilau_tutor: lu32,
    //nacrene_tutor: lu32,
};

/// All party members have this as the base.
/// * If trainer.party_type & 0b10 then there is an additional u16 after the base, which is the held
///   item.
/// * If trainer.party_type & 0b01 then there is an additional 4 * u16 after the base, which are
///   the party members moveset.
pub const PartyMember = packed struct {
    iv: u8,
    gender: u4,
    ability: u4,
    level: u8,
    padding: u8,
    species: lu16,
    form: lu16,
};

pub const Trainer = packed struct {
    const has_item = 0b10;
    const has_moves = 0b01;

    party_type: u8,
    class: u8,
    battle_type: u8, // TODO: This should probably be an enum
    party_size: u8,
    items: [4]lu16,
    ai: lu32,
    healer: bool,
    healer_padding: u7,
    cash: u8,
    post_battle_item: lu16,
};

pub const Move = packed struct {
    @"type": Type,
    effect_category: u8,
    category: common.MoveCategory,
    power: u8,
    accuracy: u8,
    pp: u8,
    priority: u8,
    hits: u8,
    min_hits: u4,
    max_hits: u4,
    crit_chance: u8,
    flinch: u8,
    effect: lu16,
    target_hp: u8,
    user_hp: u8,
    target: u8,
    stats_affected: [3]u8,
    stats_affected_magnetude: [3]u8,
    stats_affected_chance: [3]u8,

    // TODO: Figure out if this is actually how the last fields are layed out.
    padding: [2]u8,
    flags: lu16,
};

pub const LevelUpMove = packed struct {
    move_id: lu16,
    level: lu16,
};

pub const Type = enum(u8) {
    Normal = 0x00,
    Fighting = 0x01,
    Flying = 0x02,
    Poison = 0x03,
    Ground = 0x04,
    Rock = 0x05,
    Bug = 0x06,
    Ghost = 0x07,
    Steel = 0x08,
    Fire = 0x09,
    Water = 0x0A,
    Grass = 0x0B,
    Electric = 0x0C,
    Psychic = 0x0D,
    Ice = 0x0E,
    Dragon = 0x0F,
    Dark = 0x10,
};

pub const WildPokemon = packed struct {
    species: lu16,
    level_min: u8,
    level_max: u8,
};

pub const WildPokemons = packed struct {
    rates: [7]u8,
    pad: u8,
    grass: [12]WildPokemon,
    dark_grass: [12]WildPokemon,
    rustling_grass: [12]WildPokemon,
    surf: [5]WildPokemon,
    ripple_surf: [5]WildPokemon,
    fishing: [5]WildPokemon,
    ripple_fishing: [5]WildPokemon,
};

pub const Game = struct {
    const legendaries = common.legendaries;

    base: pokemon.BaseGame,
    base_stats: *const nds.fs.Narc,
    moves: *const nds.fs.Narc,
    level_up_moves: *const nds.fs.Narc,
    trainers: *const nds.fs.Narc,
    parties: *const nds.fs.Narc,
    tms1: []lu16,
    hms: []lu16,
    tms2: []lu16,

    pub fn fromRom(rom: nds.Rom) !Game {
        const info = try getInfo(rom.header.gamecode);
        const hm_tm_prefix_index = mem.indexOf(u8, rom.arm9, constants.hm_tm_prefix) orelse return error.CouldNotFindTmsOrHms;
        const hm_tm_index = hm_tm_prefix_index + constants.hm_tm_prefix.len;
        const hm_tm_len = (constants.tm_count + constants.hm_count) * @sizeOf(u16);
        const hm_tms = @bytesToSlice(lu16, rom.arm9[hm_tm_index..][0..hm_tm_len]);

        return Game{
            .base = pokemon.BaseGame{ .version = info.version },
            .base_stats = try common.getNarc(rom.root, info.base_stats),
            .level_up_moves = try common.getNarc(rom.root, info.level_up_moves),
            .moves = try common.getNarc(rom.root, info.moves),
            .trainers = try common.getNarc(rom.root, info.trainers),
            .parties = try common.getNarc(rom.root, info.parties),
            .tms1 = hm_tms[0..92],
            .hms = hm_tms[92..98],
            .tms2 = hm_tms[98..],
        };
    }

    fn getInfo(gamecode: []const u8) !constants.Info {
        for (constants.infos) |info| {
            //if (!mem.eql(u8, info.game_title, game_title))
            //    continue;
            if (!mem.eql(u8, info.gamecode, gamecode))
                continue;

            return info;
        }

        return error.NotGen5Game;
    }
};
