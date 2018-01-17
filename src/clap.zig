const std  = @import("std");
const bits = @import("bits.zig");

const mem   = std.mem;
const fmt   = std.fmt;
const debug = std.debug;

const assert = debug.assert;


// TODO: Missing a few convinient features
//     * Short arguments that doesn't take values should probably be able to be
//       chain like many linux programs: "rm -rf"
//       We will probably change the api, to only allow single ascii chars for
//       short args by then.
//     * Have a function that can output a help message from an array of Args

pub fn Arg(comptime T: type) -> type { return struct {
    const Self = this;

    help_message: []const u8,
    handler: fn(&T, []const u8) -> %void,
    is_required: bool,
    takes_value: bool,
    short_arg: ?[]const u8,
    long_arg:  ?[]const u8,

    pub fn init(handler: fn(&T, []const u8) -> %void) -> Self {
        return Self {
            .help_message = "",
            .handler = handler,
            .is_required = false,
            .takes_value = false,
            .short_arg = null,
            .long_arg = null,
        };
    }

    pub fn help(self: &const Self, str: []const u8) -> Self {
        var res = *self; res.help_message = str;
        return res;
    }

    pub fn short(self: &const Self, str: []const u8) -> Self {
        var res = *self; res.short_arg = str;
        return res;
    }

    pub fn long(self: &const Self, str: []const u8) -> Self {
        var res = *self; res.long_arg = str;
        return res;
    }

    pub fn takesValue(self: &const Self, b: bool) -> Self {
        var res = *self; res.takes_value = b;
        return res;
    }

    pub fn required(self: &const Self, b: bool) -> Self {
        var res = *self; res.is_required = b;
        return res;
    }
};}

error MissingValueToArgument;
error InvalidArgument;
error ToManyOptions;
error RequiredArgumentWasntHandled;

pub fn parse(comptime T: type, args: []const []const u8, defaults: &const T, options: []const Arg(T)) -> %T {
    var result = *defaults;

    const Kind    = enum { Long, Short, None };
    const ArgKind = struct { arg: []const u8, kind: Kind };

    // TODO: We avoid allocation here by using a bit field to store the required
    //       arguments that we need to handle. This does however mean, that we
    //       can only parse 128 options.
    var required : u128 = 0;
    if (args.len >= 128) return error.ToManyOptions;

    for (options) |option, i| {
        if (option.is_required)
            required = bits.set(u128, required, u7(i), 1);
    }

    // We assume that the first arg is always the exe path
    var arg_i = usize(1);
    while (arg_i < args.len) : (arg_i += 1) {
        const pair = blk: {
            const tmp = args[arg_i];
            if (mem.startsWith(u8, tmp, "--"))
                break :blk ArgKind { .arg = tmp[2..], .kind = Kind.Long };
            if (mem.startsWith(u8, tmp, "-"))
                break :blk ArgKind { .arg = tmp[1..], .kind = Kind.Short };

            break :blk ArgKind { .arg = tmp, .kind = Kind.None };
        };
        const arg = pair.arg;
        const kind = pair.kind;

        loop: for (options) |option, op_i| {
            switch (kind) {
                Kind.None => {
                    if (option.short_arg != null) continue :loop;
                    if (option.long_arg != null)  continue :loop;

                    try option.handler(&result, arg);
                    required = bits.set(u128, required, u7(op_i), 0);
                    break :loop;
                },
                Kind.Short => {
                    const short = option.short_arg ?? continue :loop;
                    if (!mem.eql(u8, short, arg))     continue :loop;
                },
                Kind.Long => {
                    const long = option.long_arg ?? continue :loop;
                    if (!mem.eql(u8, long, arg))    continue :loop;
                }
            }

            if (option.takes_value) arg_i += 1;
            if (args.len <= arg_i) return error.MissingValueToArgument;
            const value = args[arg_i];
            try option.handler(&result, value);
            required = bits.set(u128, required, u7(op_i), 0);

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


test "args.parse.Example" {
    const Color = struct {
        const Self = this;

        r: u8, g: u8, b: u8,

        fn rFromStr(self: &Self, str: []const u8) -> %void {
            self.r = try fmt.parseInt(u8, str, 10);
        }

        fn gFromStr(self: &Self, str: []const u8) -> %void {
            self.g = try fmt.parseInt(u8, str, 10);
        }

        fn bFromStr(self: &Self, str: []const u8) -> %void {
            self.b = try fmt.parseInt(u8, str, 10);
        }
    };

    const CArg = Arg(Color);
    const options = []CArg {
        CArg.init(Color.rFromStr)
            .help("The amount of red in our color")
            .short("r")
            .long("red")
            .takesValue(true)
            .required(true),
        CArg.init(Color.gFromStr)
            .help("The amount of green in our color")
            .short("g")
            .long("green")
            .takesValue(true),
        CArg.init(Color.bFromStr)
            .help("The amount of blue in our color")
            .short("b")
            .long("blue")
            .takesValue(true),
    };

    const Case = struct { args: []const []const u8, res: Color, err: ?error };
    const cases = []Case {
        Case {
            .args = [][]const u8 { "color.exe", "-r", "100", "-g", "100", "-b", "100", },
            .res = Color { .r = 100, .g = 100, .b = 100 },
            .err = null,
        },
        Case {
            .args = [][]const u8 { "color.exe", "--red", "100", "-g", "100", "--blue", "50", },
            .res = Color { .r = 100, .g = 100, .b = 50 },
            .err = null,
        },
        Case {
            .args = [][]const u8 { "color.exe", "-g", "200", "--blue", "100", "--red", "100", },
            .res = Color { .r = 100, .g = 200, .b = 100 },
            .err = null,
        },
        Case {
            .args = [][]const u8 { "color.exe", "-r", "200", "-r", "255" },
            .res = Color { .r = 255, .g = 0, .b = 0 },
            .err = null,
        },
        Case {
            .args = [][]const u8 { "color.exe", "-g", "200", "-b", "255" },
            .res = Color { .r = 0, .g = 0, .b = 0 },
            .err = error.RequiredArgumentWasntHandled,
        },
        Case {
            .args = [][]const u8 { "color.exe", "-p" },
            .res = Color { .r = 0, .g = 0, .b = 0 },
            .err = error.InvalidArgument,
        },
        Case {
            .args = [][]const u8 { "color.exe", "-g" },
            .res = Color { .r = 0, .g = 0, .b = 0 },
            .err = error.MissingValueToArgument,
        },
    };

    for (cases) |case| {
        const default = Color { .r = 0, .g = 0, .b = 0 };
        if (parse(Color, case.args, default, options)) |res| {
            assert(res.r == case.res.r);
            assert(res.g == case.res.g);
            assert(res.b == case.res.b);
        } else |err| {
            assert(err == (case.err ?? unreachable));
        }
    }
}