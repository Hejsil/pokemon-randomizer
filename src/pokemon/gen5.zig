const std    = @import("std");
const little = @import("../little.zig");
const nds    = @import("../nds/index.zig");
const utils  = @import("../utils/index.zig");
const common = @import("common.zig");

const mem = std.mem;

const Little = little.Little;

pub const BasePokemon = packed struct {
    hp:         u8,
    attack:     u8,
    defense:    u8,
    speed:      u8,
    sp_attack:  u8,
    sp_defense: u8,

    types: [2]common.Type,

    catch_rate:     u8,

    evs: [3]u8, // TODO: Figure out if common.EvYield fits in these 3 bytes
    items: [3]Little(u16),

    gender_ratio:    u8,
    egg_cycles:      u8,
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

    special_tutors: Little(u32),
    driftveil_tutor: Little(u32),
    lentimas_tutor: Little(u32),
    humilau_tutor: Little(u32),
    nacrene_tutor: Little(u32),
};

// https://projectpokemon.org/home/forums/topic/22629-b2w2-general-rom-info/?do=findComment&comment=153174
pub const PartyMember = packed struct {
    iv: u8,
    gender: u4,
    ability: u4,
    level: u8,
    padding: u8,
    species: Little(u16),
    form: Little(u16),
};

pub const PartyMemberWithMoves = packed struct {
    base: PartyMember,
    moves: [4]Little(u16),
};

pub const PartyMemberWithHeld = packed struct {
    base: PartyMember,
    held_item: Little(u16),
};

pub const PartyMemberWithBoth = packed struct {
    base: PartyMember,
    held_item: Little(u16),
    moves: [4]Little(u16),
};

