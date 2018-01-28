pub fn isUpper(char: u8) bool {
    return 'A' <= char and char <= 'Z';
}

pub fn isLower(char: u8) bool {
    return 'a' <= char and char <= 'z';
}

pub fn isSpace(char: u8) bool {
    return ' ' == char or ('\t' <= char and char <= '\r');
}

pub fn isUpperAscii(char: u8) bool {
    return !isLower(char) and !isZero(char);
}

pub fn isZero(char: u8) bool { return char == 0; }