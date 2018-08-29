const libpoke = @import("../src/pokemon/index.zig");
const utils = @import("../src/utils/index.zig");
const fakes = @import("fake_roms.zig");
const std = @import("std");
const heap = std.heap;
const os = std.os;
const debug = std.debug;
const rand = std.rand;
const math = std.math;
const time = os.time;
const loop = utils.loop;

const max_alloc = 100 * 1024 * 1024;

const Randomizer = @import("../src/randomizer.zig").Randomizer;
const Options = @import("../src/randomizer.zig").Options;

test "Fake rom: Api" {
    var direct_alloc = heap.DirectAllocator.init();
    const buf = try direct_alloc.allocator.alloc(u8, max_alloc);
    defer direct_alloc.allocator.free(buf);

    var gen_alloc = heap.FixedBufferAllocator.init(buf);
    const roms_files = try fakes.generateFakeRoms(&gen_alloc.allocator);
    defer fakes.deleteFakeRoms(&gen_alloc.allocator);

    var timer = try time.Timer.start();

    debug.warn("\n");
    for (roms_files) |file_name, i| {
        var fix_buf_alloc = heap.FixedBufferAllocator.init(buf[gen_alloc.end_index..]);
        const allocator = &fix_buf_alloc.allocator;

        debug.warn("Testing api ({}/{}): '{}':\n", i + 1, roms_files.len, file_name);
        defer debug.warn("Ok\n");

        var file = try os.File.openRead(file_name);
        defer file.close();

        timer.reset();
        var game = try libpoke.Game.load(&file, allocator);
        defer game.deinit();
        const time_to_load = timer.read();

        debug.warn("* Rom size: {B}\n", file.getEndPos());
        debug.warn("* Mem allocated: {B}\n", fix_buf_alloc.end_index);
        debug.warn("* Time taken: {}ms\n", time_to_load / 1000000);

        {
            const pokemons = game.pokemons();
            debug.assert(pokemons.len() > 0);

            var it = pokemons.iterator();
            while (try it.next()) |pair| {
                const pokemon = pair.value;

                debug.assert(pokemon.hp().* == fakes.hp);
                debug.assert(pokemon.attack().* == fakes.attack);
                debug.assert(pokemon.defense().* == fakes.defense);
                debug.assert(pokemon.speed().* == fakes.speed);
                debug.assert(pokemon.spAttack().* == fakes.sp_attack);
                debug.assert(pokemon.spDefense().* == fakes.sp_defense);
                debug.assert(pokemon.types()[0] == fakes.ptype);
                debug.assert(pokemon.types()[1] == fakes.ptype);

                const lvl_moves = pokemon.levelUpMoves();
                debug.assert(lvl_moves.len() == 1);

                const lvl_move = lvl_moves.at(0);
                debug.assert(lvl_move.moveId() == fakes.move);
                debug.assert(lvl_move.level() == fakes.level);

                const tms = pokemon.tmLearnset();
                const hms = pokemon.hmLearnset();
                debug.assert(tms.len() > 0);
                debug.assert(hms.len() > 0);

                var tm_it = tms.iterator();
                var hm_it = hms.iterator();
                while (tm_it.next()) |can_learn|
                    debug.assert(!can_learn.value);
                while (hm_it.next()) |can_learn|
                    debug.assert(!can_learn.value);
            }
        }

        {
            const trainers = game.trainers();
            debug.assert(trainers.len() > 0);

            var it = trainers.iterator();
            while (try it.next()) |pair| {
                const trainer = pair.value;
                const party = trainer.party();
                debug.assert(party.len() > 0);

                var party_it = party.iterator();
                while (party_it.next()) |party_pair| {
                    const party_member = party_pair.value;
                    debug.assert(party_member.level() == fakes.level);
                    debug.assert(party_member.species() == fakes.species);

                    if (party_member.moves()) |moves| {
                        debug.assert(moves.at(0) == fakes.move);
                        debug.assert(moves.at(1) == fakes.move);
                        debug.assert(moves.at(2) == fakes.move);
                        debug.assert(moves.at(3) == fakes.move);
                    }
                    if (party_member.item()) |item| {
                        debug.assert(fakes.item == item);
                    }
                }
            }
        }

        {
            const moves = game.moves();
            debug.assert(moves.len() > 0);

            var it = moves.iterator();
            while (try it.next()) |pair| {
                const move = pair.value;
                debug.assert(move.power().* == fakes.power);
                debug.assert(move.pp().* == fakes.pp);

                for (move.types().*) |t|
                    debug.assert(t == fakes.ptype);
            }
        }

        {
            const tms = game.tms();
            const hms = game.hms();
            debug.assert(tms.len() > 0);
            debug.assert(hms.len() > 0);

            var tm_it = tms.iterator();
            var hm_it = hms.iterator();
            while (tm_it.next()) |move_id|
                debug.assert(move_id.value == fakes.move);
            while (hm_it.next()) |move_id|
                debug.assert(move_id.value == fakes.move);
        }

        {
            const zones = game.zones();
            debug.assert(zones.len() > 0);

            var zone_it = zones.iterator();
            while (try zone_it.next()) |zone| {
                const wild_pokemons = zone.value.getWildPokemons();
                debug.assert(wild_pokemons.len() > 0);

                var wild_it = wild_pokemons.iterator();
                while (try wild_it.next()) |wild_mon| {
                    debug.assert(wild_mon.value.getSpecies() == fakes.species);
                    debug.assert(wild_mon.value.getMinLevel() == fakes.level);
                    debug.assert(wild_mon.value.getMaxLevel() == fakes.level);
                }
            }
        }
    }
}

