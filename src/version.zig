const std = @import("std");
const utils = @import("utils.zig");
const nds = @import("nds/index.zig");
const mem = std.mem;
const debug = std.debug;
const File = std.io.File;
const Pair = utils.Pair;

const NdsHeader = nds.header.Header;

error UnknownVersion;

pub const Version = enum {
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

    pub fn fromFile(rom: &File) -> %Version {
        const prev = %return rom.getPos();
        defer _ = rom.seekTo(prev);

        nds_block: {
            var header : NdsHeader = undefined;
            const read = %return rom.read(utils.asBytes(NdsHeader, &header));

            if (read != @sizeOf(NdsHeader)) break :nds_block;
            header.validate() %% break :nds_block;
            return Version.fromNdsHeader(&header) %% break :nds_block;
        }

        // TODO: We only focus on NDS roms, for now. Add other roms later on

        return error.UnknownVersion;
    }

    pub fn fromNdsHeader(header: &const NdsHeader) -> %Version {
        const nintendo_makercode = "01";
        const Game = Pair([]const u8, Version);
        const games = []Game {
            Game.init("IRB", Version.Black),
            Game.init("IRA", Version.White),
            Game.init("IRE", Version.Black2),
            Game.init("IRD", Version.White2),
            Game.init("ADA", Version.Diamond),
            Game.init("APA", Version.Pearl),
            Game.init("CPU", Version.Platinum),
        };

        if (!mem.eql(u8, header.makercode, nintendo_makercode)) return error.UnknownVersion;

        for (games) |game| {
            if (mem.startsWith(u8, header.gamecode, game.first)) {
                return game.second;
            }
        }            
        
        return error.UnknownVersion;
    }

    pub fn gen(self: Version) -> u8 {
        const V = Version;
        return switch (self) {
            V.Red,  V.Blue,     V.Yellow   => u8(1),
            V.Gold, V.Silver,   V.Crystal  => u8(2),
            V.Ruby, V.Sapphire, V.Emerald,
            V.FireRed, V.LeafGreen,        => u8(3),
            V.Diamond, V.Pearl, V.Platinum,
            V.HeartGold, V.SoulSilver,     => u8(4),
            V.Black,  V.White,
            V.Black2, V.White2,            => u8(5),
            V.X, V.Y, V.OmegaRuby, 
            V.AlphaSapphire,               => u8(6),
            V.Sun, V.Moon, V.UltraSun,
            V.UltraMoon,                   => u8(7)
        };
    }

    pub fn hasPhysicalSpecialSplit(self: Version) -> bool {
        return self.gen() > 3;
    }
};