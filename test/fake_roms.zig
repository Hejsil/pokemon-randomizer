// TODO: When we can test with packages, remove relative path.
const libpoke = @import("../src/pokemon/index.zig");
const nds = @import("../src/nds/index.zig");
const gba = @import("../src/gba.zig");
const utils = @import("../src/utils/index.zig");
const int = @import("../src/int.zig");
const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const os = std.os;
const math = std.math;
const debug = std.debug;
const io = std.io;

const lu16 = int.lu16;
const lu32 = int.lu32;
const lu64 = int.lu64;

const tmp_folder = "__fake_roms__";

pub const level = 1;
pub const party_size = 2;
pub const species = 3;
pub const item = 4;
pub const move = 5;
pub const power = 6;
pub const ptype = 7;
pub const pp = 8;
pub const hp = 10;
pub const attack = 11;
pub const defense = 12;
pub const speed = 13;
pub const sp_attack = 14;
pub const sp_defense = 15;
pub const has_moves = 0b01;
pub const has_item = 0b10;

pub fn generateFakeRoms(allocator: *mem.Allocator) ![][]u8 {
    deleteFakeRoms(allocator);
    try os.makeDir(allocator, tmp_folder);
    errdefer deleteFakeRoms(allocator);

    var rom_names = std.ArrayList([]u8).init(allocator);
    errdefer {
        for (rom_names.toSliceConst()) |name|
            allocator.free(name);
        rom_names.deinit();
    }

    for (libpoke.gen3.constants.infos) |info, i| {
        try rom_names.append(try genGen3FakeRom(allocator, info));
    }

    return rom_names.toOwnedSlice();
}

pub fn deleteFakeRoms(allocator: *mem.Allocator) void {
    os.deleteTree(allocator, tmp_folder) catch {};
}

fn genGen3FakeRom(allocator: *mem.Allocator, info: libpoke.gen3.constants.Info) ![]u8 {
    const name = try fmt.allocPrint(allocator, "{}/__{}_{}_{}__", tmp_folder, info.game_title, info.gamecode, @tagName(info.version));
    errdefer allocator.free(name);

    var free_space_offset = getGen3FreeSpace(info);
    var file = try os.File.openWrite(allocator, name);
    errdefer os.deleteFile(allocator, name) catch {};
    defer file.close();

    const header = gba.Header{
        .rom_entry_point = undefined,
        .nintendo_logo = undefined,
        .game_title = info.game_title,
        .gamecode = info.gamecode,
        .makercode = "AA",
        .fixed_value = 0x96,
        .main_unit_code = undefined,
        .device_type = undefined,
        .reserved1 = []u8{0} ** 7,
        .software_version = undefined,
        .complement_check = undefined,
        .reserved2 = []u8{0} ** 2,
    };
    try file.write(utils.toBytes(gba.Header, header));

    {
        var i: usize = 0;
        while (i < info.trainers.len) : (i += 1) {
            var party_type: u8 = 0;
            if (i & has_moves != 0)
                party_type |= libpoke.gen3.Trainer.has_moves;
            if (i & has_item != 0)
                party_type |= libpoke.gen3.Trainer.has_item;

            // Output trainer
            try file.seekTo(info.trainers.start + i * @sizeOf(libpoke.gen3.Trainer));
            try file.write(utils.toBytes(libpoke.gen3.Trainer, libpoke.gen3.Trainer{
                .party_type = party_type,
                .class = undefined,
                .encounter_music = undefined,
                .trainer_picture = undefined,
                .name = undefined,
                .items = undefined,
                .is_double = undefined,
                .ai = undefined,
                .party_size = lu32.init(party_size),
                .party_offset = lu32.init(@intCast(u32, free_space_offset + 0x8000000)),
            }));

            // Output party
            try file.seekTo(free_space_offset);
            var j: usize = 0;
            while (j < party_size) : (j += 1) {
                try file.write(utils.toBytes(libpoke.gen3.PartyMember, libpoke.gen3.PartyMember{
                    .iv = undefined,
                    .level = lu16.init(level),
                    .species = lu16.init(species),
                }));
                if (party_type & libpoke.gen3.Trainer.has_item != 0)
                    try file.write(lu16.init(item).bytes);
                if (party_type & libpoke.gen3.Trainer.has_moves != 0) {
                    try file.write(lu16.init(move).bytes);
                    try file.write(lu16.init(move).bytes);
                    try file.write(lu16.init(move).bytes);
                    try file.write(lu16.init(move).bytes);
                }
                if (party_type & libpoke.gen3.Trainer.has_item == 0)
                    try file.write([]u8{ 0x00, 0x00 });
            }

            free_space_offset = try file.getPos();
        }
    }

    {
        try file.seekTo(info.moves.start);
        var i: usize = 0;
        while (i < info.moves.len) : (i += 1) {
            try file.write(utils.toBytes(libpoke.gen3.Move, libpoke.gen3.Move{
                .effect = undefined,
                .power = power,
                .@"type" = @intToEnum(libpoke.gen3.Type, ptype),
                .accuracy = undefined,
                .pp = pp,
                .side_effect_chance = undefined,
                .target = undefined,
                .priority = undefined,
                .flags = undefined,
            }));
        }
    }

    {
        try file.seekTo(info.machine_learnsets.start);
        var i: usize = 0;
        while (i < info.machine_learnsets.len) : (i += 1) {
            try file.write(lu64.init(0).bytes);
        }
    }

    {
        try file.seekTo(info.base_stats.start);
        var i: usize = 0;
        while (i < info.base_stats.len) : (i += 1) {
            try file.write(utils.toBytes(libpoke.gen3.BasePokemon, libpoke.gen3.BasePokemon{
                .stats = libpoke.common.Stats{
                    .hp = hp,
                    .attack = attack,
                    .defense = defense,
                    .speed = speed,
                    .sp_attack = sp_attack,
                    .sp_defense = sp_defense,
                },
                .types = [2]libpoke.gen3.Type{
                    @intToEnum(libpoke.gen3.Type, ptype),
                    @intToEnum(libpoke.gen3.Type, ptype),
                },
                .catch_rate = undefined,
                .base_exp_yield = undefined,
                .ev_yield = undefined,
                .items = undefined,
                .gender_ratio = undefined,
                .egg_cycles = undefined,
                .base_friendship = undefined,
                .growth_rate = undefined,
                .egg_group1 = undefined,
                .egg_group1_pad = undefined,
                .egg_group2 = undefined,
                .egg_group2_pad = undefined,
                .abilities = undefined,
                .safari_zone_rate = undefined,
                .color = undefined,
                .flip = undefined,
                .padding = undefined,
            }));
        }
    }

    {
        // TODO: We don't expose evolutions through the api yet, so lets not output it yet.
    }

    {
        var i: usize = 0;
        while (i < info.level_up_learnset_pointers.len) : (i += 1) {
            try file.seekTo(info.level_up_learnset_pointers.start + i * @sizeOf(lu32));
            try file.write(lu32.init(@intCast(u32, free_space_offset + 0x8000000)).bytes);

            try file.seekTo(free_space_offset);
            try file.write(utils.toBytes(libpoke.gen3.LevelUpMove, libpoke.gen3.LevelUpMove{
                .move_id = move,
                .level = level,
            }));
            try file.write([]u8{ 0xFF, 0xFF });

            free_space_offset = try file.getPos();
        }
    }

    {
        try file.seekTo(info.hms.start);
        var i: usize = 0;
        while (i < info.hms.len) : (i += 1) {
            try file.write(lu16.init(move).bytes);
        }
    }

    {
        try file.seekTo(info.tms.start);
        var i: usize = 0;
        while (i < info.tms.len) : (i += 1) {
            try file.write(lu16.init(move).bytes);
        }
    }

    {
        // TODO: We don't expose items through the api yet, so lets not output it yet.
    }

    const end = try file.getEndPos();
    try file.seekTo(end);

    const rem = end % 0x1000000;
    if (rem != 0) {
        var file_stream = io.FileOutStream.init(&file);
        var buf_stream = io.BufferedOutStream(io.FileOutStream.Error).init(&file_stream.stream);
        var stream = &buf_stream.stream;
        try stream.writeByteNTimes(0, 0x1000000 - rem);
        try buf_stream.flush();
    }

    return name;
}

