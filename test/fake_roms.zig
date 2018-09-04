// TODO: When we can test with packages, remove relative path.
const libpoke = @import("../src/pokemon/index.zig");
const nds = @import("../src/nds/index.zig");
const gba = @import("../src/gba.zig");
const utils = @import("../src/utils/index.zig");
const int = @import("../src/int.zig");
const std = @import("std");
const fun = @import("../lib/fun-with-zig/src/index.zig"); // TODO: Package stuff

const mem = std.mem;
const fmt = std.fmt;
const os = std.os;
const math = std.math;
const heap = std.heap;
const debug = std.debug;
const io = std.io;
const path = os.path;
const loop = fun.loop;

const lu16 = int.lu16;
const lu32 = int.lu32;
const lu64 = int.lu64;
const lu128 = int.lu128;

const tmp_folder = "zig-cache" ++ []u8{path.sep} ++  "__fake_roms__" ++ []u8{path.sep};

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
pub const rate = 16;
pub const has_moves = 0b01;
pub const has_item = 0b10;

const trainer_count = 800;
const move_count = 200;
const pokemon_count = 800;
const level_up_move_count = pokemon_count;
const zone_count = 100;

pub fn generateFakeRoms(allocator: *mem.Allocator) ![][]u8 {
    const tmp = try allocator.alloc(u8, 2 * 1024 * 1024);
    defer allocator.free(tmp);

    var tmp_fix_buf_alloc = heap.FixedBufferAllocator.init(tmp[0..]);
    const tmp_allocator = &tmp_fix_buf_alloc.allocator;

    deleteFakeRoms(tmp_allocator);
    try os.makeDir(tmp_folder);
    errdefer deleteFakeRoms(tmp_allocator);

    tmp_fix_buf_alloc = heap.FixedBufferAllocator.init(tmp[0..]);

    var rom_names = std.ArrayList([]u8).init(allocator);
    errdefer {
        for (rom_names.toSliceConst()) |name|
            allocator.free(name);
        rom_names.deinit();
    }

    for (libpoke.gen3.constants.infos) |info| {
        const name = try genGen3FakeRom(tmp_allocator, info);
        try rom_names.append(try mem.dupe(allocator, u8, name));
        tmp_fix_buf_alloc = heap.FixedBufferAllocator.init(tmp[0..]);
    }

    for (libpoke.gen4.constants.infos) |info| {
        const name = try genGen4FakeRom(tmp_allocator, info);
        try rom_names.append(try mem.dupe(allocator, u8, name));
        tmp_fix_buf_alloc = heap.FixedBufferAllocator.init(tmp[0..]);
    }

    for (libpoke.gen5.constants.infos) |info| {
        const name = try genGen5FakeRom(tmp_allocator, info);
        try rom_names.append(try mem.dupe(allocator, u8, name));
        tmp_fix_buf_alloc = heap.FixedBufferAllocator.init(tmp[0..]);
    }

    return rom_names.toOwnedSlice();
}

pub fn deleteFakeRoms(allocator: *mem.Allocator) void {
    os.deleteTree(allocator, tmp_folder) catch {};
}

