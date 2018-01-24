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
    party_size: Little(u32),
    party_offset: Little(u32),
};

pub const PartyMember = packed struct {
    iv: Little(u16),
    level: u8,
    species: Little(u16),
};

pub const PartyMemberWithMoves = packed struct {
    iv: Little(u16),
    level: u8,
    species: Little(u16),
    moves: [4]Little(u16),
};

pub const PartyMemberWithHeld = packed struct {
    iv: Little(u16),
    level: u8,
    species: Little(u16),
    held_item: Little(u16),
};

pub const PartyMemberWithBoth = packed struct {
    iv: Little(u16),
    level: u8,
    species: Little(u16),
    held_item: Little(u16),
    moves: [4]Little(u16),
};

pub const Party = union(PartyType) {
    Standard:  []PartyMember,
    WithMoves: []PartyMemberWithMoves,
    WithHeld:  []PartyMemberWithHeld,
    WithBoth:  []PartyMemberWithBoth,
};

// SOURCE: https://bulbapedia.bulbagarden.net/wiki/List_of_Pok%C3%A9mon_by_index_number_(Generation_III)
// TODO: Can we get this data without hardcoding?
const pokemon_count = 440;

const Offsets = struct {
    // Some bytes here
    trainer_parties:            usize,
    trainer_class_names:        usize,
    trainers:                   usize,
    species_names:              usize,
    move_names:                 usize,
    // Some bytes here
    base_stats:                 usize,
    level_up_learnsets:         usize,
    evolution_table:            usize,
    level_up_learnset_pointers: usize,
    // Some bytes here
};

