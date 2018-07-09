const libpoke = @import("index.zig");
const int = @import("../int.zig");
const std = @import("std");
const fun = @import("fun");
const mem = std.mem;
const debug = std.debug;
const generic = fun.generic;

const lu16 = int.lu16;
const lu32 = int.lu32;
const lu64 = int.lu64;

pub fn Section(comptime Item: type) type {
    return struct {
        const Self = this;

        start: usize,
        len: usize,

        pub fn init(data_slice: []const u8, items: []const Item) Self {
            const data_ptr = @ptrToInt(data_slice.ptr);
            const item_ptr = @ptrToInt(items.ptr);
            debug.assert(data_ptr <= item_ptr);
            debug.assert(item_ptr + items.len * @sizeOf(Item) <= data_ptr + data_slice.len);

            return Self{
                .start = item_ptr - data_ptr,
                .len = items.len,
            };
        }

        pub fn end(offset: Self) usize {
            return offset.start + @sizeOf(Item) * offset.len;
        }

        pub fn slice(offset: Self, data: []u8) []Item {
            return @bytesToSlice(Item, data[offset.start..offset.end()]);
        }
    };
}

pub const TrainerSection = Section(libpoke.gen3.Trainer);
pub const MoveSection = Section(libpoke.gen3.Move);
pub const MachineLearnsetSection = Section(lu64);
pub const BaseStatsSection = Section(libpoke.gen3.BasePokemon);
pub const EvolutionSection = Section([5]libpoke.common.Evolution);
pub const LevelUpLearnsetPointerSection = Section(libpoke.gen3.Ref(libpoke.gen3.LevelUpMove));
pub const HmSection = Section(lu16);
pub const TmSection = Section(lu16);
pub const ItemSection = Section(libpoke.gen3.Item);

pub const Info = struct {
    game_title: [12]u8,
    gamecode: [4]u8,
    version: libpoke.Version,

    trainers: TrainerSection,
    moves: MoveSection,
    machine_learnsets: MachineLearnsetSection,
    base_stats: BaseStatsSection,
    evolutions: EvolutionSection,
    level_up_learnset_pointers: LevelUpLearnsetPointerSection,
    hms: HmSection,
    tms: TmSection,
    items: ItemSection,
};

pub const infos = []Info{
    emerald_us_info,
    ruby_us_info,
    sapphire_us_info,
    fire_us_info,
    leaf_us_info,
};

const emerald_us_info = Info{
    .game_title = "POKEMON EMER",
    .gamecode = "BPEE",
    .version = libpoke.Version.Emerald,

    .trainers = TrainerSection{
        .start = 0x0310030,
        .len = 855,
    },
    .moves = MoveSection{
        .start = 0x031C898,
        .len = 355,
    },
    .machine_learnsets = MachineLearnsetSection{
        .start = 0x031E898,
        .len = 412,
    },
    .base_stats = BaseStatsSection{
        .start = 0x03203CC,
        .len = 412,
    },
    .evolutions = EvolutionSection{
        .start = 0x032531C,
        .len = 412,
    },
    .level_up_learnset_pointers = LevelUpLearnsetPointerSection{
        .start = 0x032937C,
        .len = 412,
    },
    .hms = HmSection{
        .start = 0x0329EEA,
        .len = 008,
    },
    .tms = TmSection{
        .start = 0x0615B94,
        .len = 050,
    },
    .items = ItemSection{
        .start = 0x05839A0,
        .len = 377,
    },
};

