const std    = @import("std");
const gba    = @import("../gba.zig");
const little = @import("../little.zig");
const utils  = @import("../utils.zig");
const common = @import("common.zig");

const mem   = std.mem;
const debug = std.debug;
const io    = std.io;

const assert = debug.assert;
const u9     = @IntType(false, 9);

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
    flip: bool,

    padding: [2]u8
};

pub const EvolutionType = enum(u16) {
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
    @"type": EvolutionType,
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

pub const Move = packed struct {
    effect: u8,
    power: u8,
    @"type": common.Type,
    accuracy: u8,
    pp: u8,
    side_effect_chance: u8,
    target: u8,
    priority: u8,
    flags: Little(u32),
};

pub const LevelUpMove = packed struct {
    level: u7,
    move_id: u9,
};

pub const Item = packed struct {
    name: [14]u8,
    id: Little(u16),
    price: Little(u16),
    unknown1: [2]u8,
    description_offset: Little(u32),
    unknown2: [2]u8,
    pocked: u8,
    unknown3: u8,
    out_battle_effect_offset: Little(u32),
    unknown5: Little(u32),
    in_battle_effect_offset: Little(u32),
    unknown6: Little(u32),
};

const Offset = struct {
    start: usize,
    end: usize,

    fn slice(offset: &const Offset, comptime T: type, data: []u8) []T {
        return ([]T)(data[offset.start..offset.end]);
    }
};

const Offsets = struct {
    trainers:                   Offset,
    moves:                      Offset,
    tm_hm_learnset:             Offset,
    base_stats:                 Offset,
    evolution_table:            Offset,
    level_up_learnset_pointers: Offset,
    hms:                        Offset,
    items:                      Offset,
    tms:                        Offset,
};

// TODO: WIP https://github.com/pret/pokeemerald/blob/master/data/data2c.s
const emerald_offsets = Offsets {
    .trainers                   = Offset { .start = 0x0310030, .end = 0x03185C8 },
    .moves                      = Offset { .start = 0x031C898, .end = 0x031D93C },
    .tm_hm_learnset             = Offset { .start = 0x031E898, .end = 0x031F578 },
    .base_stats                 = Offset { .start = 0x03203CC, .end = 0x03230DC },
    .evolution_table            = Offset { .start = 0x032531C, .end = 0x032937C },
    .level_up_learnset_pointers = Offset { .start = 0x032937C, .end = 0x03299EC },
    .hms                        = Offset { .start = 0x0329EEA, .end = 0x0329EFC },
    .items                      = Offset { .start = 0x05839A0, .end = 0x0587A6C },
    .tms                        = Offset { .start = 0x0616040, .end = 0x06160B4 },
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
    moves: []Move,
    tm_hm_learnset: []Little(u64),
    base_stats: []BasePokemon,
    evolution_table: [][5]Evolution,
    level_up_learnset_pointers: []Little(u32),
    hms: []Little(u16),
    items: []Item,
    tms: []Little(u16),

    pub fn fromFile(file: &io.File, allocator: &mem.Allocator) %&Game {
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
        *res = Game {
            .offsets                    = offsets,
            .data                       = rom,
            .header                     = @ptrCast(&gba.Header, &rom[0]),
            .trainers                   = offsets.trainers.slice(Trainer, rom),
            .moves                      = offsets.moves.slice(Move, rom),
            .tm_hm_learnset             = offsets.tm_hm_learnset.slice(Little(u64), rom),
            .base_stats                 = offsets.base_stats.slice(BasePokemon, rom),
            .evolution_table            = offsets.evolution_table.slice([5]Evolution, rom),
            .level_up_learnset_pointers = offsets.level_up_learnset_pointers.slice(Little(u32), rom),
            .hms                        = offsets.hms.slice(Little(u16), rom),
            .items                      = offsets.items.slice(Item, rom),
            .tms                        = offsets.tms.slice(Little(u16), rom),
        };

        return res;
    }

    fn getOffsets(header: &const gba.Header) %&const Offsets {
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

    pub fn validateData(game: &const Game) %void {
        if (!mem.eql(u8, bulbasaur_fingerprint, utils.asConstBytes(BasePokemon, game.base_stats[1])))
            return error.NoBulbasaurFound;
    }

    pub fn writeToStream(game: &const Game, stream: &io.OutStream) %void {
        try game.header.validate();
        try stream.write(game.data);
    }

    pub fn destroy(game: &const Game, allocator: &mem.Allocator) void {
        allocator.free(game.data);
        allocator.destroy(game);
    }

    pub fn getBasePokemon(game: &const Game, index: usize) ?&BasePokemon {
        return utils.ptrAt(BasePokemon, game.base_stats, index);
    }

    pub fn getTrainer(game: &const Game, index: usize) ?&Trainer {
        return utils.ptrAt(Trainer, game.trainers, index);
    }

    pub fn getTrainerPokemon(game: &const Game, trainer: &const Trainer, index: usize) ?&PartyMemberBase {
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

    fn getBasePartyMember(comptime TMember: type, data: []u8, index: usize, offset: usize, size: usize) ?&PartyMemberBase {
        const party_end = offset + size * @sizeOf(TMember);
        if (data.len < party_end) return null;

        const party = ([]TMember)(data[offset..party_end]);
        const pokemon = utils.ptrAt(TMember, party, index) ?? return null;
        return &pokemon.base;
    }

    pub fn getMove(game: &const Game, index: usize) ?&Move {
        return utils.ptrAt(Move, game.moves, index);
    }

    pub fn getMoveCount(game: &const Game) usize {
        return game.moves.len;
    }

    pub fn getLevelupMoves(game: &const Game, species: usize) ?[]LevelUpMove {
        const offset = blk: {
            const res = utils.itemAt(Little(u32), game.level_up_learnset_pointers, species) ?? return null;
            if (res.get() < 0x8000000) return null;
            break :blk res.get() - 0x8000000;
        };
        if (game.data.len < offset) return null;

        const end = blk: {
            var i : usize = offset;
            while (true) : (i += @sizeOf(LevelUpMove)) {
                if (game.data.len < i)     return null;
                if (game.data.len < i + 1) return null;
                if (game.data[i] == 0xFF and game.data[i+1] == 0xFF) break;
            }

            break :blk i;
        };

        return ([]LevelUpMove)(game.data[offset..end]);
    }

    pub fn getTms(game: &const Game) []Little(u16) {
        return game.tms;
    }

    pub fn getHms(game: &const Game) []Little(u16) {
        return game.hms;
    }

    pub fn getTmHmLearnset(game: &const Game, species: usize) ?&Little(u64) {
        return utils.ptrAt(Little(u64), game.tm_hm_learnset, species);
    }
};