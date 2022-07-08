use lazy_static::lazy_static;
use std::collections::HashMap;

lazy_static! {
    pub static ref WORD_TOKEN_MAP: HashMap<&'static str, TokenKind> = {
        let mut map = HashMap::new();

        // Built-in operations
        map.insert("+", TokenKind::Plus);
        map.insert("print", TokenKind::Print);

        map
    };
}

#[derive(Debug, Clone)]
pub enum TokenKind {
    // Built-in operations
    Plus,
    Print,

    // Literals
    Number(u64),
}

#[derive(Debug, Clone)]
pub struct Token {
    pub kind: TokenKind,
    // Line and column
    pub position: (usize, usize),
}