fn genGen3FakeRom(allocator: *mem.Allocator, info: libpoke.gen3.constants.Info) ![]u8 {
    const name = try fmt.allocPrint(allocator, "{}__{}_{}_{}__", tmp_folder, info.game_title, info.gamecode, @tagName(info.version));
    errdefer allocator.free(name);

    var free_space_offset = getGen3FreeSpace(info);
    var file = try os.File.openWrite(name);
    errdefer os.deleteFile(name) catch {};
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

    for (loop.to(info.trainers.len)) |_, i| {
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
            .party = try libpoke.gen3.Slice(u8).init(@intCast(u32, free_space_offset), party_size),
        }));

        // Output party
        try file.seekTo(free_space_offset);
        for (loop.to(party_size)) |_2, j| {
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

    try file.seekTo(info.moves.start);
    for (loop.to(info.moves.len)) |_, i| {
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

    try file.seekTo(info.machine_learnsets.start);
    for (loop.to(info.machine_learnsets.len)) |_, i| {
        try file.write(lu64.init(0).bytes);
    }

    try file.seekTo(info.base_stats.start);
    for (loop.to(info.base_stats.len)) |_, i| {
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

    for (loop.to(info.level_up_learnset_pointers.len)) |_, i| {
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

    try file.seekTo(info.hms.start);
    for (loop.to(info.hms.len)) |_, i| {
        try file.write(lu16.init(move).bytes);
    }

    try file.seekTo(info.tms.start);
    for (loop.to(info.tms.len)) |_, i| {
        try file.write(lu16.init(move).bytes);
    }

    for (loop.to(info.wild_pokemon_headers.len)) |_, i| {
        try file.seekTo(free_space_offset);
        const lens = []usize{12,5,5,10};
        var offsets: [lens.len]u32 = undefined;
        inline for (lens) |len, j| {
            const offset = try file.getPos();
            for (loop.to(len)) |_2| {
                try file.write(utils.toBytes(libpoke.gen3.WildPokemon, libpoke.gen3.WildPokemon{
                    .min_level = level,
                    .max_level = level,
                    .species = lu16.init(species),
                }));
            }

            offsets[j] = @intCast(u32, try file.getPos());
            try file.write(utils.toBytes(libpoke.gen3.WildPokemonInfo(len), libpoke.gen3.WildPokemonInfo(len){
                .encounter_rate = rate,
                .pad = undefined,
                .wild_pokemons = try libpoke.gen3.Ref([len]libpoke.gen3.WildPokemon).init(@intCast(u32, offset)),
            }));
        }

        free_space_offset = try file.getPos();

        try file.seekTo(info.wild_pokemon_headers.start + i * @sizeOf(libpoke.gen3.WildPokemonHeader));
        try file.write(utils.toBytes(libpoke.gen3.WildPokemonHeader, libpoke.gen3.WildPokemonHeader{
            .map_group = undefined,
            .map_num = undefined,
            .pad = undefined,
            .land_pokemons = try libpoke.gen3.Ref(libpoke.gen3.WildPokemonInfo(12)).init(offsets[0]),
            .surf_pokemons = try libpoke.gen3.Ref(libpoke.gen3.WildPokemonInfo(5)).init(offsets[1]),
            .rock_smash_pokemons = try libpoke.gen3.Ref(libpoke.gen3.WildPokemonInfo(5)).init(offsets[2]),
            .fishing_pokemons = try libpoke.gen3.Ref(libpoke.gen3.WildPokemonInfo(10)).init(offsets[3]),
        }));
    }

    const end = try file.getEndPos();
    try file.seekTo(end);

    const rem = end % 0x1000000;
    if (rem != 0) {
        var file_stream = io.FileOutStream.init(file);
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
    res = math.max(res, info.wild_pokemon_headers.end());

    return math.max(res, info.items.end());
}

fn ndsHeader(game_title: [12]u8, gamecode: [4]u8) nds.Header {
    return nds.Header{
        .game_title = game_title,
        .gamecode = gamecode,
        .makercode = "ST",
        .unitcode = 0x00,
        .encryption_seed_select = 0x00,
        .device_capacity = 0x00,
        .reserved1 = []u8{0} ** 7,
        .reserved2 = 0x00,
        .nds_region = 0x00,
        .rom_version = 0x00,
        .autostart = 0x00,
        .arm9_rom_offset = lu32.init(0x4000),
        .arm9_entry_address = lu32.init(0x2000000),
        .arm9_ram_address = lu32.init(0x2000000),
        .arm9_size = lu32.init(0x3BFE00),
        .arm7_rom_offset = lu32.init(0x8000),
        .arm7_entry_address = lu32.init(0x2000000),
        .arm7_ram_address = lu32.init(0x2000000),
        .arm7_size = lu32.init(0x3BFE00),
        .fnt_offset = lu32.init(0x00),
        .fnt_size = lu32.init(0x00),
        .fat_offset = lu32.init(0x00),
        .fat_size = lu32.init(0x00),
        .arm9_overlay_offset = lu32.init(0x00),
        .arm9_overlay_size = lu32.init(0x00),
        .arm7_overlay_offset = lu32.init(0x00),
        .arm7_overlay_size = lu32.init(0x00),
        .port_40001A4h_setting_for_normal_commands = []u8{0} ** 4,
        .port_40001A4h_setting_for_key1_commands = []u8{0} ** 4,
        .banner_offset = lu32.init(0x00),
        .secure_area_checksum = lu16.init(0x00),
        .secure_area_delay = lu16.init(0x051E),
        .arm9_auto_load_list_ram_address = lu32.init(0x00),
        .arm7_auto_load_list_ram_address = lu32.init(0x00),
        .secure_area_disable = lu64.init(0x00),
        .total_used_rom_size = lu32.init(0x00),
        .rom_header_size = lu32.init(0x4000),
        .reserved3 = []u8{0x00} ** 0x38,
        .nintendo_logo = []u8{0x00} ** 0x9C,
        .nintendo_logo_checksum = lu16.init(0x00),
        .header_checksum = lu16.init(0x00),
        .debug_rom_offset = lu32.init(0x00),
        .debug_size = lu32.init(0x00),
        .debug_ram_address = lu32.init(0x00),
        .reserved4 = []u8{0x00} ** 4,
        .reserved5 = []u8{0x00} ** 0x10,
        .wram_slots = []u8{0x00} ** 20,
        .arm9_wram_areas = []u8{0x00} ** 12,
        .arm7_wram_areas = []u8{0x00} ** 12,
        .wram_slot_master = []u8{0x00} ** 3,
        .unknown = 0,
        .region_flags = []u8{0x00} ** 4,
        .access_control = []u8{0x00} ** 4,
        .arm7_scfg_ext_setting = []u8{0x00} ** 4,
        .reserved6 = []u8{0x00} ** 3,
        .unknown_flags = 0,
        .arm9i_rom_offset = lu32.init(0x00),
        .reserved7 = []u8{0x00} ** 4,
        .arm9i_ram_load_address = lu32.init(0x00),
        .arm9i_size = lu32.init(0x00),
        .arm7i_rom_offset = lu32.init(0x00),
        .device_list_arm7_ram_addr = lu32.init(0x00),
        .arm7i_ram_load_address = lu32.init(0x00),
        .arm7i_size = lu32.init(0x00),
        .digest_ntr_region_offset = lu32.init(0x4000),
        .digest_ntr_region_length = lu32.init(0x00),
        .digest_twl_region_offset = lu32.init(0x00),
        .digest_twl_region_length = lu32.init(0x00),
        .digest_sector_hashtable_offset = lu32.init(0x00),
        .digest_sector_hashtable_length = lu32.init(0x00),
        .digest_block_hashtable_offset = lu32.init(0x00),
        .digest_block_hashtable_length = lu32.init(0x00),
        .digest_sector_size = lu32.init(0x00),
        .digest_block_sectorcount = lu32.init(0x00),
        .banner_size = lu32.init(0x00),
        .reserved8 = []u8{0x00} ** 4,
        .total_used_rom_size_including_dsi_area = lu32.init(0x00),
        .reserved9 = []u8{0x00} ** 4,
        .reserved10 = []u8{0x00} ** 4,
        .reserved11 = []u8{0x00} ** 4,
        .modcrypt_area_1_offset = lu32.init(0x00),
        .modcrypt_area_1_size = lu32.init(0x00),
        .modcrypt_area_2_offset = lu32.init(0x00),
        .modcrypt_area_2_size = lu32.init(0x00),
        .title_id_emagcode = []u8{0x00} ** 4,
        .title_id_filetype = 0,
        .title_id_rest = []u8{ 0x00, 0x03, 0x00 },
        .public_sav_filesize = lu32.init(0x00),
        .private_sav_filesize = lu32.init(0x00),
        .reserved12 = []u8{0x00} ** 176,
        .cero_japan = 0,
        .esrb_us_canada = 0,
        .reserved13 = 0,
        .usk_germany = 0,
        .pegi_pan_europe = 0,
        .resereved14 = 0,
        .pegi_portugal = 0,
        .pegi_and_bbfc_uk = 0,
        .agcb_australia = 0,
        .grb_south_korea = 0,
        .reserved15 = []u8{0x00} ** 6,
        .arm9_hash_with_secure_area = []u8{0x00} ** 20,
        .arm7_hash = []u8{0x00} ** 20,
        .digest_master_hash = []u8{0x00} ** 20,
        .icon_title_hash = []u8{0x00} ** 20,
        .arm9i_hash = []u8{0x00} ** 20,
        .arm7i_hash = []u8{0x00} ** 20,
        .reserved16 = []u8{0x00} ** 40,
        .arm9_hash_without_secure_area = []u8{0x00} ** 20,
        .reserved17 = []u8{0x00} ** 2636,
        .reserved18 = []u8{0x00} ** 0x180,
        .signature_across_header_entries = []u8{0x00} ** 0x80,
    };
}

const ndsBanner = nds.Banner{
    .version = nds.Banner.Version.Original,
    .version_padding = 0,
    .has_animated_dsi_icon = false,
    .has_animated_dsi_icon_padding = 0,
    .crc16_across_0020h_083Fh = lu16.init(0x00),
    .crc16_across_0020h_093Fh = lu16.init(0x00),
    .crc16_across_0020h_0A3Fh = lu16.init(0x00),
    .crc16_across_1240h_23BFh = lu16.init(0x00),
    .reserved1 = []u8{0x00} ** 0x16,
    .icon_bitmap = []u8{0x00} ** 0x200,
    .icon_palette = []u8{0x00} ** 0x20,
    .title_japanese = []u8{0x00} ** 0x100,
    .title_english = []u8{0x00} ** 0x100,
    .title_french = []u8{0x00} ** 0x100,
    .title_german = []u8{0x00} ** 0x100,
    .title_italian = []u8{0x00} ** 0x100,
    .title_spanish = []u8{0x00} ** 0x100,
};

fn repeat(allocator: *mem.Allocator, comptime T: type, m: []const T, n: usize) ![]T {
    const to_alloc = math.mul(usize, m.len, n) catch return mem.Allocator.Error.OutOfMemory;
    const res = try allocator.alloc(T, to_alloc);

    for (loop.to(n)) |_, i| {
        const off = i * m.len;
        mem.copy(T, res[off..], m);
    }

    return res;
}

test "repeat" {
    var buf: [10 * 1024]u8 = undefined;
    var fix_buf_alloc = heap.FixedBufferAllocator.init(buf[0..]);
    const allocator = &fix_buf_alloc.allocator;

    debug.assert(mem.eql(u8, try repeat(allocator, u8, "ab", 0), ""));
    debug.assert(mem.eql(u8, try repeat(allocator, u8, "ab", 1), "ab"));
    debug.assert(mem.eql(u8, try repeat(allocator, u8, "ab", 2), "abab"));
    debug.assert(mem.eql(u8, try repeat(allocator, u8, "ab", 4), "abababab"));
}

fn genGen4FakeRom(allocator: *mem.Allocator, info: libpoke.gen4.constants.Info) ![]u8 {
    const machine_len = libpoke.gen4.constants.tm_count + libpoke.gen4.constants.hm_count;
    const machines = []lu16{comptime lu16.init(move)} ** machine_len;
    const arm9 = try fmt.allocPrint(allocator, "{}{}", info.hm_tm_prefix, @sliceToBytes(machines[0..]));
    defer allocator.free(arm9);

    const rom = nds.Rom{
        .allocator = allocator,
        .header = ndsHeader(info.game_title, info.gamecode),
        .banner = ndsBanner,
        .arm9 = arm9,
        .arm7 = []u8{},
        .nitro_footer = []lu32{comptime lu32.init(0)} ** 3,
        .arm9_overlay_table = []nds.Overlay{},
        .arm9_overlay_files = [][]u8{},
        .arm7_overlay_table = []nds.Overlay{},
        .arm7_overlay_files = [][]u8{},
        .root = try nds.fs.Nitro.create(allocator),
    };
    const root = rom.root;

    {
        // TODO: This can leak on err
        const trainer_narc = try nds.fs.Narc.create(allocator);
        const party_narc = try nds.fs.Narc.create(allocator);
        try trainer_narc.ensureCapacity(trainer_count);
        try party_narc.ensureCapacity(trainer_count);
        _ = try root.createPathAndFile(info.trainers, nds.fs.Nitro.File{
            .Narc = trainer_narc,
        });
        _ = try root.createPathAndFile(info.parties, nds.fs.Nitro.File{
            .Narc = party_narc,
        });

        for (loop.to(trainer_count)) |_, i| {
            var name_buf: [10]u8 = undefined;
            const name = try fmt.bufPrint(name_buf[0..], "{}", i);

            var party_type: u8 = 0;
            if (i & has_moves != 0)
                party_type |= libpoke.gen4.Trainer.has_moves;
            if (i & has_item != 0)
                party_type |= libpoke.gen4.Trainer.has_item;

            {
                const trainer = try allocator.create(libpoke.gen4.Trainer{
                    .party_type = party_type,
                    .class = undefined,
                    .battle_type = undefined,
                    .party_size = party_size,
                    .items = []lu16{comptime lu16.init(item)} ** 4,
                    .ai = undefined,
                    .battle_type2 = undefined,
                });
                errdefer allocator.destroy(trainer);

                _ = try trainer_narc.createFile(name, nds.fs.Narc.File{
                    .allocator = allocator,
                    .data = utils.asBytes(libpoke.gen4.Trainer, trainer)[0..],
                });
            }

            var tmp_buf: [100]u8 = undefined;
            const party_member = libpoke.gen4.PartyMember{
                .iv = undefined,
                .gender = undefined,
                .ability = undefined,
                .level = lu16.init(level),
                .species = species,
                .form = undefined,
            };
            const held_item_bytes = lu16.init(item).bytes;
            const moves_bytes = utils.toBytes([4]lu16, []lu16{comptime lu16.init(move)} ** 4);
            const padding = switch (info.version) {
                libpoke.Version.HeartGold, libpoke.Version.SoulSilver, libpoke.Version.Platinum => usize(2),
                else => usize(0),
            };

            const full_party_member_bytes = try fmt.bufPrint(
                tmp_buf[0..],
                "{}{}{}{}",
                utils.toBytes(libpoke.gen4.PartyMember, party_member)[0..],
                held_item_bytes[0..held_item_bytes.len * @boolToInt(i & has_item != 0)],
                moves_bytes[0..moves_bytes.len * @boolToInt(i & has_moves != 0)],
                ([]u8{0x00} ** 2)[0..padding],
            );
            errdefer allocator.free(full_party_member_bytes);

            _ = try party_narc.createFile(name, nds.fs.Narc.File{
                .allocator = allocator,
                .data = try repeat(allocator, u8, full_party_member_bytes, party_size),
            });
        }
    }

    {
        // TODO: This can leak on err
        const narc = try nds.fs.Narc.create(allocator);
        try narc.ensureCapacity(move_count);
        _ = try root.createPathAndFile(info.moves, nds.fs.Nitro.File{
            .Narc = narc,
        });

        for (loop.to(move_count)) |_, i| {
            var name_buf: [10]u8 = undefined;
            const name = try fmt.bufPrint(name_buf[0..], "{}", i);

            // TODO: This can leak on err
            const gen4_move = try allocator.create(libpoke.gen4.Move{
                .u8_0 = undefined,
                .u8_1 = undefined,
                .category = undefined,
                .power = power,
                .@"type" = @intToEnum(libpoke.gen4.Type, ptype),
                .accuracy = undefined,
                .pp = pp,
                .u8_7 = undefined,
                .u8_8 = undefined,
                .u8_9 = undefined,
                .u8_10 = undefined,
                .u8_11 = undefined,
                .u8_12 = undefined,
                .u8_13 = undefined,
                .u8_14 = undefined,
                .u8_15 = undefined,
            });
            _ = try narc.createFile(name, nds.fs.Narc.File{
                .allocator = allocator,
                .data = utils.asBytes(libpoke.gen4.Move, gen4_move),
            });
        }
    }

    {
        // TODO: This can leak on err
        const narc = try nds.fs.Narc.create(allocator);
        try narc.ensureCapacity(pokemon_count);
        _ = try root.createPathAndFile(info.base_stats, nds.fs.Nitro.File{
            .Narc = narc,
        });

        for (loop.to(pokemon_count)) |_, i| {
            var name_buf: [10]u8 = undefined;
            const name = try fmt.bufPrint(name_buf[0..], "{}", i);

            // TODO: This can leak on err
            const base_stats = try allocator.create(libpoke.gen4.BasePokemon{
                .stats = libpoke.common.Stats{
                    .hp = hp,
                    .attack = attack,
                    .defense = defense,
                    .speed = speed,
                    .sp_attack = sp_attack,
                    .sp_defense = sp_defense,
                },
                .types = [2]libpoke.gen4.Type{
                    @intToEnum(libpoke.gen4.Type, ptype),
                    @intToEnum(libpoke.gen4.Type, ptype),
                },
                .catch_rate = undefined,
                .base_exp_yield = undefined,
                .evs = undefined,
                .items = []lu16{comptime lu16.init(item)} ** 2,
                .gender_ratio = undefined,
                .egg_cycles = undefined,
                .base_friendship = undefined,
                .growth_rate = undefined,
                .egg_group1 = undefined,
                .egg_group1_pad = undefined,
                .egg_group2 = undefined,
                .egg_group2_pad = undefined,
                .abilities = undefined,
                .flee_rate = undefined,
                .color = undefined,
                .color_padding = undefined,
                .machine_learnset = lu128.init(0),
            });
            _ = try narc.createFile(name, nds.fs.Narc.File{
                .allocator = allocator,
                .data = utils.asBytes(libpoke.gen4.BasePokemon, base_stats),
            });
        }
    }

    {
        // TODO: This can leak on err
        const narc = try nds.fs.Narc.create(allocator);
        try narc.ensureCapacity(level_up_move_count);
        _ = try root.createPathAndFile(info.level_up_moves, nds.fs.Nitro.File{
            .Narc = narc,
        });

        for (loop.to(level_up_move_count)) |_, i| {
            var name_buf: [10]u8 = undefined;
            const name = try fmt.bufPrint(name_buf[0..], "{}", i);

            const lvlup_learnset = libpoke.gen4.LevelUpMove{
                .move_id = move,
                .level = level,
            };
            _ = try narc.createFile(name, nds.fs.Narc.File{
                .allocator = allocator,
                // TODO: This can leak on err
                .data = try fmt.allocPrint(
                    allocator,
                    "{}{}",
                    utils.toBytes(libpoke.gen4.LevelUpMove, lvlup_learnset)[0..],
                    []u8{0xFF} ** @sizeOf(libpoke.gen4.LevelUpMove),
                ),
            });
        }
    }

    {
        // TODO: This can leak on err
        const narc = try nds.fs.Narc.create(allocator);
        try narc.ensureCapacity(zone_count);
        _ = try root.createPathAndFile(info.wild_pokemons, nds.fs.Nitro.File{
            .Narc = narc,
        });

        for (loop.to(zone_count)) |_, i| {
            var name_buf: [10]u8 = undefined;
            const name = try fmt.bufPrint(name_buf[0..], "{}", i);

            switch (info.version) {
                libpoke.Version.Diamond, libpoke.Version.Pearl, libpoke.Version.Platinum => {
                    const WildPokemons = libpoke.gen4.DpptWildPokemons;
                    const Grass = WildPokemons.Grass;
                    const Replacement = WildPokemons.Replacement;
                    const Sea = WildPokemons.Sea;
                    const sea = comptime Sea{
                        .level_max = level,
                        .level_min = level,
                        .pad1 = undefined,
                        .species = lu16.init(species),
                        .pad2 = undefined,
                    };

                    // TODO: This can leak on err
                    const wild_pokemon = try allocator.create(WildPokemons{
                        .grass_rate = lu32.init(rate),
                        .grass = []Grass{
                            comptime Grass{
                                .level = level,
                                .pad1 = undefined,
                                .species = lu16.init(species),
                                .pad2 = undefined,
                            },
                        } ** 12,
                        .swarm_replacements = []Replacement{
                            Replacement{
                                .species = comptime lu16.init(species),
                                .pad = undefined,
                            },
                        } ** 2,
                        .day_replacements = []Replacement{
                            Replacement{
                                .species = comptime lu16.init(species),
                                .pad = undefined,
                            },
                        } ** 2,
                        .night_replacements = []Replacement{
                            Replacement{
                                .species = comptime lu16.init(species),
                                .pad = undefined,
                            },
                        } ** 2,
                        .radar_replacements = []Replacement{
                            Replacement{
                                .species = comptime lu16.init(species),
                                .pad = undefined,
                            },
                        } ** 4,
                        .unknown_replacements = []Replacement{
                            Replacement{
                                .species = comptime lu16.init(species),
                                .pad = undefined,
                            },
                        } ** 6,
                        .gba_replacements = []Replacement{
                            Replacement{
                                .species = comptime lu16.init(species),
                                .pad = undefined,
                            },
                        } ** 10,
                        .surf = []Sea{sea} ** 5,
                        .sea_unknown = []Sea{sea} ** 5,
                        .old_rod = []Sea{sea} ** 5,
                        .good_rod = []Sea{sea} ** 5,
                        .super_rod = []Sea{sea} ** 5,
                    });

                    _ = try narc.createFile(name, nds.fs.Narc.File{
                        .allocator = allocator,
                        .data = utils.asBytes(WildPokemons, wild_pokemon),
                    });
                },
                libpoke.Version.HeartGold, libpoke.Version.SoulSilver => {
                    const WildPokemons = libpoke.gen4.HgssWildPokemons;
                    const Sea = WildPokemons.Sea;
                    const sea = comptime Sea{
                        .level_min = level,
                        .level_max = level,
                        .species = lu16.init(species),
                    };

                    // TODO: This can leak on err
                    const wild_pokemon = try allocator.create(WildPokemons{
                        .grass_rate = rate,
                        .sea_rates = []u8{rate} ** 5,
                        .unknown = undefined,
                        .grass_levels = []u8{level} ** 12,
                        .grass_morning = []lu16{comptime lu16.init(species)} ** 12,
                        .grass_day = []lu16{comptime lu16.init(species)} ** 12,
                        .grass_night = []lu16{comptime lu16.init(species)} ** 12,
                        .radio = []lu16{comptime lu16.init(species)} ** 4,
                        .surf = []Sea{sea} ** 5,
                        .sea_unknown = []Sea{sea} ** 2,
                        .old_rod = []Sea{sea} ** 5,
                        .good_rod = []Sea{sea} ** 5,
                        .super_rod = []Sea{sea} ** 5,
                        .swarm = []lu16{comptime lu16.init(species)} ** 4,
                    });

                    _ = try narc.createFile(name, nds.fs.Narc.File{
                        .allocator = allocator,
                        .data = utils.asBytes(WildPokemons, wild_pokemon),
                    });
                },
                else => unreachable,
            }
        }
    }

    const name = try fmt.allocPrint(allocator, "{}__{}_{}_{}__", tmp_folder, info.game_title, info.gamecode, @tagName(info.version));
    errdefer allocator.free(name);

    var file = try os.File.openWrite(name);
    errdefer os.deleteFile(name) catch {};
    defer file.close();

    try rom.writeToFile(file, allocator);

    return name;
}

fn genGen5FakeRom(allocator: *mem.Allocator, info: libpoke.gen5.constants.Info) ![]u8 {
    const machine_len = libpoke.gen5.constants.tm_count + libpoke.gen5.constants.hm_count;
    const machines = []lu16{comptime lu16.init(move)} ** machine_len;
    const arm9 = try fmt.allocPrint(allocator, "{}{}", libpoke.gen5.constants.hm_tm_prefix, @sliceToBytes(machines[0..]));
    defer allocator.free(arm9);

    const rom = nds.Rom{
        .allocator = allocator,
        .header = ndsHeader(info.game_title, info.gamecode),
        .banner = ndsBanner,
        .arm9 = arm9,
        .arm7 = []u8{},
        .nitro_footer = []lu32{comptime lu32.init(0)} ** 3,
        .arm9_overlay_table = []nds.Overlay{},
        .arm9_overlay_files = [][]u8{},
        .arm7_overlay_table = []nds.Overlay{},
        .arm7_overlay_files = [][]u8{},
        .root = try nds.fs.Nitro.create(allocator),
    };
    const root = rom.root;

    {
        // TODO: This can leak on err
        const trainer_narc = try nds.fs.Narc.create(allocator);
        const party_narc = try nds.fs.Narc.create(allocator);
        try trainer_narc.ensureCapacity(trainer_count);
        try party_narc.ensureCapacity(trainer_count);
        _ = try root.createPathAndFile(info.trainers, nds.fs.Nitro.File{
            .Narc = trainer_narc,
        });
        _ = try root.createPathAndFile(info.parties, nds.fs.Nitro.File{
            .Narc = party_narc,
        });

        for (loop.to(trainer_count)) |_, i| {
            var name_buf: [10]u8 = undefined;
            const name = try fmt.bufPrint(name_buf[0..], "{}", i);

            var party_type: u8 = 0;
            if (i & has_moves != 0)
                party_type |= libpoke.gen5.Trainer.has_moves;
            if (i & has_item != 0)
                party_type |= libpoke.gen5.Trainer.has_item;

            // TODO: This can leak on err
            const trainer = try allocator.create(libpoke.gen5.Trainer{
                .party_type = party_type,
                .class = undefined,
                .battle_type = undefined,
                .party_size = party_size,
                .items = []lu16{comptime lu16.init(item)} ** 4,
                .ai = undefined,
                .healer = undefined,
                .healer_padding = undefined,
                .cash = undefined,
                .post_battle_item = undefined,
            });
            _ = try trainer_narc.createFile(name, nds.fs.Narc.File{
                .allocator = allocator,
                .data = utils.asBytes(libpoke.gen5.Trainer, trainer)[0..],
            });

            var tmp_buf: [100]u8 = undefined;
            const party_member = libpoke.gen5.PartyMember{
                .iv = undefined,
                .gender = undefined,
                .ability = undefined,
                .level = level,
                .padding = undefined,
                .species = lu16.init(species),
                .form = undefined,
            };
            const held_item_bytes = lu16.init(item).bytes;
            const moves_bytes = utils.toBytes([4]lu16, []lu16{comptime lu16.init(move)} ** 4);

            // TODO: This can leak on err
            const full_party_member_bytes = try fmt.bufPrint(
                tmp_buf[0..],
                "{}{}{}",
                utils.toBytes(libpoke.gen5.PartyMember, party_member)[0..],
                held_item_bytes[0..held_item_bytes.len * @boolToInt(i & has_item != 0)],
                moves_bytes[0..moves_bytes.len * @boolToInt(i & has_moves != 0)],
            );

            _ = try party_narc.createFile(name, nds.fs.Narc.File{
                .allocator = allocator,
                .data = try repeat(allocator, u8, full_party_member_bytes, party_size),
            });
        }
    }

    {
        // TODO: This can leak on err
        const narc = try nds.fs.Narc.create(allocator);
        try narc.ensureCapacity(move_count);
        _ = try root.createPathAndFile(info.moves, nds.fs.Nitro.File{
            .Narc = narc,
        });

        for (loop.to(move_count)) |_, i| {
            var name_buf: [10]u8 = undefined;
            const name = try fmt.bufPrint(name_buf[0..], "{}", i);

            // TODO: This can leak on err
            const gen5_move = try allocator.create(libpoke.gen5.Move{
                .@"type" = @intToEnum(libpoke.gen5.Type, ptype),
                .effect_category = undefined,
                .category = undefined,
                .power = power,
                .accuracy = undefined,
                .pp = pp,
                .priority = undefined,
                .hits = undefined,
                .min_hits = undefined,
                .max_hits = undefined,
                .crit_chance = undefined,
                .flinch = undefined,
                .effect = undefined,
                .target_hp = undefined,
                .user_hp = undefined,
                .target = undefined,
                .stats_affected = undefined,
                .stats_affected_magnetude = undefined,
                .stats_affected_chance = undefined,
                .padding = undefined,
                .flags = undefined,
            });
            _ = try narc.createFile(name, nds.fs.Narc.File{
                .allocator = allocator,
                .data = utils.asBytes(libpoke.gen5.Move, gen5_move),
            });
        }
    }

    {
        // TODO: This can leak on err
        const narc = try nds.fs.Narc.create(allocator);
        try narc.ensureCapacity(pokemon_count);
        _ = try root.createPathAndFile(info.base_stats, nds.fs.Nitro.File{
            .Narc = narc,
        });

        for (loop.to(pokemon_count)) |_, i| {
            var name_buf: [10]u8 = undefined;
            const name = try fmt.bufPrint(name_buf[0..], "{}", i);

            // TODO: This can leak on err
            const base_stats = try allocator.create(libpoke.gen5.BasePokemon{
                .stats = libpoke.common.Stats{
                    .hp = hp,
                    .attack = attack,
                    .defense = defense,
                    .speed = speed,
                    .sp_attack = sp_attack,
                    .sp_defense = sp_defense,
                },
                .types = [2]libpoke.gen5.Type{
                    @intToEnum(libpoke.gen5.Type, ptype),
                    @intToEnum(libpoke.gen5.Type, ptype),
                },
                .catch_rate = undefined,
                .evs = undefined,
                .items = []lu16{comptime lu16.init(item)} ** 3,
                .gender_ratio = undefined,
                .egg_cycles = undefined,
                .base_friendship = undefined,
                .growth_rate = undefined,
                .egg_group1 = undefined,
                .egg_group1_pad = undefined,
                .egg_group2 = undefined,
                .egg_group2_pad = undefined,
                .abilities = undefined,
                .flee_rate = undefined,
                .form_stats_start = undefined,
                .form_sprites_start = undefined,
                .form_count = undefined,
                .color = undefined,
                .color_padding = undefined,
                .base_exp_yield = undefined,
                .height = undefined,
                .weight = undefined,
                .machine_learnset = undefined,
            });
            _ = try narc.createFile(name, nds.fs.Narc.File{
                .allocator = allocator,
                .data = utils.asBytes(libpoke.gen5.BasePokemon, base_stats),
            });
        }
    }

    {
        // TODO: This can leak on err
        const narc = try nds.fs.Narc.create(allocator);
        try narc.ensureCapacity(level_up_move_count);
        _ = try root.createPathAndFile(info.level_up_moves, nds.fs.Nitro.File{
            .Narc = narc,
        });

        for (loop.to(level_up_move_count)) |_, i| {
            var name_buf: [10]u8 = undefined;
            const name = try fmt.bufPrint(name_buf[0..], "{}", i);

            const lvlup_learnset = libpoke.gen5.LevelUpMove{
                .move_id = lu16.init(move),
                .level = lu16.init(level),
            };
            _ = try narc.createFile(name, nds.fs.Narc.File{
                .allocator = allocator,
                // TODO: This can leak on err
                .data = try fmt.allocPrint(
                    allocator,
                    "{}{}",
                    utils.toBytes(libpoke.gen5.LevelUpMove, lvlup_learnset)[0..],
                    []u8{0xFF} ** @sizeOf(libpoke.gen5.LevelUpMove),
                ),
            });
        }
    }

    {
        // TODO: This can leak on err
        const narc = try nds.fs.Narc.create(allocator);
        try narc.ensureCapacity(level_up_move_count);
        _ = try root.createPathAndFile(info.wild_pokemons, nds.fs.Nitro.File{
            .Narc = narc,
        });

        for (loop.to(zone_count)) |_, i| {
            var name_buf: [10]u8 = undefined;
            const name = try fmt.bufPrint(name_buf[0..], "{}", i);

            const WildPokemon = libpoke.gen5.WildPokemon;
            const wild_pokemon = comptime WildPokemon{
                .species = lu16.init(species),
                .level_min = level,
                .level_max = level,
            };

            // TODO: This can leak on err
            const wild_pokemons = try allocator.create(libpoke.gen5.WildPokemons{
                .rates = []u8{rate} ** 7,
                .pad = undefined,
                .grass = []WildPokemon{wild_pokemon} ** 12,
                .dark_grass = []WildPokemon{wild_pokemon} ** 12,
                .rustling_grass = []WildPokemon{wild_pokemon} ** 12,
                .surf = []WildPokemon{wild_pokemon} ** 5,
                .ripple_surf = []WildPokemon{wild_pokemon} ** 5,
                .fishing = []WildPokemon{wild_pokemon} ** 5,
                .ripple_fishing = []WildPokemon{wild_pokemon} ** 5,
            });

            _ = try narc.createFile(name, nds.fs.Narc.File{
                .allocator = allocator,
                .data = utils.asBytes(libpoke.gen5.WildPokemons, wild_pokemons),
            });
        }
    }

    const name = try fmt.allocPrint(allocator, "{}__{}_{}_{}__", tmp_folder, info.game_title, info.gamecode, @tagName(info.version));
    errdefer allocator.free(name);

    var file = try os.File.openWrite(name);
    errdefer os.deleteFile(name) catch {};
    defer file.close();

    try rom.writeToFile(file, allocator);

    return name;
}