pub const ruby_us_info = Info{
    .game_title = "POKEMON RUBY",
    .gamecode = "AXVE",
    .version = libpoke.Version.Ruby,

    .trainers = TrainerSection{
        .start = 0x01F0514,
        .len = 339,
    },
    .moves = MoveSection{
        .start = 0x01FB144,
        .len = 355,
    },
    .machine_learnsets = MachineLearnsetSection{
        .start = 0x01FD108,
        .len = 412,
    },
    .base_stats = BaseStatsSection{
        .start = 0x01FEC30,
        .len = 412,
    },
    .evolutions = EvolutionSection{
        .start = 0x0203B80,
        .len = 412,
    },
    .level_up_learnset_pointers = LevelUpLearnsetPointerSection{
        .start = 0x0207BE0,
        .len = 412,
    },
    .hms = HmSection{
        .start = 0x0208332,
        .len = 008,
    },
    .tms = TmSection{
        .start = 0x037651C,
        .len = 050,
    },
    .items = ItemSection{
        .start = 0x03C5580,
        .len = 349,
    },
};

pub const sapphire_us_info = Info{
    .game_title = "POKEMON SAPP",
    .gamecode = "AXPE",
    .version = libpoke.Version.Sapphire,

    .trainers = TrainerSection{
        .start = 0x01F04A4,
        .len = 339,
    },
    .moves = MoveSection{
        .start = 0x01FB0D4,
        .len = 355,
    },
    .machine_learnsets = MachineLearnsetSection{
        .start = 0x01FD098,
        .len = 412,
    },
    .base_stats = BaseStatsSection{
        .start = 0x01FEBC0,
        .len = 412,
    },
    .evolutions = EvolutionSection{
        .start = 0x0203B10,
        .len = 412,
    },
    .level_up_learnset_pointers = LevelUpLearnsetPointerSection{
        .start = 0x0207B70,
        .len = 412,
    },
    .hms = HmSection{
        .start = 0x02082C2,
        .len = 008,
    },
    .tms = TmSection{
        .start = 0x03764AC,
        .len = 050,
    },
    .items = ItemSection{
        .start = 0x03C55DC,
        .len = 349,
    },
};

pub const fire_us_info = Info{
    .game_title = "POKEMON FIRE",
    .gamecode = "BPRE",
    .version = libpoke.Version.FireRed,

    .trainers = TrainerSection{
        .start = 0x023EB38,
        .len = 439,
    },
    .moves = MoveSection{
        .start = 0x0250C74,
        .len = 355,
    },
    .machine_learnsets = MachineLearnsetSection{
        .start = 0x0252C38,
        .len = 412,
    },
    .base_stats = BaseStatsSection{
        .start = 0x02547F4,
        .len = 412,
    },
    .evolutions = EvolutionSection{
        .start = 0x02597C4,
        .len = 412,
    },
    .level_up_learnset_pointers = LevelUpLearnsetPointerSection{
        .start = 0x025D824,
        .len = 412,
    },
    .hms = HmSection{
        .start = 0x025E084,
        .len = 008,
    },
    .tms = TmSection{
        .start = 0x045A604,
        .len = 050,
    },
    .items = ItemSection{
        .start = 0x03DB098,
        .len = 374,
    },
};

pub const leaf_us_info = Info{
    .game_title = "POKEMON LEAF",
    .gamecode = "BPGE",
    .version = libpoke.Version.LeafGreen,

    .trainers = TrainerSection{
        .start = 0x023EB14,
        .len = 439,
    },
    .moves = MoveSection{
        .start = 0x0250C50,
        .len = 355,
    },
    .machine_learnsets = MachineLearnsetSection{
        .start = 0x0252C14,
        .len = 412,
    },
    .base_stats = BaseStatsSection{
        .start = 0x02547D0,
        .len = 412,
    },
    .evolutions = EvolutionSection{
        .start = 0x02597A4,
        .len = 412,
    },
    .level_up_learnset_pointers = LevelUpLearnsetPointerSection{
        .start = 0x025D804,
        .len = 412,
    },
    .hms = HmSection{
        .start = 0x025E064,
        .len = 008,
    },
    .tms = TmSection{
        .start = 0x045A034,
        .len = 050,
    },
    .items = ItemSection{
        .start = 0x03DAED4,
        .len = 374,
    },
};
