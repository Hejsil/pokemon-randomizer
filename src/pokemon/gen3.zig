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

// SOURCE: https://bulbapedia.bulbagarden.net/wiki/List_of_Pok%C3%A9mon_by_index_number_(Generation_III)
// TODO: Can we get this data without hardcoding?
const pokemon_count = 440;

const Offsets = struct {
    base_stats:      usize,
    evolution_table: usize,

    fn assertNoOverlap(self: &const Offsets) -> void {
        assert(self.base_stats + inBytes(BasePokemon, pokemon_count)       <= self.evolution_table);
        //assert(self.evolution_table + inBytes([5]Evolution, pokemon_count) <= SOMETHING);
    }

    fn inBytes(comptime T: type, count: usize) -> usize {
        return @sizeOf(T) * count;
    }
};

// TODO: WIP https://github.com/pret/pokeemerald/blob/master/data/data2c.s
const emerald_offsets = Offsets {
    .base_stats      = 0x03203CC,
    .evolution_table = 0x032531C,
};

comptime { 
    emerald_offsets.assertNoOverlap(); 
}

error InvalidRomSize;
error InvalidGen3PokemonHeader;
error NoBulbasaurFound;

const bulbasaur_fingerprint = []u8 {
    0x2D, 0x31, 0x31, 0x2D, 0x41, 0x41, 0x0C, 0x03, 0x2D, 0x40, 0x00, 0x01, 0x00, 0x00, 
    0x00, 0x00, 0x1F, 0x14, 0x46, 0x03, 0x01, 0x07, 0x41, 0x00, 0x00, 0x03, 0x00, 0x00,
};

pub const Game = struct {
    header: &gba.Header,
    
    unknown1: []u8,
    base_stats: []BasePokemon,

    unknown2: []u8,
    evolution_table: [][5]Evolution,

    unknown3: []u8,

    pub fn fromFile(file: &io.File, allocator: &mem.Allocator) -> %Game {
        const header = try utils.createAndReadNoEof(gba.Header, file, allocator);
        %defer allocator.destroy(header);
        
        try header.validate();
        const offsets = try getOffsets(header);

        const unknown1 = try utils.allocAndReadNoEof(u8, file, allocator, offsets.base_stats - try file.getPos());
        %defer allocator.free(unknown1);

        const base_stats = try utils.allocAndReadNoEof(BasePokemon, file, allocator, pokemon_count);
        %defer allocator.free(base_stats);

        const unknown2 = try utils.allocAndReadNoEof(u8, file, allocator, offsets.evolution_table - try file.getPos());
        %defer allocator.free(unknown2);

        const evolution_table = try utils.allocAndReadNoEof([5]Evolution, file, allocator, pokemon_count);
        %defer allocator.free(evolution_table);

        var file_stream = io.FileInStream.init(file);
        var stream = &file_stream.stream;

        const unknown3 = try stream.readAllAlloc(allocator, @maxValue(usize));

        if ((try file.getPos()) % 0x1000000 != 0)
            return error.InvalidRomSize;

        return Game {
            .header = header,
            
            .unknown1 = unknown1,
            .base_stats = base_stats,

            .unknown2 = unknown2,
            .evolution_table = evolution_table,

            .unknown3 = unknown3,
        };
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

        try stream.write(utils.asConstBytes(gba.Header, game.header));
        try stream.write(game.unknown1);
        try stream.write(([]u8)(game.base_stats));
        try stream.write(game.unknown2);
        try stream.write(([]u8)(game.evolution_table));
        try stream.write(game.unknown3);
    }

    pub fn destroy(game: &const Game, allocator: &mem.Allocator) {
        allocator.destroy(game.header);
        allocator.free(game.unknown1);
        allocator.free(game.base_stats);
        allocator.free(game.unknown2);
        allocator.free(game.evolution_table);
        allocator.free(game.unknown3);
    }
};

error InvalidGeneration;
error OutOfRange;

