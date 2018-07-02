const libpoke = @import("../src/pokemon/index.zig");
const fakes = @import("fake_roms.zig");
const std = @import("std");
const heap = std.heap;
const os = std.os;
const debug = std.debug;

test "Fake rom: Api" {
    var direct_alloc = heap.DirectAllocator.init();
    const buf = try direct_alloc.allocator.alloc(u8, 1024 * 1024 * 1024);
    defer direct_alloc.allocator.free(buf);

    debug.warn("\n");

    var generate_buf: [100 * 1024]u8 = undefined;
    var generate_fix_buf_alloc = heap.FixedBufferAllocator.init(generate_buf[0..]);
    const generate_allocator = &generate_fix_buf_alloc.allocator;

    const roms_files = try fakes.generateFakeRoms(generate_allocator);
    defer fakes.deleteFakeRoms(generate_allocator);

    for (roms_files) |file_name, i| {
        var fix_buf_alloc = heap.FixedBufferAllocator.init(buf);
        const allocator = &fix_buf_alloc.allocator;

        debug.warn("Testing api ({}/{}): '{}'...", i + 1, roms_files.len, file_name);
        defer debug.warn("Ok\n");

        var file = try os.File.openRead(allocator, file_name);
        defer file.close();

        var game = try libpoke.Game.load(&file, allocator);
        defer game.deinit();

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
    }
}

test "Fake rom: Randomizer" {}
