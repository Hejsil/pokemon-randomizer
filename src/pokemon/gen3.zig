const std    = @import("std");
const gba    = @import("../gba.zig");
const little = @import("../little.zig");
const utils  = @import("../utils/index.zig");
const common = @import("common.zig");

const mem   = std.mem;
const debug = std.debug;
const io    = std.io;
const os    = std.os;
const slice = utils.slice;

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

    types: [2]common.Type,

    catch_rate:     u8,
    base_exp_yield: u8,

    ev_yield: common.EvYield,

    items: [2]Little(u16),

    gender_ratio:    u8,
    egg_cycles:      u8,
    base_friendship: u8,

    growth_rate: common.GrowthRate,

    egg_group1: common.EggGroup,
    egg_group1_pad: u4,
    egg_group2: common.EggGroup,
    egg_group2_pad: u4,

    abilities: [2]u8,
    safari_zone_rate: u8,

    color: common.Color,
    flip: bool,

    padding: [2]u8
};

pub const EvolutionType = enum(u16) {
    Unused                 = toLittle(u16(0x00)).get(),
    FriendShip             = toLittle(u16(0x01)).get(),
    FriendShipDuringDay    = toLittle(u16(0x02)).get(),
    FriendShipDuringNight  = toLittle(u16(0x03)).get(),
    LevelUp                = toLittle(u16(0x04)).get(),
    Trade                  = toLittle(u16(0x05)).get(),
    TradeHoldingItem       = toLittle(u16(0x06)).get(),
    UseItem                = toLittle(u16(0x07)).get(),
    AttackGthDefense       = toLittle(u16(0x08)).get(),
    AttackEqlDefense       = toLittle(u16(0x09)).get(),
    AttackLthDefense       = toLittle(u16(0x0A)).get(),
    PersonalityValue1      = toLittle(u16(0x0B)).get(),
    PersonalityValue2      = toLittle(u16(0x0C)).get(),
    LevelUpMaySpawnPokemon = toLittle(u16(0x0D)).get(),
    LevelUpSpawnIfCond     = toLittle(u16(0x0E)).get(),
    Beauty                 = toLittle(u16(0x0F)).get(),
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
    hold_effect: u8,
    hold_effect_param: u8,
    description_offset: Little(u32),
    importance: u8,
    unknown: u8,
    pocked: u8,
    @"type": u8,
    field_use_func: Little(u32),
    battle_usage: Little(u32),
    battle_use_func: Little(u32),
    secondary_id: Little(u32),
};