pub const GameAdapter = struct {
    game: &Game,
    base: common.IGame,

    pub fn init(game: &Game) -> GameAdapter {
        return GameAdapter {
            .game = game,
            .base = common.IGame {
                .getPokemonFn = getPokemon,
                .setPokemonFn = setPokemon
            }
        };
    }

    fn getGame(base: &common.IGame) -> &Game {
        return @fieldParentPtr(GameAdapter, "base", base).game;
    }

    fn getPokemon(base: &common.IGame, index: usize) -> ?common.BasePokemon {
        const game = getGame(base);

        if (index < game.base_stats.len) {
            const pokemon = game.base_stats[index];

            return common.BasePokemon {
                .hp             = pokemon.hp,
                .attack         = pokemon.attack,
                .defense        = pokemon.defense,
                .speed          = pokemon.speed,
                .sp_attack      = pokemon.sp_attack,
                .sp_defense     = pokemon.sp_defense,
                .type1          = pokemon.type1,
                .type2          = pokemon.type2,
                .catch_rate     = pokemon.catch_rate,
                .base_exp_yield = pokemon.base_exp_yield,
                .growth_rate    = pokemon.growth_rate,
                
                .extra = common.BasePokemon.Extra {
                    .III = common.BasePokemon.Gen3Extra {
                        .item1            = pokemon.item1.get(),
                        .item2            = pokemon.item2.get(),
                        .gender_ratio     = pokemon.gender_ratio,
                        .egg_cycles       = pokemon.egg_cycles,
                        .egg_group1       = pokemon.egg_group1,
                        .egg_group2       = pokemon.egg_group2,
                        .ev_yield         = pokemon.ev_yield,
                        .base_friendship  = pokemon.base_friendship,
                        .abillity1        = pokemon.abillity1,
                        .abillity2        = pokemon.abillity2,
                        .safari_zone_rate = pokemon.safari_zone_rate,
                        .color            = pokemon.color,
                        .flip             = pokemon.flip,
                    }
                }
            };
        } else {
            return null;
        }
    }

    fn setPokemon(base: &common.IGame, index: usize, pokemon: &const common.BasePokemon) -> %void {
        var game = getGame(base);

        if (game.base_stats.len <= index) 
            return error.OutOfRange;

        switch (pokemon.extra) {
            common.Generation.III => |extra| {
                game.base_stats[index] = BasePokemon {
                    .hp               = pokemon.hp,
                    .attack           = pokemon.attack,
                    .defense          = pokemon.defense,
                    .speed            = pokemon.speed,
                    .sp_attack        = pokemon.sp_attack,
                    .sp_defense       = pokemon.sp_defense,
                    .type1            = pokemon.type1,
                    .type2            = pokemon.type2,
                    .catch_rate       = pokemon.catch_rate,
                    .base_exp_yield   = pokemon.base_exp_yield,
                    .ev_yield         = extra.ev_yield,
                    .item1            = Little(u16).init(extra.item1),
                    .item2            = Little(u16).init(extra.item2),
                    .gender_ratio     = extra.gender_ratio,
                    .egg_cycles       = extra.egg_cycles,
                    .base_friendship  = extra.base_friendship,
                    .growth_rate      = pokemon.growth_rate,
                    .egg_group1       = extra.egg_group1,
                    .egg_group1_pad   = 0,
                    .egg_group2       = extra.egg_group2,
                    .egg_group2_pad   = 0,
                    .abillity1        = extra.abillity1,
                    .abillity2        = extra.abillity2,
                    .safari_zone_rate = extra.safari_zone_rate,
                    .color            = extra.color,
                    .flip             = extra.flip,
                    .padding          = [2]u8 { 0, 0 }
                };
            },
            else => return error.InvalidGeneration,
        }
    }
};

comptime {
    assert(@offsetOf(BasePokemon, "hp")               == 0x00);
    assert(@offsetOf(BasePokemon, "attack")           == 0x01);
    assert(@offsetOf(BasePokemon, "defense")          == 0x02);
    assert(@offsetOf(BasePokemon, "speed")            == 0x03);
    assert(@offsetOf(BasePokemon, "sp_attack")        == 0x04);
    assert(@offsetOf(BasePokemon, "sp_defense")       == 0x05);

    assert(@offsetOf(BasePokemon, "type1")            == 0x06);
    assert(@offsetOf(BasePokemon, "type2")            == 0x07);

    assert(@offsetOf(BasePokemon, "catch_rate")       == 0x08);
    assert(@offsetOf(BasePokemon, "base_exp_yield")   == 0x09);

    assert(@offsetOf(BasePokemon, "ev_yield")         == 0x0A);
    assert(@offsetOf(BasePokemon, "item1")            == 0x0C);
    assert(@offsetOf(BasePokemon, "item2")            == 0x0E);

    assert(@offsetOf(BasePokemon, "gender_ratio")     == 0x10);
    assert(@offsetOf(BasePokemon, "egg_cycles")       == 0x11);
    assert(@offsetOf(BasePokemon, "base_friendship")  == 0x12);
    assert(@offsetOf(BasePokemon, "growth_rate")      == 0x13);

    assert(@offsetOf(BasePokemon, "egg_group1")       == 0x14);
    assert(@offsetOf(BasePokemon, "egg_group2")       == 0x15);

    assert(@offsetOf(BasePokemon, "abillity1")        == 0x16);
    assert(@offsetOf(BasePokemon, "abillity2")        == 0x17);

    assert(@offsetOf(BasePokemon, "safari_zone_rate") == 0x18);
    assert(@offsetOf(BasePokemon, "color")            == 0x19);
    assert(@offsetOf(BasePokemon, "padding")          == 0x1A);

    assert(@sizeOf(BasePokemon) == 0x1C);
}

comptime {
    assert(@offsetOf(Evolution, "kind")    == 0x00);
    assert(@offsetOf(Evolution, "param")   == 0x02);
    assert(@offsetOf(Evolution, "target")  == 0x04);
    assert(@offsetOf(Evolution, "padding") == 0x06);

    assert(@sizeOf(Evolution) == 0x08);
}