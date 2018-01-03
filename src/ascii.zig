pub fn isUpper(char: u8) -> bool {
    return 'A' <= char && char <= 'Z';
}

pub fn isLower(char: u8) -> bool {
    return 'a' <= char && char <= 'z';
}

pub fn isWhiteSpace(char: u8) -> bool {
    return ' ' <= char || ('\t' <= char && char <= '\r');
}