const Offset = struct {
    start: usize,
    end: usize,

    fn getSlice(offset: &const Offset, comptime T: type, data: []u8) []T {
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

const bulbasaur_fingerprint = []u8 {
    0x2D, 0x31, 0x31, 0x2D, 0x41, 0x41, 0x0C, 0x03, 0x2D, 0x40, 0x00, 0x01, 0x00, 0x00,
    0x00, 0x00, 0x1F, 0x14, 0x46, 0x03, 0x01, 0x07, 0x41, 0x00, 0x00, 0x03, 0x00, 0x00,
};

pub const Game = struct {
    const legendaries = []u16 {
        0x090, 0x091, 0x092, // Articuno, Zapdos, Moltres
        0x096, 0x097,        // Mewtwo, Mew
        0x0F3, 0x0F4, 0x0F5, // Raikou, Entei, Suicune
        0x0F9, 0x0FA, 0x0FB, // Lugia, Ho-Oh, Celebi
        0x191, 0x192, 0x193, // Regirock, Regice, Registeel
        0x194, 0x195, 0x196, // Kyogre, Groudon, Rayquaza
        0x197, 0x198,        // Latias, Latios
        0x199, 0x19A,        // Jirachi, Deoxys
    };

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

    pub fn fromFile(file: &os.File, allocator: &mem.Allocator) !Game {
        var file_out_stream = io.FileInStream.init(file);
        var out_stream = &file_out_stream.stream;

        const header = try utils.file.read(file, gba.Header);
        try header.validate();
        try file.seekTo(0);

        const offsets = try getOffsets(header);
        const rom = try out_stream.readAllAlloc(allocator, @maxValue(usize));
        errdefer allocator.free(rom);

        if (rom.len % 0x1000000 != 0) return error.InvalidRomSize;

        return Game {
            .offsets                    = offsets,
            .data                       = rom,
            .header                     = @ptrCast(&gba.Header, &rom[0]),
            .trainers                   = offsets.trainers.getSlice(Trainer, rom),
            .moves                      = offsets.moves.getSlice(Move, rom),
            .tm_hm_learnset             = offsets.tm_hm_learnset.getSlice(Little(u64), rom),
            .base_stats                 = offsets.base_stats.getSlice(BasePokemon, rom),
            .evolution_table            = offsets.evolution_table.getSlice([5]Evolution, rom),
            .level_up_learnset_pointers = offsets.level_up_learnset_pointers.getSlice(Little(u32), rom),
            .hms                        = offsets.hms.getSlice(Little(u16), rom),
            .items                      = offsets.items.getSlice(Item, rom),
            .tms                        = offsets.tms.getSlice(Little(u16), rom),
        };
    }

    pub fn writeToStream(game: &const Game, out_stream: var) !void {
        try game.header.validate();
        try out_stream.write(game.data);
    }

    pub fn destroy(game: &const Game, allocator: &mem.Allocator) void {
        allocator.free(game.data);
    }

    // TODO: When we are able to allocate at comptime, construct a HashMap
    //       that maps struct { game_title: []const u8, gamecode: []const u8, } -> Offsets
    // game_title: POKEMON EMER
    // gamecode: BPEE
    const emerald_us_offsets = Offsets {
        .trainers                   = Offset { .start = 0x0310030, .end = 0x03185C8, },
        .moves                      = Offset { .start = 0x031C898, .end = 0x031D93C, },
        .tm_hm_learnset             = Offset { .start = 0x031E898, .end = 0x031F578, },
        .base_stats                 = Offset { .start = 0x03203CC, .end = 0x03230DC, },
        .evolution_table            = Offset { .start = 0x032531C, .end = 0x032937C, },
        .level_up_learnset_pointers = Offset { .start = 0x032937C, .end = 0x03299EC, },
        .hms                        = Offset { .start = 0x0329EEA, .end = 0x0329EFC, },
        .items                      = Offset { .start = 0x05839A0, .end = 0x0587A6C, },
        .tms                        = Offset { .start = 0x0615B94, .end = 0x0615C08, },
    };

    // game_title: POKEMON RUBY
    // gamecode: AXVE
    const ruby_us_offsets = Offsets {
        .trainers                   = Offset { .start = 0x01F0514, .end = 0x01F3A0C, },
        .moves                      = Offset { .start = 0x01FB144, .end = 0x01FC1E8, },
        .tm_hm_learnset             = Offset { .start = 0x01FD108, .end = 0x01FDDE8, },
        .base_stats                 = Offset { .start = 0x01FEC30, .end = 0x0201940, },
        .evolution_table            = Offset { .start = 0x0203B80, .end = 0x0207BE0, },
        .level_up_learnset_pointers = Offset { .start = 0x0207BE0, .end = 0x0208250, },
        .hms                        = Offset { .start = 0x0208332, .end = 0x0208344, },
        .items                      = Offset { .start = 0x03C5580, .end = 0x03C917C, },
        .tms                        = Offset { .start = 0x037651C, .end = 0x0376590, },
    };

    // game_title: POKEMON SAPP
    // gamecode: AXPE
    const sapphire_us_offsets = Offsets {
        .trainers                   = Offset { .start = 0x01F04A4, .end = 0x01F399C, },
        .moves                      = Offset { .start = 0x01FB0D4, .end = 0x01FC178, },
        .tm_hm_learnset             = Offset { .start = 0x01FD098, .end = 0x01FDD78, },
        .base_stats                 = Offset { .start = 0x01FEBC0, .end = 0x02018D0, },
        .evolution_table            = Offset { .start = 0x0203B10, .end = 0x0207B70, },
        .level_up_learnset_pointers = Offset { .start = 0x0207B70, .end = 0x02081E0, },
        .hms                        = Offset { .start = 0x02082C2, .end = 0x02082D4, },
        .items                      = Offset { .start = 0x03C55DC, .end = 0x03C91D8, },
        .tms                        = Offset { .start = 0x03764AC, .end = 0x0376520, },
    };

    fn getOffsets(header: &const gba.Header) !&const Offsets {
        if (mem.eql(u8, header.game_title, "POKEMON EMER")) return &emerald_us_offsets;
        if (mem.eql(u8, header.game_title, "POKEMON RUBY")) return &ruby_us_offsets;
        if (mem.eql(u8, header.game_title, "POKEMON SAPP")) return &sapphire_us_offsets;

        return error.InvalidGen3PokemonHeader;
    }

    pub fn validateData(game: &const Game) !void {
        if (!mem.eql(u8, bulbasaur_fingerprint, utils.asBytes(game.base_stats[1])))
            return error.NoBulbasaurFound;
    }

    pub fn getBasePokemon(game: &const Game, index: usize) ?&BasePokemon {
        return slice.ptrAtOrNull(game.base_stats, index);
    }

    pub fn getTrainer(game: &const Game, index: usize) ?&Trainer {
        return slice.ptrAtOrNull(game.trainers, index);
    }

    pub fn getTrainerPokemon(game: &const Game, trainer: &const Trainer, index: usize) ?&PartyMemberBase {
        if (trainer.party_offset.get() < 0x8000000) return null;

        const offset = trainer.party_offset.get() - 0x8000000;

        return switch (trainer.party_type) {
            PartyType.Standard =>  getBasePartyMember(PartyMember, game.data, index, offset, trainer.party_size.get()),
            PartyType.WithMoves => getBasePartyMember(PartyMemberWithMoves, game.data, index, offset, trainer.party_size.get()),
            PartyType.WithHeld =>  getBasePartyMember(PartyMemberWithHeld, game.data, index, offset, trainer.party_size.get()),
            PartyType.WithBoth =>  getBasePartyMember(PartyMemberWithBoth, game.data, index, offset, trainer.party_size.get()),
            else => null,
        };
    }

    fn getBasePartyMember(comptime TMember: type, data: []u8, index: usize, offset: usize, size: usize) ?&PartyMemberBase {
        const party_end = offset + size * @sizeOf(TMember);
        if (data.len < party_end) return null;

        const party = ([]TMember)(data[offset..party_end]);
        const pokemon = utils.slice.ptrAtOrNull(party, index) ?? return null;
        return &pokemon.base;
    }

    pub fn getMove(game: &const Game, index: usize) ?&Move { return utils.slice.ptrAtOrNull(game.moves, index); }
    pub fn getMoveCount(game: &const Game) usize { return game.moves.len; }

    pub fn getLevelupMoves(game: &const Game, species: usize) ?[]LevelUpMove {
        const offset = blk: {
            const res = utils.slice.atOrNull(game.level_up_learnset_pointers, species) ?? return null;
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

    pub fn getTms(game: &const Game) []Little(u16) { return game.tms; }
    pub fn getHms(game: &const Game) []Little(u16) { return game.hms; }

    pub fn getTmHmLearnset(game: &const Game, species: usize) ?&Little(u64) {
        return utils.slice.ptrAtOrNull(game.tm_hm_learnset, species);
    }
};