fn randomEnum(random: *rand.Random, comptime Enum: type) Enum {
    const info = @typeInfo(Enum).Enum;
    const f = info.fields[random.range(usize, 0, info.fields.len)];
    return @intToEnum(Enum, @intCast(info.tag_type, f.value));
}

test "Fake rom: Randomizer" {
    var direct_alloc = heap.DirectAllocator.init();
    const buf = try direct_alloc.allocator.alloc(u8, max_alloc);
    defer direct_alloc.allocator.free(buf);

    var gen_alloc = heap.FixedBufferAllocator.init(buf);
    const roms_files = try fakes.generateFakeRoms(&gen_alloc.allocator);
    defer fakes.deleteFakeRoms(&gen_alloc.allocator);

    var timer = try time.Timer.start();

    debug.warn("\n");
    for (roms_files) |file_name, i| {
        debug.warn("Testing randomizer ({}/{}): '{}':\n", i + 1, roms_files.len, file_name);
        defer debug.warn("Ok\n");

        const game_buf = buf[gen_alloc.end_index..];
        var game_alloc = heap.FixedBufferAllocator.init(game_buf);
        var file = try os.File.openRead(file_name);
        defer file.close();

        var game = try libpoke.Game.load(&file, &game_alloc.allocator);
        defer game.deinit();

        var max_mem: usize = 0;
        var max_time: u64 = 0;
        var random = &rand.DefaultPrng.init(0).random;

        for (loop.to(20)) |_| {
            debug.warn(".");
            var options = Options{
                .trainer = Options.Trainer{
                    .pokemon = randomEnum(random, Options.Trainer.Pokemon),
                    .same_total_stats = random.scalar(bool),
                    .held_items = randomEnum(random, Options.Trainer.HeldItems),
                    .moves = randomEnum(random, Options.Trainer.Moves),
                    .level_modifier = random.float(f64) * 2,
                },
            };

            var rand_alloc = heap.FixedBufferAllocator.init(game_buf[game_alloc.end_index..]);
            var r = Randomizer.init(&game, random, &rand_alloc.allocator);

            timer.reset();
            try r.randomize(options);

            max_time = math.max(max_time, timer.read());
            max_mem = math.max(max_mem, rand_alloc.end_index);
        }

        debug.warn("\n");
        debug.warn("* Max mem allocated: {B}\n", max_mem);
        debug.warn("* Max time taken: {}ms\n", max_time / 1000000);
    }
}
