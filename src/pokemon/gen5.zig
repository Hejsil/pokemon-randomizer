const little = @import("../little.zig");
const nds    = @import("../nds/index.zig");
const utils  = @import("../utils/index.zig");
const common = @import("common.zig");

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

pub const Game = struct {
    base_stats: []nds.fs.File,
    trainer_data: []nds.fs.File,
    trainer_pokemons: []nds.fs.File,

    pub fn fromRom(rom: &nds.Rom) !Game {
        const root = &rom.root;

        return Game {
            .base_stats       = getNarcFiles(root, "a/0/1/6") ?? return error.Err,
            .trainer_data     = getNarcFiles(root, "a/0/9/1") ?? return error.Err,
            .trainer_pokemons = getNarcFiles(root, "a/0/9/2") ?? return error.Err,
        };
    }

    fn getNarcFiles(folder: &const nds.fs.Folder, path: []const u8) ?[]nds.fs.File {
        const file = folder.getFile("a/0/1/6") ?? return null;

        switch (file.@"type") {
            nds.fs.File.Type.Binary => return null,
            nds.fs.File.Type.Narc => |f| return f.files,
        }
    }

    fn getBinaryAs(comptime T: type, files: []nds.fs.File, index: usize) ?&T {
        const file = utils.slice.atOrNull(files, index) ?? return null;

        switch (file.@"type") {
            nds.fs.File.Type.Binary => |data| {
                return utils.slice.ptrAtOrNull(([]T)(data), index);
            },
            nds.fs.File.Type.Narc => return null,
        }
    }

    pub fn getBasePokemon(game: &const Game, index: usize) ?&BasePokemon {
        return getBinaryAs(BasePokemon, game.base_stats, index);
    }

    pub fn getTrainer(game: &const Game, index: usize) ?&Trainer {
        return getBinaryAs(Trainer, game.trainer_data, index);
    }

    pub fn getTrainerPokemon(game: &const Game, trainer: &const Trainer, index: usize) ?&PartyMember {
        unreachable;
    }

    pub fn getMove(game: &const Game, index: usize) ?&Move {
        unreachable;
    }

    pub fn getMoveCount(game: &const Game) usize {
        unreachable;
     }

    pub fn getLevelupMoves(game: &const Game, species: usize) ?[]LevelUpMove {
        unreachable;
    }

    pub fn getTms(game: &const Game) []Little(u16) {
        unreachable;
    }

    pub fn getHms(game: &const Game) []Little(u16) {
        unreachable;
    }

    pub fn getTmHmLearnset(game: &const Game, species: usize) ?&Little(u64) {
        unreachable;
    }
};
