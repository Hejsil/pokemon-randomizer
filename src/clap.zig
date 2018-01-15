const std = @import("std");

const mem   = std.mem;
const fmt   = std.fmt;
const debug = std.debug;

const assert = debug.assert;


// TODO: Missing a few convinient features
//     * Required arguments. How should these be handled?
//     * Short arguments that doesn't take values should probably be able to be
//       chain like many linux programs: "rm -rf"
//       We will probably change the api, to only allow single ascii chars for
//       short args by then.
//     * Have a function that can output a help message from an array of Args

pub fn Arg(comptime T: type) -> type { return struct {
    const Self = this;

    pub const Short = struct { name: []const u8, takes_value: bool };
    pub const Long  = struct { name: []const u8, takes_value: bool };
    pub const Both  = struct { short: []const u8, long: []const u8, takes_value: bool };
    pub const FlagKind = enum(u8) { Short, Long, Both, None };
    pub const Flag = union(FlagKind) {
        Short: Short,
        Long:  Long,
        Both:  Both,
        None:  void
    };

    help_message: []const u8,
    handler: fn(&T, []const u8) -> %void,
    flag: Flag,

    pub fn init(handler: fn(&T, []const u8) -> %void) -> Self {
        return Self {
            .help_message = "",
            .handler = handler,
            .flag = Flag {
                .None = void{}
            }
        };
    }

    pub fn help(self: &const Self, str: []const u8) -> Self {
        var res = *self; res.help_message = str;
        return res;
    }

    pub fn short(self: &const Self, str: []const u8) -> Self {
        var res = *self;
        switch (res.flag) {
            Flag.Short => |*shrt| shrt.name  = str,
            Flag.Both  => |*both| both.short = str,
            Flag.Long => |lng| {
                res.flag = Flag {
                    .Both = Both {
                        .short = str,
                        .long  = lng.name,
                        .takes_value = lng.takes_value,
                    }
                };
            },
            Flag.None => {
                res.flag = Flag {
                    .Short = Short {
                        .name = str,
                        .takes_value = false,
                    }
                };
            }
        }

        return res;
    }

    pub fn long(self: &const Self, str: []const u8) -> Self {
        var res = *self;
        switch (res.flag) {
            Flag.Long => |*lng|  lng.name   = str,
            Flag.Both => |*both| both.short = str,
            Flag.Short => |shrt| {
                res.flag = Flag {
                    .Both = Both {
                        .short = shrt.name,
                        .long  = str,
                        .takes_value = shrt.takes_value,
                    }
                };
            },
            Flag.None => {
                res.flag = Flag {
                    .Long = Long {
                        .name = str,
                        .takes_value = false,
                    }
                };
            }
        }

        return res;
    }

    pub fn takesValue(self: &const Self, b: bool) -> Self {
        var res = *self;
        switch (res.flag) {
            Flag.Long  => |*lng|  lng.takes_value  = b,
            Flag.Both  => |*both| both.takes_value  = b,
            Flag.Short => |*shrt| shrt.takes_value = b,
            Flag.None  => {},
        }

        return res;
    }
};}

error MissingValueToArgument;
error InvalidArgument;

pub fn parse(comptime T: type, args: []const []const u8, defaults: &const T, options: []const Arg(T)) -> %T {
    var result = *defaults;

    const Kind    = enum { Long, Short, None };
    const ArgKind = struct { arg: []const u8, kind: Kind };

    // We assume that the first arg is always the exe path
    var i = usize(1);
    while (i < args.len) : (i += 1) {
        const pair = blk: {
            const tmp = args[i];
            if (mem.startsWith(u8, tmp, "--"))
                break :blk ArgKind { .arg = tmp[2..], .kind = Kind.Long };
            if (mem.startsWith(u8, tmp, "-"))
                break :blk ArgKind { .arg = tmp[1..], .kind = Kind.Short };

            break :blk ArgKind { .arg = tmp, .kind = Kind.None };
        };
        const arg = pair.arg;
        const kind = pair.kind;

        loop: for (options) |option| {
            const Flag = Arg(T).Flag;
            switch (option.flag) {
                Flag.Both => |both| blk: {
                    switch (kind) {
                        Kind.None  => continue :loop,
                        Kind.Short => if (!mem.eql(u8, both.short, arg)) continue :loop,
                        Kind.Long  => if (!mem.eql(u8, both.long, arg))  continue :loop,
                    }

                    if (both.takes_value) i += 1;
                    if (args.len <= i) return error.MissingValueToArgument;
                    const value = args[i];
                    try option.handler(&result, value);

                    break :loop;
                },
                Flag.Short => |short| blk: {
                    if (kind != Kind.Short)            continue :loop;
                    if (!mem.eql(u8, short.name, arg)) continue :loop;

                    if (short.takes_value) i += 1;
                    if (args.len <= i) return error.MissingValueToArgument;
                    const value = args[i];
                    try option.handler(&result, value);

                    break :loop;
                },
                Flag.Long => |long| blk: {
                    if (kind != Kind.Long)            continue :loop;
                    if (!mem.eql(u8, long.name, arg)) continue :loop;

                    if (long.takes_value) i += 1;
                    if (args.len <= i) return error.MissingValueToArgument;
                    const value = args[i];
                    try option.handler(&result, value);

                    break :loop;
                },
                Flag.None => blk: {
                    if (kind != Kind.None) continue :loop;
                    try option.handler(&result, arg);
                    break :loop;
                }
            }

            break :loop;
        } else {
            return error.InvalidArgument;
        }
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
            .takesValue(true),
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

    const Case = struct { args: []const []const u8, res: Color };
    const cases = []Case {
        Case {
            .args = [][]const u8 { "color.exe", "-r", "100", "-g", "100", "-b", "100", },
            .res = Color { .r = 100, .g = 100, .b = 100 },
        },
        Case {
            .args = [][]const u8 { "color.exe", "--red", "100", "-g", "100", "--blue", "50", },
            .res = Color { .r = 100, .g = 100, .b = 50 },
        },
        Case {
            .args = [][]const u8 { "color.exe", "-g", "200", "--blue", "100", "--red", "100", },
            .res = Color { .r = 100, .g = 200, .b = 100 },
        },
        Case {
            .args = [][]const u8 { "color.exe", "-r", "200", "-r", "255" },
            .res = Color { .r = 255, .g = 0, .b = 0 },
        },
    };

    for (cases) |case| {
        const default = Color { .r = 0, .g = 0, .b = 0 };
        const res = try parse(Color, case.args, default, options);
        assert(res.r == case.res.r);
        assert(res.g == case.res.g);
        assert(res.b == case.res.b);
    }
}