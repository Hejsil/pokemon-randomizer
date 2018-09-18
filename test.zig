const F = packed struct {
    a: u8,
};


test "" {
    var b: [1]u8 = undefined;
    var f = @bytesToSlice(F, b);
}
