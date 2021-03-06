const std = @import("std");
const builtin = @import("builtin");
const gba = @import("gba.zig");
const nds = @import("nds/index.zig");
const utils = @import("utils.zig");
const randomizer = @import("randomizer.zig");
const clap = @import("clap.zig");
const pokemon = @import("pokemon/index.zig");
const gen3 = pokemon.gen3;
const gen4 = pokemon.gen4;
const gen5 = pokemon.gen5;

const os = std.os;
const debug = std.debug;
const mem = std.mem;
const io = std.io;
const rand = std.rand;
const fmt = std.fmt;
const path = os.path;

const Randomizer = randomizer.Randomizer;

// TODO: put into struct. There is no reason this should be global.
var help = false;
var input_file: []const u8 = "input";
var output_file: []const u8 = "randomized";

fn setHelp(op: *randomizer.Options, str: []const u8) anyerror!void {
    help = true;
}
fn setInFile(op: *randomizer.Options, str: []const u8) anyerror!void {
    input_file = str;
}
fn setOutFile(op: *randomizer.Options, str: []const u8) anyerror!void {
    output_file = str;
}
fn setTrainerPokemon(op: *randomizer.Options, str: []const u8) !void {
    if (mem.eql(u8, str, "same")) {
        op.trainer.pokemon = randomizer.Options.Trainer.Pokemon.Same;
    } else if (mem.eql(u8, str, "random")) {
        op.trainer.pokemon = randomizer.Options.Trainer.Pokemon.Random;
    } else if (mem.eql(u8, str, "same-type")) {
        op.trainer.pokemon = randomizer.Options.Trainer.Pokemon.SameType;
    } else if (mem.eql(u8, str, "type-themed")) {
        op.trainer.pokemon = randomizer.Options.Trainer.Pokemon.TypeThemed;
    } else if (mem.eql(u8, str, "legendaries")) {
        op.trainer.pokemon = randomizer.Options.Trainer.Pokemon.Legendaries;
    } else {
        return error.InvalidOptions;
    }
}

fn setTrainerSameStrength(op: *randomizer.Options, str: []const u8) anyerror!void {
    op.trainer.same_total_stats = true;
}
fn setTrainerHeldItems(op: *randomizer.Options, str: []const u8) !void {
    if (mem.eql(u8, str, "none")) {
        op.trainer.held_items = randomizer.Options.Trainer.HeldItems.None;
    } else if (mem.eql(u8, str, "same")) {
        op.trainer.held_items = randomizer.Options.Trainer.HeldItems.Same;
        //} else if (mem.eql(u8, str, "random")) {
        //    op.trainer.held_items = randomizer.Options.Trainer.HeldItems.Random;
        //} else if (mem.eql(u8, str, "random-useful")) {
        //    op.trainer.held_items = randomizer.Options.Trainer.HeldItems.RandomUseful;
        //} else if (mem.eql(u8, str, "random-best")) {
        //    op.trainer.held_items = randomizer.Options.Trainer.HeldItems.RandomBest;
    } else {
        return error.InvalidOptions;
    }
}

fn setTrainerMoves(op: *randomizer.Options, str: []const u8) !void {
    if (mem.eql(u8, str, "same")) {
        op.trainer.moves = randomizer.Options.Trainer.Moves.Same;
    } else if (mem.eql(u8, str, "random")) {
        op.trainer.moves = randomizer.Options.Trainer.Moves.Random;
    } else if (mem.eql(u8, str, "random-within-learnset")) {
        op.trainer.moves = randomizer.Options.Trainer.Moves.RandomWithinLearnset;
    } else if (mem.eql(u8, str, "best")) {
        op.trainer.moves = randomizer.Options.Trainer.Moves.Best;
    } else {
        return error.InvalidOptions;
    }
}

fn parseGenericOption(str: []const u8) !randomizer.GenericOption {
    if (mem.eql(u8, str, "same")) {
        return randomizer.GenericOption.Same;
    } else if (mem.eql(u8, str, "random")) {
        return randomizer.GenericOption.Random;
    } else if (mem.eql(u8, str, "best")) {
        return randomizer.GenericOption.Best;
    } else {
        return error.InvalidOptions;
    }
}

fn setLevelModifier(op: *randomizer.Options, str: []const u8) !void {
    const precent = try fmt.parseInt(i16, str, 10);
    op.trainer.level_modifier = (@intToFloat(f64, precent) / 100) + 1;
}

const Arg = clap.Arg(randomizer.Options);
// TODO: Format is horrible. Fix
const program_arguments = comptime [8]Arg{
    Arg.init(setHelp).help("Display this help and exit.").short('h').long("help").kind(Arg.Kind.IgnoresRequired),
    Arg.init(setInFile).help("The rom to randomize.").kind(Arg.Kind.Required),
    Arg.init(setOutFile).help("The place to output the randomized rom.").short('o').long("output").takesValue(true),
    Arg.init(setTrainerPokemon).help("How trainer Pokémons should be randomized. Options: [same, random, same-type, type-themed, legendaries].").long("trainer-pokemon").takesValue(true),
    Arg.init(setTrainerSameStrength).help("The randomizer will replace trainers Pokémon with Pokémon of similar total stats.").long("trainer-same-total-stats"),
    Arg.init(setTrainerHeldItems).help("How trainer Pokémon held items should be randomized. Options: [none, same].").long("trainer-held-items").takesValue(true),
    Arg.init(setTrainerMoves).help("How trainer Pokémon moves should be randomized. Options: [same, random, random-within-learnset, best].").long("trainer-moves").takesValue(true),
    Arg.init(setLevelModifier).help("A percent level modifier to trainers Pokémon.").long("trainer-level-modifier").takesValue(true),
};

pub fn main() !void {
    // TODO: Use Zig's own general purpose allocator... When it has one.
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();
    var arena = std.heap.ArenaAllocator.init(&direct_allocator.allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    var stdout_handle = try io.getStdOut();
    var stdout_file_stream = stdout_handle.outStream();
    var stdout = &stdout_file_stream.stream;

    const args = try os.argsAlloc(allocator);
    defer os.argsFree(allocator, args);

    const options = clap.parse(randomizer.Options, program_arguments, randomizer.Options.default(), args) catch |err| {
        // TODO: Write useful error message to user
        return err;
    };

    if (help) {
        try clap.help(randomizer.Options, program_arguments, stdout);
        return;
    }

    var rom_file = os.File.openRead(input_file) catch |err| {
        debug.warn("Couldn't open {}.\n", input_file);
        return err;
    };
    defer rom_file.close();

    var game = pokemon.Game.load(rom_file, allocator) catch |err| {
        debug.warn("Couldn't load game {}.\n", input_file);
        return err;
    };
    defer game.deinit();

    var random = rand.DefaultPrng.init(blk: {
        var buf: [8]u8 = undefined;
        try std.os.getRandomBytes(buf[0..]);
        break :blk mem.readInt(buf[0..8], u64, builtin.Endian.Little);
    });

    var r = Randomizer.init(game, &random.random, allocator);
    r.randomize(options) catch |err| {
        debug.warn("Randomizing error occured {}.\n", @errorName(err));
        return err;
    };

    var out_file = os.File.openWrite(output_file) catch |err| {
        debug.warn("Couldn't open {}.\n", output_file);
        return err;
    };
    defer out_file.close();

    game.save(out_file) catch |err| {
        debug.warn("Couldn't save game {}.\n", @errorName(err));
        return err;
    };
}