pub const PartyType = enum(u8) {
    Standard  = 0x00,
    WithMoves = 0x01,
    WithHeld  = 0x02,
    WithBoth  = 0x03,
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

// https://projectpokemon.org/home/forums/topic/14212-bw-move-data/?do=findComment&comment=123606
pub const Move = packed struct {
    @"type": common.Type,
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

pub const Game = struct {
    const legendaries = common.legendaries;

    base_stats: []const &nds.fs.NarcFile,
    moves: []const &nds.fs.NarcFile,
    level_up_moves: []const &nds.fs.NarcFile,
    trainer_data: []const &nds.fs.NarcFile,
    trainer_pokemons: []const &nds.fs.NarcFile,
    tms1: []Little(u16),
    hms: []Little(u16),
    tms2: []Little(u16),

    pub fn fromRom(rom: &nds.Rom) !Game {
        const tm_count = 95;
        const hm_count = 6;
        const hm_tm_prefix = "\x87\x03\x88\x03";
        const hm_tm_prefix_index = mem.indexOf(u8, rom.arm9, hm_tm_prefix) ?? return error.CouldNotFindTmsOrHms;
        const hm_tm_index = hm_tm_prefix_index + hm_tm_prefix.len;
        const hm_tms = ([]Little(u16))(rom.arm9[hm_tm_index..][0..(tm_count + hm_count) * @sizeOf(u16)]);

        return Game {
            .base_stats       = getNarcFiles(rom.tree, "a/0/1/6") ?? return error.Err,
            .level_up_moves   = getNarcFiles(rom.tree, "a/0/1/8") ?? return error.Err,
            .moves            = getNarcFiles(rom.tree, "a/0/2/1") ?? return error.Err,
            .trainer_data     = getNarcFiles(rom.tree, "a/0/9/1") ?? return error.Err,
            .trainer_pokemons = getNarcFiles(rom.tree, "a/0/9/2") ?? return error.Err,
            .tms1             = hm_tms[0..92],
            .hms              = hm_tms[92..98],
            .tms2             = hm_tms[98..],
        };
    }

    fn getNarcFiles(tree: &const nds.fs.Tree(nds.fs.NitroFile), path: []const u8) ?[]const &nds.fs.NarcFile {
        const file = tree.getFile(path) ?? return null;

        switch (file.@"type") {
            nds.fs.NitroFile.Type.Binary => return null,
            nds.fs.NitroFile.Type.Narc => |f| return f.root.files.toSliceConst(),
        }
    }

    fn getFileAsType(comptime T: type, files: []const &nds.fs.NarcFile, index: usize) ?&T {
        const file = utils.slice.atOrNull(files, index) ?? return null;
        const data = file.data;
        const len = data.len - (data.len % @sizeOf(T));
        return utils.slice.ptrAtOrNull(([]T)(data[0..len]), 0);
    }

    pub fn getBasePokemon(game: &const Game, index: usize) ?&BasePokemon {
        return getFileAsType(BasePokemon, game.base_stats, index);
    }

    pub fn getTrainer(game: &const Game, index: usize) ?&Trainer {
        return getFileAsType(Trainer, game.trainer_data, index);
    }

    pub fn getTrainerPokemon(game: &const Game, trainer_index: usize, party_member_index: usize) ?&PartyMember {
        const trainer = getTrainer(game, trainer_index) ?? return null;
        const trainer_party = utils.slice.atOrNull(game.trainer_pokemons, trainer_index) ?? return null;

        return switch (trainer.party_type) {
            PartyType.Standard  => getPartyMember(PartyMember, trainer_party.data, party_member_index),
            PartyType.WithMoves => getPartyMember(PartyMemberWithMoves, trainer_party.data, party_member_index),
            PartyType.WithHeld  => getPartyMember(PartyMemberWithHeld, trainer_party.data, party_member_index),
            PartyType.WithBoth  => getPartyMember(PartyMemberWithBoth, trainer_party.data, party_member_index),
            else => null,
        };
    }

    fn getPartyMember(comptime TMember: type, data: []u8, index: usize) ?&PartyMember {
        const member = utils.slice.ptrAtOrNull(([]TMember)(data), index) ?? return null;
        return if (TMember == PartyMember) member else &member.base;
    }

    pub fn getMove(game: &const Game, index: usize) ?&Move {
        return getFileAsType(Move, game.moves, index);
    }

    pub fn getMoveCount(game: &const Game) usize {
        return game.moves.len;
     }

    pub fn getLevelupMoves(game: &const Game, species: usize) ?[]LevelUpMove {
        const level_up_moves = ([]LevelUpMove)(getBinary(game.level_up_moves, index) ?? return null);

        // Even though each level up move have it's own file, level up moves still
        // end with 0xFFFF 0xFFFF.
        for (level_up_moves) |level_up_moves, index| {
            if (level_up_moves.move_id.get() == 0xFFFF and level_up_moves.level.get() == 0xFFFF)
                return level_up_moves[0..index];
        }

        // In the case where we don't find the end 0xFFFF 0xFFFF, we just
        // return the level up moves, and assume things are correct.
        return level_up_moves;
    }

    pub fn getTmMove(game: &const Game, tm: usize) ?&Little(u16) {
        return utils.slice.ptrAtOrNull(game.tms1, tm) ??
               utils.slice.ptrAtOrNull(game.tms2, tm - game.tms1.len);
    }

    pub fn getHmMove(game: &const Game, hm: usize) ?&Little(u16) { return utils.slice.ptrAtOrNull(game.hms, hm); }

    pub fn learnsTm(game: &const Game, species: usize, tm: usize) ?bool {
        if (tm >= game.tms2.len + game.tms1.len) return null;

        const pokemon = game.getBasePokemon(species) ?? return null;
        const tm_hm_learnset = pokemon.tm_hm_learnset.get();
        const index = if (tm < game.tms1.len) tm else tm + game.hms.len;

        return bits.get(u128, tm_hm_learnset, u6(index));
    }

    pub fn learnsHm(game: &const Game, species: usize, hm: usize) ?bool {
        if (hm >= game.hms.len)                 return null;

        const pokemon = game.getBasePokemon(species) ?? return null;
        const tm_hm_learnset = pokemon.tm_hm_learnset.get();

        return bits.get(u64, tm_hm_learnset, u6(hm + game.tms.len));
    }
};
