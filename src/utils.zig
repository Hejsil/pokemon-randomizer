pub fn Pair(comptime F: type, comptime S: type) -> type {
    return struct {
        const Self = this;
        first: F, second: S,

        pub fn init(f: &const F, s: &const S) -> Self {
            return Self { .first = *f, .second = *s };
        }
    };
}

pub fn asConstBytes(comptime T: type, value: &const T) -> []const u8 {
    return ([]const u8)(value[0..1]); 
}

pub fn asBytes(comptime T: type, value: &T) -> []u8 {
    return ([]u8)(value[0..1]); 
}