fn getGen3FreeSpace(info: libpoke.gen3.constants.Info) usize {
    var res = info.trainers.end();

    res = math.max(res, info.moves.end());
    res = math.max(res, info.machine_learnsets.end());
    res = math.max(res, info.base_stats.end());
    res = math.max(res, info.evolutions.end());
    res = math.max(res, info.level_up_learnset_pointers.end());
    res = math.max(res, info.hms.end());
    res = math.max(res, info.tms.end());

    return math.max(res, info.items.end());
}

fn genGen4FakeRom(allocator: *mem.Allocator, info: libpoke.gen4.constants.Info) ![]u8 {
    const machine_len = libpoke.gen4.constants.tm_count + libpoke.gen4.constants.hm_count;
    const machines = []lu16{move} ** machine_len;
    const arm9 = try fmt.allocPrint(allocator, "{}{}", info.hm_tm_prefix, @sliceToBytes(machines[0..]));
    defer allocator.free(arm9);

    const rom = nds.Rom{
        .allocator = allocator,
        .header = nds.Header{},
        .banner = nds.Banner{},
        .arm9 = arm9,
        .arm7 = []u8{},
        .nitro_footer = []lu32{lu32.init(0)} ** 3,
        .arm9_overlay_table = []Overlay{},
        .arm9_overlay_files = [][]u8{},
        .arm7_overlay_table = []Overlay{},
        .arm7_overlay_files = [][]u8{},
        .file_system = try nds.fs.Nitro.alloc(allocator),
    };
    const fs = rom.file_system;

    {
        // Gen trainers
    }

    {
        // Gen moves
    }

    {
        // Gen base pokemons
    }

    {
        // Gen lvl up learnset
    }

    const name = try fmt.allocPrint(allocator, "{}/__{}_{}_{}__", tmp_folder, info.game_title, info.gamecode, @tagName(info.version));
    errdefer allocator.free(name);
}
