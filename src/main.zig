const std        = @import("std");
const gba        = @import("gba.zig");
const nds        = @import("nds/index.zig");
const utils      = @import("utils.zig");
const randomizer = @import("randomizer.zig");
const clap       = @import("clap.zig");
const gen3       = @import("pokemon/gen3.zig");
const gen5       = @import("pokemon/gen5.zig");

const os    = std.os;
const debug = std.debug;
const mem   = std.mem;
const io    = std.io;
const rand  = std.rand;
const fmt   = std.fmt;
const path  = os.path;

var help = false;
var input_file  : []const u8 = "input";
var output_file : []const u8 = "randomized";

fn setHelp(op: &randomizer.Options, str: []const u8) error!void { help = true; }
fn setInFile(op: &randomizer.Options, str: []const u8) error!void { input_file = str; }
fn setOutFile(op: &randomizer.Options, str: []const u8) error!void { output_file = str; }
fn setTrainerPokemon(op: &randomizer.Options, str: []const u8) !void {
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
    }  else {
        return error.InvalidOptions;
    }
}

fn setTrainerSameStrength(op: &randomizer.Options, str: []const u8) error!void { op.trainer.same_total_stats = true; }
fn setTrainerHeldItems(op: &randomizer.Options, str: []const u8) !void {
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

fn setTrainerMoves(op: &randomizer.Options, str: []const u8) !void {
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

fn setTrainerIv(op: &randomizer.Options, str: []const u8) !void { op.trainer.iv = try parseGenericOption(str); }

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

fn setLevelModifier(op: &randomizer.Options, str: []const u8) !void {
    const precent = try fmt.parseInt(i16, str, 10);
    op.trainer.level_modifier = (f64(precent) / 100) + 1;
}

const Arg = clap.Arg(randomizer.Options);
const program_arguments = comptime []Arg {
    Arg.init(setHelp)
        .help("Display this help and exit.")
        .short('h')
        .long("help")
        .kind(Arg.Kind.IgnoresRequired),
    Arg.init(setInFile)
        .help("The rom to randomize.")
        .kind(Arg.Kind.Required),
    Arg.init(setOutFile)
        .help("The place to output the randomized rom.")
        .short('o')
        .long("output")
        .takesValue(true),
    Arg.init(setTrainerPokemon)
        .help("How trainer Pokémons should be randomized. Options: [same, random, same-type, type-themed, legendaries].")
        .long("trainer-pokemon")
        .takesValue(true),
    Arg.init(setTrainerSameStrength)
        .help("The randomizer will replace trainers Pokémon with Pokémon of similar total stats.")
        .long("trainer-same-total-stats"),
    Arg.init(setTrainerHeldItems)
        .help("How trainer Pokémon held items should be randomized. Options: [none, same].")
        .long("trainer-held-items")
        .takesValue(true),
    Arg.init(setTrainerMoves)
        .help("How trainer Pokémon moves should be randomized. Options: [same, random, random-within-learnset, best].")
        .long("trainer-moves")
        .takesValue(true),
    Arg.init(setTrainerIv)
        .help("How trainer Pokémon ivs should be randomized. Options: [same, random, best].")
        .long("trainer-iv")
        .takesValue(true),
    Arg.init(setLevelModifier)
        .help("A percent level modifier to trainers Pokémon.")
        .long("trainer-level-modifier")
        .takesValue(true),
};

pub fn main() !void {
    // TODO: Use Zig's own general purpose allocator... When it has one.
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();
    var arena = std.heap.ArenaAllocator.init(&direct_allocator.allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    var stdout = try io.getStdOut();
    var stdout_file_stream = io.FileOutStream.init(&stdout);
    var stdout_stream = &stdout_file_stream.stream;

    const args = try os.argsAlloc(allocator);
    defer os.argsFree(allocator, args);

    const options = clap.parse(randomizer.Options, program_arguments, randomizer.Options.default(), args) catch |err| {
        // TODO: Write useful error message to user
        return err;
    };

    if (help) {
        try clap.help(randomizer.Options, program_arguments, stdout_stream);
        return;
    }

    var out_file = os.File.openWrite(allocator, output_file) catch |err| {
        try stdout_stream.print("Couldn't open {}.\n", output_file);
        return err;
    };
    defer out_file.close();


    gba_blk: {
        var rom_file = try os.File.openRead(allocator, input_file);
        //defer rom_file.close(); error: unreachable code
        var game = gen3.Game.fromFile(&rom_file, allocator) catch break :gba_blk;

        game.validateData() catch |err| {
            try stdout_stream.print("Warning: Invalid Pokemon game data. The rom will still be randomized, but there is no garenties that the rom will work as indented.\n");

            switch (err) {
                error.NoBulbasaurFound => {
                    try stdout_stream.print("Note: Pokemon 001 (Bulbasaur) did not have expected stats.\n");
                    try stdout_stream.print("Note: If you are randomizing a hacked version, then .\n");
                },
                else => {}
            }
        };

        var random = rand.Rand.init(0);
        try randomizer.randomize(game, options, &random, allocator);

        var file_stream = io.FileOutStream.init(&out_file);
        game.writeToStream(&file_stream.stream) catch |err| {
            try stdout_stream.print("Unable to write gba to {}.\n", output_file);
            return err;
        };

        return;
    }

    nds_blk: {
        var rom_file = try os.File.openRead(allocator, input_file);
        //defer rom_file.close(); error: unreachable code
        var nds_rom = nds.Rom.fromFile(&rom_file, allocator) catch break :nds_blk;

        var game = try gen5.Game.fromRom(&nds_rom);

        nds_rom.writeToFile(&out_file) catch |err| {
            try stdout_stream.print("Unable to write nds to {}\n", output_file);
            return err;
        };

        return;
    }

    try stdout_stream.print("Rom type not supported (yet)\n");
    return error.NotARom;
}
