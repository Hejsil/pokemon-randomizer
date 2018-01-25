const std    = @import("std");
const gba    = @import("../gba.zig");
const little = @import("../little.zig");
const utils  = @import("../utils.zig");
const common = @import("common.zig");

const mem   = std.mem;
const debug = std.debug;
const io    = std.io;

const assert = debug.assert;
const u1     = @IntType(false, 1);

const toLittle = little.toLittle;
const Little   = little.Little;

pub const BasePokemon = packed struct {
    hp:         u8,
    attack:     u8,
    defense:    u8,
    speed:      u8,
    sp_attack:  u8,
    sp_defense: u8,

    type1: common.Type,
    type2: common.Type,

    catch_rate:     u8,
    base_exp_yield: u8,

    ev_yield: common.EvYield,

    item1: Little(u16),
    item2: Little(u16),

    gender_ratio:    u8,
    egg_cycles:      u8,
    base_friendship: u8,

    growth_rate: common.GrowthRate,

    egg_group1: common.EggGroup,
    egg_group1_pad: u4,
    egg_group2: common.EggGroup,
    egg_group2_pad: u4,

    abillity1: u8,
    abillity2: u8,

    safari_zone_rate: u8,

    color: common.Color,
    flip: u1,

    padding: [2]u8
};

pub const EvolutionKind = enum(u16) {
    Unused                 = toLittle(u16, 0x00).get(),
    FriendShip             = toLittle(u16, 0x01).get(),
    FriendShipDuringDay    = toLittle(u16, 0x02).get(),
    FriendShipDuringNight  = toLittle(u16, 0x03).get(),
    LevelUp                = toLittle(u16, 0x04).get(),
    Trade                  = toLittle(u16, 0x05).get(),
    TradeHoldingItem       = toLittle(u16, 0x06).get(),
    UseItem                = toLittle(u16, 0x07).get(),
    AttackGthDefense       = toLittle(u16, 0x08).get(),
    AttackEqlDefense       = toLittle(u16, 0x09).get(),
    AttackLthDefense       = toLittle(u16, 0x0A).get(),
    PersonalityValue1      = toLittle(u16, 0x0B).get(),
    PersonalityValue2      = toLittle(u16, 0x0C).get(),
    LevelUpMaySpawnPokemon = toLittle(u16, 0x0D).get(),
    LevelUpSpawnIfCond     = toLittle(u16, 0x0E).get(),
    Beauty                 = toLittle(u16, 0x0F).get(),
};

pub const Evolution = packed struct {
    kind: EvolutionKind,
    param: Little(u16),
    target: Little(u16),
    padding: [2]u8,
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
    encounter_music: u8,
    trainer_picture: u8,
    name: [12]u8,
    items: [4]Little(u16),
    is_double: Little(u32),
    ai: Little(u32),
    party_size: Little(u32),
    party_offset: Little(u32),
};

pub const PartyMemberBase = packed struct {
    iv: Little(u16),
    level: Little(u16),
    species: Little(u16),
};

pub const PartyMember = packed struct {
    base: PartyMemberBase,
    padding: Little(u16),
};

