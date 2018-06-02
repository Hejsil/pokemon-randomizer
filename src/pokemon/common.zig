const little = @import("../little.zig");

const toLittle = little.toLittle;
const Little = little.Little;

const u9 = @IntType(false, 9);

pub const MoveCategory = enum(u8) {
    Physical = 0x00,
    Status = 0x01,
    Special = 0x02,
};

pub const GrowthRate = enum(u8) {
    MediumFast = 0x00,
    Erratic = 0x01,
    Fluctuating = 0x02,
    MediumSlow = 0x03,
    Fast = 0x04,
    Slow = 0x05,
};

pub const EggGroup = enum(u4) {
    Invalid = 0x00, // TODO: Figure out if there is a 0x00 egg group
    Monster = 0x01,
    Water1 = 0x02,
    Bug = 0x03,
    Flying = 0x04,
    Field = 0x05,
    Fairy = 0x06,
    Grass = 0x07,
    HumanLike = 0x08,
    Water3 = 0x09,
    Mineral = 0x0A,
    Amorphous = 0x0B,
    Water2 = 0x0C,
    Ditto = 0x0D,
    Dragon = 0x0E,
    Undiscovered = 0x0F,
};

pub const Color = enum(u7) {
    Red = 0x00,
    Blue = 0x01,
    Yellow = 0x02,
    Green = 0x03,
    Black = 0x04,
    Brown = 0x05,
    Purple = 0x06,
    Gray = 0x07,
    White = 0x08,
    Pink = 0x09,
};

// TODO: Figure out if the this have the same layout in all games that have it.
//       They probably have, so let's assume that for now and if a bug
//       is ever encountered related to this, we figure it out.
pub const EvYield = packed struct {
    hp: u2,
    attack: u2,
    defense: u2,
    speed: u2,
    sp_attack: u2,
    sp_defense: u2,
    padding: u4,
};

pub const LevelUpMove = packed struct {
    move_id: u9,
    level: u7,
};

pub const Evolution = packed struct {
    method: Evolution.Method,
    param: Little(u16),
    target: Little(u16),
    padding: [2]u8,

    pub const Method = enum(u16) {
        Unused = toLittle(u16(0x00)).get(),
        FriendShip = toLittle(u16(0x01)).get(),
        FriendShipDuringDay = toLittle(u16(0x02)).get(),
        FriendShipDuringNight = toLittle(u16(0x03)).get(),
        LevelUp = toLittle(u16(0x04)).get(),
        Trade = toLittle(u16(0x05)).get(),
        TradeHoldingItem = toLittle(u16(0x06)).get(),
        UseItem = toLittle(u16(0x07)).get(),
        AttackGthDefense = toLittle(u16(0x08)).get(),
        AttackEqlDefense = toLittle(u16(0x09)).get(),
        AttackLthDefense = toLittle(u16(0x0A)).get(),
        PersonalityValue1 = toLittle(u16(0x0B)).get(),
        PersonalityValue2 = toLittle(u16(0x0C)).get(),
        LevelUpMaySpawnPokemon = toLittle(u16(0x0D)).get(),
        LevelUpSpawnIfCond = toLittle(u16(0x0E)).get(),
        Beauty = toLittle(u16(0x0F)).get(),
    };
};

pub const Generation = enum(u8) {
    I = 1,
    II = 2,
    III = 3,
    IV = 4,
    V = 5,
    VI = 6,
    VII = 7,

    pub fn hasPhysicalSpecialSplit(gen: Generation) bool {
        return u8(gen) > 3;
    }
};

pub const Version = enum(u8) {
    Red,
    Blue,
    Yellow,

    Gold,
    Silver,
    Crystal,

    Ruby,
    Sapphire,
    Emerald,
    FireRed,
    LeafGreen,

    Diamond,
    Pearl,
    Platinum,
    HeartGold,
    SoulSilver,

    Black,
    White,
    Black2,
    White2,

    X,
    Y,
    OmegaRuby,
    AlphaSapphire,

    Sun,
    Moon,
    UltraSun,
    UltraMoon,

    pub fn generation(version: Version) Generation {
        const V = Version;
        // TODO: Fix format
        return switch (version) {
            V.Red, V.Blue, V.Yellow => Generation.I,
            V.Gold, V.Silver, V.Crystal => Generation.II,
            V.Ruby, V.Sapphire, V.Emerald, V.FireRed, V.LeafGreen => Generation.III,
            V.Diamond, V.Pearl, V.Platinum, V.HeartGold, V.SoulSilver => Generation.IV,
            V.Black, V.White, V.Black2, V.White2 => Generation.V,
            V.X, V.Y, V.OmegaRuby, V.AlphaSapphire => Generation.VI,
            V.Sun, V.Moon, V.UltraSun, V.UltraMoon => Generation.VII,
        };
    }
};

// TODO: Fix format
pub const legendaries = []u16{
    144, 145, 146, // Articuno, Zapdos, Moltres
    150, 151, // Mewtwo, Mew
        243,
    244, 245, // Raikou, Entei, Suicune
        249,
    250, 251, // Lugia, Ho-Oh, Celebi
        377,
    378, 379, // Regirock, Regice, Registeel
        380,
    381, // Latias, Latios
        382, 383,
    384, // Kyogre, Groudon, Rayquaza
        385, 386, // Jirachi, Deoxys
    480, 481, 482, // Uxie, Mesprit, Azelf
    483, 484, // Dialga, Palkia
        485,
    486, // Heatran, Regigigas
        487, 488, // Giratina, Cresselia
    489, 490, // Phione, Manaphy
        491,
    492, 493, // Darkrai, Shaymin, Arceus
        494, // Victini
    638, 639, 640, // Cobalion, Terrakion, Virizion
    641, 642, // Tornadus, Thundurus
        643,
    644, // Reshiram, Zekrom
        645, 646,
    647, // Landorus, Kyurem, Keldeo
        648, 649, // Meloetta, Genesect
    716, 717, 718, // Xerneas, Yveltal, Zygarde
    719, 720, 721, // Diancie, Hoopa, Volcanion
    // TODO: Sun and Moon legendaries
};
