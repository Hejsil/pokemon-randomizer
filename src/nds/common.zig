pub fn alignAddr(comptime T: type, address: T, alignment: T) T {
    const rem = address % alignment;
    const result = address + (alignment - rem);

    return result;
}