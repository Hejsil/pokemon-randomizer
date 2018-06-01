const std = @import("std");
const bits = @import("bits.zig");

const mem = std.mem;
const fmt = std.fmt;
const debug = std.debug;
const io = std.io;

const assert = debug.assert;

// TODO: Missing a few convinient features
//     * Short arguments that doesn't take values should probably be able to be
//       chain like many linux programs: "rm -rf"
//     * Handle "--something=VALUE"

pub fn Arg(comptime T: type) type {
    return struct {
        const Self = this;

        pub const Kind = enum {
            Optional,
            Required,
            IgnoresRequired,
        };

        help_message: []const u8,
        handler: fn (*T, []const u8) error!void,
        arg_kind: Kind,
        takes_value: bool,
        short_arg: ?u8,
        long_arg: ?[]const u8,

        pub fn init(handler: fn (*T, []const u8) error!void) Self {
            return Self{
                .help_message = "",
                .handler = handler,
                .arg_kind = Kind.Optional,
                .takes_value = false,
                .short_arg = null,
                .long_arg = null,
            };
        }

        pub fn help(arg: *const Self, str: []const u8) Self {
            var res = arg.*;
            res.help_message = str;
            return res;
        }

        pub fn short(arg: *const Self, char: u8) Self {
            var res = arg.*;
            res.short_arg = char;
            return res;
        }

        pub fn long(arg: *const Self, str: []const u8) Self {
            var res = arg.*;
            res.long_arg = str;
            return res;
        }

        pub fn takesValue(arg: *const Self, b: bool) Self {
            var res = arg.*;
            res.takes_value = b;
            return res;
        }

        pub fn kind(arg: *const Self, k: Kind) Self {
            var res = arg.*;
            res.arg_kind = k;
            return res;
        }
    };
}

pub fn parse(comptime T: type, options: []const Arg(T), defaults: *const T, args: []const []const u8) !T {
    var result = defaults.*;

    const Kind = enum {
        Long,
        Short,
        None,
    };
    const ArgKind = struct {
        arg: []const u8,
        kind: Kind,
    };

    // NOTE: We avoid allocation here by using a bit field to store the required
    //       arguments that we need to handle. I'll only make this more flexible
    //       if someone finds a usecase for more than 128 required arguments.
    var required: u128 = 0;
    if (args.len >= 128) return error.ToManyOptions;

    {
        var required_index: usize = 0;
        for (options) |option, i| {
            if (option.arg_kind == Arg(T).Kind.Required) {
                required = bits.set(u128, required, u7(required_index), true);
                required_index += 1;
            }
        }
    }

    // We assume that the first arg is always the exe path
    var arg_i = usize(1);
    while (arg_i < args.len) : (arg_i += 1) {
        const pair = blk: {
            const tmp = args[arg_i];
            if (mem.startsWith(u8, tmp, "--"))
                break :blk ArgKind{ .arg = tmp[2..], .kind = Kind.Long };
            if (mem.startsWith(u8, tmp, "-"))
                break :blk ArgKind{ .arg = tmp[1..], .kind = Kind.Short };

            break :blk ArgKind{ .arg = tmp, .kind = Kind.None };
        };
        const arg = pair.arg;
        const kind = pair.kind;

        var required_index: usize = 0;
        loop: for (options) |option, op_i| {
            switch (kind) {
                Kind.None => {
                    if (option.short_arg != null) continue :loop;
                    if (option.long_arg != null) continue :loop;

                    try option.handler(&result, arg);

                    switch (option.arg_kind) {
                        Arg(T).Kind.Required => {
                            required = bits.set(u128, required, u7(required_index), false);
                            required_index += 1;
                        },
                        Arg(T).Kind.IgnoresRequired => {
                            required = 0;
                            required_index += 1;
                        },
                        else => {},
                    }

                    break :loop;
                },
                Kind.Short => {
                    const short = option.short_arg ?? continue :loop;
                    if (arg.len != 1 or arg[0] != short) continue :loop;
                },
                Kind.Long => {
                    const long = option.long_arg ?? continue :loop;
                    if (!mem.eql(u8, long, arg)) continue :loop;
                },
            }

            if (option.takes_value) arg_i += 1;
            if (args.len <= arg_i) return error.MissingValueToArgument;
            const value = args[arg_i];
            try option.handler(&result, value);

            switch (option.arg_kind) {
                Arg(T).Kind.Required => {
                    required = bits.set(u128, required, u7(required_index), false);
                    required_index += 1;
                },
                Arg(T).Kind.IgnoresRequired => {
                    required = 0;
                    required_index += 1;
                },
                else => {},
            }

            break :loop;
        } else {
            return error.InvalidArgument;
        }
    }

    if (required != 0) {
        return error.RequiredArgumentWasntHandled;
    }

    return result;
}

