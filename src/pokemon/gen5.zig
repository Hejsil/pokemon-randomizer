const std = @import("std");
const pokemon = @import("index.zig");
const little = @import("../little.zig");
const nds = @import("../nds/index.zig");
const utils = @import("../utils/index.zig");
const common = @import("common.zig");
const constants = @import("gen5-constants.zig");

const mem = std.mem;

const ISlice = utils.slice.ISlice;
const Little = little.Little;
const Narc = nds.fs.Narc;
const Nitro = nds.fs.Nitro;

pub const PokemonStats = packed struct {
    hp: u8,
    attack: u8,
    defense: u8,
    speed: u8,
    sp_attack: u8,
    sp_defense: u8,

    types: [2]Type,

    catch_rate: u8,

    evs: [3]u8, // TODO: Figure out if common.EvYield fits in these 3 bytes
    items: [3]Little(u16),

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

    height: Little(u16),
    weight: Little(u16),

    // Memory layout
    // TMS 01-92, HMS 01-06, TMS 93-95
    tm_hm_learnset: Little(u128),

    // TODO: Tutor data only exists in BW2
    //special_tutors: Little(u32),
    //driftveil_tutor: Little(u32),
    //lentimas_tutor: Little(u32),
    //humilau_tutor: Little(u32),
    //nacrene_tutor: Little(u32),
};

pub const PartyMemberBase = packed struct {
    iv: u8,
    gender: u4,
    ability: u4,
    level: u8,
    padding: u8,
    species: Little(u16),
    form: Little(u16),
};

pub const PartyMemberWithMoves = packed struct {
    base: PartyMemberBase,
    moves: [4]Little(u16),
};

pub const PartyMemberWithHeld = packed struct {
    base: PartyMemberBase,
    held_item: Little(u16),
};

pub const PartyMemberWithBoth = packed struct {
    base: PartyMemberBase,
    held_item: Little(u16),
    moves: [4]Little(u16),
};

pub const PartyType = enum(u8) {
    Standard = 0x00,
    WithMoves = 0x01,
    WithHeld = 0x02,
    WithBoth = 0x03,
};

pub const Trainer = packed struct {
    party_type: PartyType,
    class: u8,
    battle_type: u8, // TODO: This should probably be an enum
    party_size: u8,
    items: [4]Little(u16),
    ai: Little(u32),
    healer: bool,
    healer_padding: u7,
    cash: u8,
    post_battle_item: Little(u16),
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
    effect: Little(u16),
    target_hp: u8,
    user_hp: u8,
    target: u8,
    stats_affected: [3]u8,
    stats_affected_magnetude: [3]u8,
    stats_affected_chance: [3]u8,

    // TODO: Figure out if this is actually how the last fields are layed out.
    padding: [2]u8,
    flags: Little(u16),
};

pub const LevelUpMove = packed struct {
    move_id: Little(u16),
    level: Little(u16),
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

pub const Game = struct {
    const legendaries = common.legendaries;

    base: pokemon.Game,
    base_stats: []const *Narc.File,
    moves: []const *Narc.File,
    level_up_moves: []const *Narc.File,
    trainer_data: []const *Narc.File,
    trainer_pokemons: []const *Narc.File,
    tms1: []Little(u16),
    hms: []Little(u16),
    tms2: []Little(u16),

    pub fn fromRom(rom: *nds.Rom) !Game {
        const info = try getInfo(rom.header.gamecode);
        const hm_tm_prefix_index = mem.indexOf(u8, rom.arm9, constants.hm_tm_prefix) ?? return error.CouldNotFindTmsOrHms;
        const hm_tm_index = hm_tm_prefix_index + constants.hm_tm_prefix.len;
        const hm_tms = ([]Little(u16))(rom.arm9[hm_tm_index..][0 .. (constants.tm_count + constants.hm_count) * @sizeOf(u16)]);

        return Game{
            .base = pokemon.Game{
                .version = info.version,
            },
            .base_stats = try getNarcFiles(rom.file_system, info.base_stats),
            .level_up_moves = try getNarcFiles(rom.file_system, info.level_up_moves),
            .moves = try getNarcFiles(rom.file_system, info.moves),
            .trainer_data = try getNarcFiles(rom.file_system, info.trainer_data),
            .trainer_pokemons = try getNarcFiles(rom.file_system, info.trainer_pokemons),
            .tms1 = hm_tms[0..92],
            .hms = hm_tms[92..98],
            .tms2 = hm_tms[98..],
        };
    }

    fn getNarcFiles(file_system: *const nds.fs.Nitro, path: []const u8) ![]const *Narc.File {
        const file = file_system.getFile(path) ?? return error.CouldntFindFile;

        switch (file.@"type") {
            Nitro.File.Type.Binary => return error.InvalidFileType,
            Nitro.File.Type.Narc => |f| return f.root.files.toSliceConst(),
        }
    }

    fn getInfo(gamecode: []const u8) !constants.Info {
        if (mem.eql(u8, gamecode, "IREO")) return constants.black2_info;
        if (mem.eql(u8, gamecode, "IRDO")) return constants.white2_info;
        if (mem.eql(u8, gamecode, "IRBO")) return constants.black_info;
        if (mem.eql(u8, gamecode, "IRAO")) return constants.white_info;

        return error.InvalidGen5GameCode;
    }

    const FileAsTypeError = error{FileToSmall};

    fn getFileAsType(comptime T: type, files: []const *nds.fs.Narc.File, index: usize) FileAsTypeError!*T {
        const data = generic.widenTrim(files[index].data, T);
        return generic.at(data, 0) catch error.FileToSmall;
    }

    pub const BaseStats = ISlice(*PokemonStats, FileAsTypeError);
    pub fn baseStats(game: *const Game) BaseStats {
        return BaseStats.initFunctions(
            []const *nds.fs.Narc.File,
            game.base_stats,
            struct {
                fn at(g: *const Game, index: usize) !Pokemon {
                    return try getFileAsType(PokemonStats, g.base_stats, index);
                }

                fn length(g: *const Game) usize {
                    return g.base_stats.len;
                }
            }
        );
    }

    pub const LevelUpMoves = ISlice([]LevelUpMove, error{});
    pub fn levelUpMoves(game: *const Game) LevelUpMoves {
        return BaseStats.initFunctions(
            []const *nds.fs.Narc.File,
            game.level_up_moves,
            struct {
                fn at(g: *const Game, index: usize) ![]LevelUpMove {
                    const res = generic.widenTrim(g.level_up_moves[index].data, LevelUpMove);

                    // Even though each level up move have it's own file, level up moves still
                    // end with 0xFFFF 0xFFFF.
                    for (res) |level_up_move, i| {
                        if (level_up_move.move_id.get() == 0xFFFF and level_up_move.level.get() == 0xFFFF)
                            return res[0..i];
                    }

                    // In the case where we don't find the end 0xFFFF 0xFFFF, we just
                    // return the level up moves, and assume things are correct.
                    return res;
                }

                fn length(g: *const Game) usize {
                    return g.level_up_moves.len;
                }
            }
        );
    }
};
