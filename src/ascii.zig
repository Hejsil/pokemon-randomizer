pub fn isUpper(char: &const u8) bool {
    return 'A' <= char and char <= 'Z';
}

pub fn isLower(char: &const u8) bool {
    return 'a' <= char.* and char.* <= 'z';
}

pub fn isSpace(char: &const u8) bool {
    return ' ' == char.* or ('\t' <= char.* and char.* <= '\r');
}

pub fn isUpperAscii(char: &const u8) bool {
    return !isLower(char) and !isZero(char);
}

pub fn isZero(char: &const u8) bool { return char.* == 0; }
