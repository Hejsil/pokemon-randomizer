const std = @import("std");
const pokemon = @import("index.zig");
const int = @import("../int.zig");
const nds = @import("../nds/index.zig");
const utils = @import("../utils/index.zig");
const common = @import("common.zig");

const mem = std.mem;

const lu16 = int.lu16;
const lu32 = int.lu32;
const lu128 = int.lu128;

pub const constants = @import("gen4-constants.zig");

pub const BasePokemon = packed struct {
    stats: common.Stats,
    types: [2]Type,

    catch_rate: u8,
    base_exp_yield: u8,

    evs: common.EvYield,
    items: [2]lu16,

    gender_ratio: u8,
    egg_cycles: u8,
    base_friendship: u8,
    growth_rate: common.GrowthRate,

    egg_group1: common.EggGroup,
    egg_group1_pad: u4,
    egg_group2: common.EggGroup,
    egg_group2_pad: u4,

    abilities: [2]u8,
    flee_rate: u8,

    color: common.Color,
    color_padding: bool,

    // Memory layout
    // TMS 01-92, HMS 01-08
    tm_hm_learnset: lu128,
};

pub const MoveTutor = packed struct {
    move: lu16,
    cost: u8,
    tutor: u8,
};

/// All party members have this as the base.
/// * If trainer.party_type & 0b10 then there is an additional u16 after the base, which is the held
///   item.
/// * If trainer.party_type & 0b01 then there is an additional 4 * u16 after the base, which are
///   the party members moveset.
/// In HG/SS/Plat, this struct is always padded with a u16 at the end, no matter the party_type
pub const PartyMember = packed struct {
    iv: u8,
    gender: u4,
    ability: u4,
    level: lu16,
    species: u10,
    form: u6,
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
    battle_type2: u8,
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
    Fire = 0x0A,
    Water = 0x0B,
    Grass = 0x0C,
    Electric = 0x0D,
    Psychic = 0x0E,
    Ice = 0x0F,
    Dragon = 0x10,
    Dark = 0x11,
};

// TODO: This is the first data structure I had to decode from scratch as I couldn't find a proper
//       resource for it... Fill it out!
pub const Move = packed struct {
    u8_0: u8,
    u8_1: u8,
    category: common.MoveCategory,
    power: u8,
    @"type": Type,
    accuracy: u8,
    pp: u8,
    u8_7: u8,
    u8_8: u8,
    u8_9: u8,
    u8_10: u8,
    u8_11: u8,
    u8_12: u8,
    u8_13: u8,
    u8_14: u8,
    u8_15: u8,
};

pub const LevelUpMove = packed struct {
    move_id: u9,
    level: u7,
};

pub const DpptWildPokemons = packed struct {
    grass_rate: lu32,
    grass: [12]Grass,
    replacements: [26]lu32, // TODO: Figure out exactly how these replacements map to encounters.
    surf: [5]Sea,
    sea_unkwown: [5]Sea,
    old_rod: [5]Sea,
    good_rod: [5]Sea,
    super_rod: [5]Sea,

    pub const Grass = packed struct {
        level: lu32,
        species: lu32,
    };

    pub const Sea = packed struct {
        level_max: u8,
        level_min: u8,
        pad: [2]u8,
        species: lu32,
    };
};

pub const HgssWildPokemons = packed struct {
    grass_rate: u8,
    sea_rates: [5]u8,
    unknown: [2]u8,
    grass_levels: [12]u8,
    grass_morning: [12]lu16,
    grass_day: [12]lu16,
    grass_night: [12]lu16,
    radio: [4]lu16,
    surf: [5]Sea,
    sea_unknown: [2]Sea,
    old_rod: [5]Sea,
    good_rod: [5]Sea,
    super_rod: [5]Sea,
    swarm: [4]lu16,

    pub const Sea = packed struct {
        level_min: u8,
        level_max: u8,
        species: lu16,
    };
};

pub const Game = struct {
    base: pokemon.BaseGame,
    base_stats: *const nds.fs.Narc,
    moves: *const nds.fs.Narc,
    level_up_moves: *const nds.fs.Narc,
    trainers: *const nds.fs.Narc,
    parties: *const nds.fs.Narc,
    tms: []align(1) lu16,
    hms: []align(1) lu16,

    pub fn fromRom(rom: nds.Rom) !Game {
        const info = try getInfo(rom.header.game_title, rom.header.gamecode);
        const hm_tm_prefix_index = mem.indexOf(u8, rom.arm9, info.hm_tm_prefix) orelse return error.CouldNotFindTmsOrHms;
        const hm_tm_index = hm_tm_prefix_index + info.hm_tm_prefix.len;
        const hm_tms_len = (constants.tm_count + constants.hm_count) * @sizeOf(u16);
        const hm_tms = @bytesToSlice(lu16, rom.arm9[hm_tm_index..][0..hm_tms_len]);

        return Game{
            .base = pokemon.BaseGame{ .version = info.version },
            .base_stats = try common.getNarc(rom.root, info.base_stats),
            .level_up_moves = try common.getNarc(rom.root, info.level_up_moves),
            .moves = try common.getNarc(rom.root, info.moves),
            .trainers = try common.getNarc(rom.root, info.trainers),
            .parties = try common.getNarc(rom.root, info.parties),
            .tms = hm_tms[0..92],
            .hms = hm_tms[92..],
        };
    }

    fn getInfo(game_title: []const u8, gamecode: []const u8) !constants.Info {
        for (constants.infos) |info| {
            //if (!mem.eql(u8, info.game_title, game_title))
            //    continue;
            if (!mem.eql(u8, info.gamecode, gamecode))
                continue;

            return info;
        }

        return error.NotGen4Game;
    }
};