pub const PartyMemberWithMoves = packed struct {
    base: PartyMemberBase,
    moves: [4]Little(u16),
    padding: Little(u16),
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

const Offsets = struct {
    trainer_class_names:        usize,
    trainers:                   usize,
    species_names:              usize,
    move_names:                 usize,
    base_stats:                 usize,
    level_up_learnsets:         usize,
    evolution_table:            usize,
    level_up_learnset_pointers: usize,
};

// TODO: WIP https://github.com/pret/pokeemerald/blob/master/data/data2c.s
const emerald_offsets = Offsets {
    .trainer_class_names        = 0x030FCD4,
    .trainers                   = 0x0310030,
    .species_names              = 0x03185C8,
    .move_names                 = 0x031977C,

    .base_stats                 = 0x03203CC,
    .level_up_learnsets         = 0x03230DC,
    .evolution_table            = 0x032531C,
    .level_up_learnset_pointers = 0x032937C,
};

error InvalidRomSize;
error InvalidGen3PokemonHeader;
error NoBulbasaurFound;
error InvalidGeneration;
error InvalidTrainerPartyOffset;
error InvalidPartyType;

const bulbasaur_fingerprint = []u8 {
    0x2D, 0x31, 0x31, 0x2D, 0x41, 0x41, 0x0C, 0x03, 0x2D, 0x40, 0x00, 0x01, 0x00, 0x00,
    0x00, 0x00, 0x1F, 0x14, 0x46, 0x03, 0x01, 0x07, 0x41, 0x00, 0x00, 0x03, 0x00, 0x00,
};

pub const Game = struct {
    offsets: &const Offsets,
    data: []u8,

    // All these fields point into data
    header: &gba.Header,
    trainers: []Trainer,
    base_stats: []BasePokemon,
    evolution_table: [][5]Evolution,

    pub fn fromFile(file: &io.File, allocator: &mem.Allocator) -> %&Game {
        var file_stream = io.FileInStream.init(file);
        var stream = &file_stream.stream;

        const header = try utils.noAllocRead(gba.Header, file);
        try header.validate();
        try file.seekTo(0);

        const offsets = try getOffsets(header);
        const rom = try stream.readAllAlloc(allocator, @maxValue(usize));
        errdefer allocator.free(rom);

        if (rom.len % 0x1000000 != 0) return error.InvalidRomSize;

        var res = try allocator.create(Game);
        errdefer allocator.destroy(res);

        *res = Game {
            .offsets         = offsets,
            .data            = rom,
            .header          = @ptrCast(&gba.Header, &rom[0]),
            .trainers        = ([]Trainer)(rom[offsets.trainers..offsets.species_names]),
            .base_stats      = ([]BasePokemon)(rom[offsets.base_stats..offsets.level_up_learnsets]),
            .evolution_table = ([][5]Evolution)(rom[offsets.evolution_table..offsets.level_up_learnset_pointers]),
        };

        return res;
    }

    fn getOffsets(header: &const gba.Header) -> %&const Offsets {
        if (mem.eql(u8, header.game_title, "POKEMON EMER")) {
            return &emerald_offsets;
        }

        // TODO:
        //if (mem.eql(u8, header.game_title, "POKEMON SAPP")) {
        //
        //}

        // TODO:
        //if (mem.eql(u8, header.game_title, "POKEMON RUBY")) {
        //
        //}

        return error.InvalidGen3PokemonHeader;
    }

    pub fn validateData(game: &const Game) -> %void {
        if (!mem.eql(u8, bulbasaur_fingerprint, utils.asConstBytes(BasePokemon, game.base_stats[1])))
            return error.NoBulbasaurFound;
    }

    pub fn writeToStream(game: &const Game, stream: &io.OutStream) -> %void {
        try game.header.validate();
        try stream.write(game.data);
    }

    pub fn destroy(game: &const Game, allocator: &mem.Allocator) {
        allocator.free(game.data);
        allocator.destroy(game);
    }

    pub fn getBasePokemon(game: &const Game, index: usize) -> ?&BasePokemon {
        return utils.ptrAt(BasePokemon, game.base_stats, index);
    }

    pub fn getTrainer(game: &const Game, index: usize) -> ?&Trainer {
        return utils.ptrAt(Trainer, game.trainers, index);
    }

    pub fn getTrainerPokemon(game: &const Game, trainer: &const Trainer, index: usize) -> ?&PartyMemberBase {
        if (trainer.party_offset.get() < 0x8000000) return null;

        const offset = trainer.party_offset.get() - 0x8000000;

        switch (trainer.party_type) {
            PartyType.Standard => {
                return getBasePartyMember(PartyMember, game.data, index, offset, trainer.party_size.get());
            },
            PartyType.WithMoves => {
                return getBasePartyMember(PartyMemberWithMoves, game.data, index, offset, trainer.party_size.get());
            },
            PartyType.WithHeld => {
                return getBasePartyMember(PartyMemberWithHeld, game.data, index, offset, trainer.party_size.get());
            },
            PartyType.WithBoth => {
                return getBasePartyMember(PartyMemberWithBoth, game.data, index, offset, trainer.party_size.get());
            },
            else => return null,
        }
    }

    fn getBasePartyMember(comptime TMember: type, data: []u8, index: usize, offset: usize, size: usize) -> ?&PartyMemberBase {
        const party_end = offset + size * @sizeOf(TMember);
        if (data.len < party_end) return null;

        const party = ([]TMember)(data[offset..party_end]);
        const pokemon = utils.ptrAt(TMember, party, index) ?? return null;
        return &pokemon.base;
    }
};