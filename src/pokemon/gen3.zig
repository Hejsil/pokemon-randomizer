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

test "pokemon.gen3.BasePokemon: Offsets" {
    const stats : BasePokemon = undefined;
    const base = @ptrToInt(&stats);

    assert(@ptrToInt(&stats.hp              ) - base == 00);
    assert(@ptrToInt(&stats.attack          ) - base == 01);
    assert(@ptrToInt(&stats.defense         ) - base == 02);
    assert(@ptrToInt(&stats.speed           ) - base == 03);
    assert(@ptrToInt(&stats.sp_attack       ) - base == 04);
    assert(@ptrToInt(&stats.sp_defense      ) - base == 05);

    assert(@ptrToInt(&stats.type1           ) - base == 06);
    assert(@ptrToInt(&stats.type2           ) - base == 07);

    assert(@ptrToInt(&stats.catch_rate      ) - base == 08);
    assert(@ptrToInt(&stats.base_exp_yield  ) - base == 09);

    assert(@ptrToInt(&stats.ev_yield,       ) - base == 10);
    assert(@ptrToInt(&stats.item1           ) - base == 12);
    assert(@ptrToInt(&stats.item2           ) - base == 14);

    assert(@ptrToInt(&stats.gender          ) - base == 16);
    assert(@ptrToInt(&stats.egg_cycles      ) - base == 17);
    assert(@ptrToInt(&stats.base_friendship ) - base == 18);
    assert(@ptrToInt(&stats.level_up_type   ) - base == 19);

    assert(@ptrToInt(&stats.egg_group1      ) - base == 20);
    assert(@ptrToInt(&stats.egg_group2      ) - base == 21);

    assert(@ptrToInt(&stats.abillity1       ) - base == 22);
    assert(@ptrToInt(&stats.abillity2       ) - base == 23);

    assert(@ptrToInt(&stats.safari_zone_rate) - base == 24);
    assert(@ptrToInt(&stats.color_and_flip  ) - base == 25);
    assert(@ptrToInt(&stats.padding         ) - base == 26);

    assert(@sizeOf(BasePokemon) == 28);
}

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

test "pokemon.gen3.Evolution: Offsets" {
    const evo : Evolution = undefined;
    const base = @ptrToInt(&evo);

    assert(@ptrToInt(&evo.kind   ) - base == 0x00);
    assert(@ptrToInt(&evo.param  ) - base == 0x02);
    assert(@ptrToInt(&evo.target ) - base == 0x04);
    assert(@ptrToInt(&evo.padding) - base == 0x06);

    assert(@sizeOf(Evolution) == 0x08);
}

test "pokemon.gen3.[5]Evolution: Offsets" {
    const evos : [5]Evolution = undefined;
    const base = @ptrToInt(&evos);

    assert(@ptrToInt(&evos[0]) - base == 0x00);
    assert(@ptrToInt(&evos[1]) - base == 0x08);
    assert(@ptrToInt(&evos[2]) - base == 0x10);
    assert(@ptrToInt(&evos[3]) - base == 0x18);
    assert(@ptrToInt(&evos[4]) - base == 0x20);

    assert(@sizeOf([5]Evolution) == 0x08 * 5);
}

// Source: https://bulbapedia.bulbagarden.net/wiki/Pok%C3%A9mon_base_stats_data_structure_in_Generation_III#Fingerprint
const bulbasaur_fingerprint = []u8 { 
    0x2D, 0x31, 0x31, 0x2D, 0x41, 0x41, 0x0C, 0x03, 0x2D, 0x40, 
    0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x1F, 0x14, 0x46, 0x03, 
    0x01, 0x07, 0x41, 0x00, 0x00, 0x03, 0x00, 0x00 
};

const zero_evo = Evolution { 
    .kind = EvolutionKind.Unused,
    .param = Little(u16).init(0),
    .target = Little(u16).init(0),
    .padding = [2]u8{ 0, 0 }
};
const bulbasaur_evos = [5]Evolution {
    Evolution {
        .kind = EvolutionKind.LevelUp,
        .param = Little(u16).init(16),
        .target = Little(u16).init(2),
        .padding = [2]u8{ 0, 0 }
    },
    zero_evo,
    zero_evo,
    zero_evo,
    zero_evo,
};

error InvalidRomSize;

pub const Game = struct {
    header: &gba.Header,
    
    before_base_stats: []u8,
    base_stats: []BasePokemon,

    before_evolution_table: []u8,
    evolution_table: [][5]Evolution,

    last: []u8,

    pub fn fromFile(file: &io.File, allocator: &mem.Allocator) -> %Game {
        const header = %return utils.createAndReadNoEof(gba.Header, file, allocator);
        %defer allocator.destroy(header);
        
        %return header.validate();

        // TODO: These are emerald offsets for now
        const base_stats_offset = 0x03203CC;
        const evolution_table_offset = 0x032531C;

        const bytes_before_base_stats = base_stats_offset - %return file.getPos();
        const before_base_stats = %return utils.allocAndReadNoEof(u8, file, allocator, bytes_before_base_stats);
        %defer allocator.destroy(before_base_stats);

        const base_stats_len = (0x032531C - base_stats_offset) / @sizeOf(BasePokemon);
        const base_stats = %return utils.allocAndReadNoEof(BasePokemon, file, allocator, base_stats_len);

        const bytes_before_evolution_table = evolution_table_offset - %return file.getPos();
        const before_evolution_table = %return utils.allocAndReadNoEof(u8, file, allocator, bytes_before_evolution_table);
        %defer allocator.destroy(before_evolution_table);

        const evolution_table_len = (0x032937C - evolution_table_offset) / @sizeOf([5]Evolution);
        const evolution_table = %return utils.allocAndReadNoEof([5]Evolution, file, allocator, evolution_table_len);

        var file_stream = io.FileInStream.init(file);
        var stream = &file_stream.stream;

        const last = %return stream.readAllAlloc(allocator, @maxValue(usize));

        if ((%return file.getPos()) % 0x1000000 != 0)
            return error.InvalidRomSize;

        return Game {
            .header = header,
            
            .before_base_stats = before_base_stats,
            .base_stats = base_stats,

            .before_evolution_table = before_evolution_table,
            .evolution_table = evolution_table,

            .last = last,
        };
    }

    pub fn writeToStream(game: &const Game, stream: &io.OutStream) -> %void {
        %return game.header.validate();

        %return stream.write(utils.asConstBytes(gba.Header, game.header));
        %return stream.write(game.before_base_stats);
        %return stream.write(([]u8)(game.base_stats));
        %return stream.write(game.before_evolution_table);
        %return stream.write(([]u8)(game.evolution_table));
        %return stream.write(game.last);
    }

    pub fn destroy(game: &const Game, allocator: &mem.Allocator) {
        allocator.destroy(game.header);
        allocator.free(game.before_base_stats);
        allocator.free(game.base_stats);
        allocator.free(game.before_evolution_table);
        allocator.free(game.evolution_table);
        allocator.free(game.last);
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