// TODO:
//    * Usage
//    * Description

pub fn help(comptime T: type, options: []const Arg(T), out_stream: var) !void {
    const equal_value: []const u8 = "=OPTION";
    var longest_long: usize = 0;
    for (options) |option| {
        const long = option.long_arg ?? continue;
        var len = long.len;

        if (option.takes_value)
            len += equal_value.len;

        if (longest_long < len)
            longest_long = len;
    }

    for (options) |option| {
        if (option.short_arg == null and option.long_arg == null) continue;

        try out_stream.print("    ");
        if (option.short_arg) |short| {
            try out_stream.print("-{c}", short);
        } else {
            try out_stream.print("  ");
        }

        if (option.short_arg != null and option.long_arg != null) {
            try out_stream.print(", ");
        } else {
            try out_stream.print("  ");
        }

        // We need to ident by:
        // "--<longest_long> ".len
        var missing_spaces = longest_long + 3;
        if (option.long_arg) |long| {
            try out_stream.print("--{}", long);
            missing_spaces -= 2 + long.len;

            if (option.takes_value) {
                try out_stream.print("{}", equal_value);
                missing_spaces -= equal_value.len;
            }
        }

        var i: usize = 0;
        while (i < (missing_spaces + 1)) : (i += 1) {
            try out_stream.print(" ");
        }

        try out_stream.print("{}\n", option.help_message);
    }
}

test "clap.parse.Example" {
    const Color = struct {
        const Self = this;

        r: u8,
        g: u8,
        b: u8,

        fn rFromStr(color: *Self, str: []const u8) !void {
            color.r = try fmt.parseInt(u8, str, 10);
        }

        fn gFromStr(color: *Self, str: []const u8) !void {
            color.g = try fmt.parseInt(u8, str, 10);
        }

        fn bFromStr(color: *Self, str: []const u8) !void {
            color.b = try fmt.parseInt(u8, str, 10);
        }
    };

    const CArg = Arg(Color);
    // TODO: Format is horrible. Fix
    const options = []CArg{
        CArg.init(Color.rFromStr).help("The amount of red in our color").short('r').long("red").takesValue(true).kind(CArg.Kind.Required),
        CArg.init(Color.gFromStr).help("The amount of green in our color").short('g').long("green").takesValue(true),
        CArg.init(Color.bFromStr).help("The amount of blue in our color").short('b').long("blue").takesValue(true),
    };

    const Case = struct {
        args: []const []const u8,
        res: Color,
        err: ?error,
    };
    const cases = []Case{
        Case{
            .args = [][]const u8{
                "color.exe",
                "-r",
                "100",
                "-g",
                "100",
                "-b",
                "100",
            },
            .res = Color{ .r = 100, .g = 100, .b = 100 },
            .err = null,
        },
        Case{
            .args = [][]const u8{
                "color.exe",
                "--red",
                "100",
                "-g",
                "100",
                "--blue",
                "50",
            },
            .res = Color{ .r = 100, .g = 100, .b = 50 },
            .err = null,
        },
        Case{
            .args = [][]const u8{
                "color.exe",
                "-g",
                "200",
                "--blue",
                "100",
                "--red",
                "100",
            },
            .res = Color{ .r = 100, .g = 200, .b = 100 },
            .err = null,
        },
        Case{
            .args = [][]const u8{ "color.exe", "-r", "200", "-r", "255" },
            .res = Color{ .r = 255, .g = 0, .b = 0 },
            .err = null,
        },
        Case{
            .args = [][]const u8{ "color.exe", "-g", "200", "-b", "255" },
            .res = Color{ .r = 0, .g = 0, .b = 0 },
            .err = error.RequiredArgumentWasntHandled,
        },
        Case{
            .args = [][]const u8{ "color.exe", "-p" },
            .res = Color{ .r = 0, .g = 0, .b = 0 },
            .err = error.InvalidArgument,
        },
        Case{
            .args = [][]const u8{ "color.exe", "-g" },
            .res = Color{ .r = 0, .g = 0, .b = 0 },
            .err = error.MissingValueToArgument,
        },
    };

    for (cases) |case| {
        const default = Color{ .r = 0, .g = 0, .b = 0 };
        if (parse(Color, options, default, case.args)) |res| {
            assert(res.r == case.res.r);
            assert(res.g == case.res.g);
            assert(res.b == case.res.b);
        } else |err| {
            assert(err == (case.err ?? unreachable));
        }
    }
}