// TODO: WIP https://github.com/pret/pokeemerald/blob/master/data/data2c.s
const emerald_offsets = Offsets {
    .trainer_parties            = 0x030B62C,
    .trainer_class_names        = 0x030B62C,
    .trainers                   = 0x0310030,
    .species_names              = 0x0310030,
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
    header: gba.Header,
    offsets: &const Offsets,

    unknown1: []u8,

    trainer_parties:     []u8,
    trainer_class_names: []u8,
    trainers:            []Trainer,
    species_names:       []u8,
    //move_names: []u8,

    unknown2: []u8,

    base_stats: []BasePokemon,
    level_up_learnsets: []u8,
    evolution_table: [][5]Evolution,
    //level_up_learnset_pointers: []u8,

    unknown3: []u8,

    pub fn fromFile(file: &io.File, allocator: &mem.Allocator) -> %&Game {
        var res = try allocator.create(Game);
        errdefer allocator.destroy(res);

        res.header = try utils.noAllocRead(gba.Header, file);
        try res.header.validate();

        const offsets = try getOffsets(res.header);
        res.offsets = offsets;

        res.unknown1 = try utils.allocAndRead(u8, file, allocator, offsets.trainer_parties - try file.getPos());
        errdefer allocator.free(res.unknown1);

        res.trainer_parties = try utils.allocAndRead(u8, file, allocator, offsets.trainer_class_names - offsets.trainer_parties);
        errdefer allocator.free(res.trainer_parties);

        res.trainer_class_names = try utils.allocAndRead(u8, file, allocator,  offsets.trainers - offsets.trainer_class_names);
        errdefer allocator.free(res.trainer_class_names);

        res.trainers = try utils.allocAndRead(Trainer, file, allocator, (offsets.species_names - offsets.trainers) / @sizeOf(Trainer));
        errdefer allocator.free(res.trainers);

        res.species_names = try utils.allocAndRead(u8, file, allocator, offsets.move_names - offsets.species_names);
        errdefer allocator.free(res.species_names);

        res.unknown2 = try utils.allocAndRead(u8, file, allocator, offsets.base_stats - (offsets.species_names + res.species_names.len));
        errdefer allocator.free(res.unknown2);

        res.base_stats = try utils.allocAndRead(BasePokemon, file, allocator, (offsets.level_up_learnsets - offsets.base_stats) / @sizeOf(BasePokemon));
        errdefer allocator.free(res.base_stats);

        res.level_up_learnsets = try utils.allocAndRead(u8, file, allocator, offsets.evolution_table - offsets.level_up_learnsets);
        errdefer allocator.free(res.level_up_learnsets);

        res.evolution_table = try utils.allocAndRead([5]Evolution, file, allocator, (offsets.level_up_learnset_pointers - offsets.evolution_table) / @sizeOf([5]Evolution));
        errdefer allocator.free(res.evolution_table);

        var file_stream = io.FileInStream.init(file);
        var stream = &file_stream.stream;

        res.unknown3 = try stream.readAllAlloc(allocator, @maxValue(usize));
        errdefer allocator.free(res.unknown3);

        if ((try file.getPos()) % 0x1000000 != 0)
            return error.InvalidRomSize;

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

    pub fn getTrainerParty(game: &const Game, trainer: &const Trainer) -> %Party {
        if (trainer.party_offset.get() < 0x8000000) return error.InvalidTrainerPartyOffset;

        const offset = trainer.party_offset.get() - 0x8000000;
        const party_table_start = game.offsets.trainer_parties;
        const party_table_end   = game.offsets.trainer_class_names;
        if (offset < party_table_start or party_table_end < offset) return error.InvalidTrainerPartyOffset;

        switch (trainer.party_type) {
            PartyType.Standard => return Party {
                .Standard = try getSpecificParty(PartyMember, game.trainer_parties, offset, trainer.party_size.get(), party_table_end),
            },
            PartyType.WithMoves => return Party {
                .WithMoves = try getSpecificParty(PartyMemberWithMoves, game.trainer_parties, offset, trainer.party_size.get(), party_table_end),
            },
            PartyType.WithHeld => return Party {
                .WithHeld = try getSpecificParty(PartyMemberWithHeld, game.trainer_parties, offset, trainer.party_size.get(), party_table_end),
            },
            PartyType.WithBoth => return Party {
                .WithBoth = try getSpecificParty(PartyMemberWithBoth, game.trainer_parties, offset, trainer.party_size.get(), party_table_end),
            },
            else => return error.InvalidPartyType,
        }
    }

    fn getSpecificParty(comptime TMember: type, trainer_parties: []u8, offset: usize, size: usize, table_end: usize) -> %[]TMember {
        const party_end = offset + size * @sizeOf(TMember);
        if (table_end < party_end) return error.InvalidTrainerPartyOffset;
        return ([]TMember)(trainer_parties[offset..party_end]);
    }

    pub fn validateData(game: &const Game) -> %void {
        if (!mem.eql(u8, bulbasaur_fingerprint, utils.asConstBytes(BasePokemon, game.base_stats[1])))
            return error.NoBulbasaurFound;
    }

    pub fn writeToStream(game: &const Game, stream: &io.OutStream) -> %void {
        try game.header.validate();

        try stream.write(utils.asConstBytes(gba.Header, game.header));
        try stream.write(game.unknown1);
        try stream.write(game.trainer_parties);
        try stream.write(game.trainer_class_names);
        try stream.write(([]u8)(game.trainers));
        try stream.write(game.species_names);
        try stream.write(game.unknown2);
        try stream.write(([]u8)(game.base_stats));
        try stream.write(game.level_up_learnsets);
        try stream.write(([]u8)(game.evolution_table));
        try stream.write(game.unknown3);
    }

    pub fn destroy(game: &const Game, allocator: &mem.Allocator) {
        allocator.free(game.unknown1);
        allocator.free(game.trainer_parties);
        allocator.free(game.trainer_class_names);
        allocator.free(game.trainers);
        allocator.free(game.species_names);
        allocator.free(game.unknown2);
        allocator.free(game.base_stats);
        allocator.free(game.level_up_learnsets);
        allocator.free(game.evolution_table);
        allocator.free(game.unknown3);

        allocator.destroy(game);
    }
};