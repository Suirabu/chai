use crate::error::ChaiError;
use crate::token::{Token, TokenKind, WORD_TOKEN_MAP};
use std::fs;

#[derive(Debug)]
pub struct Lexer {
    source: String,
    source_path: String,
    index: usize,

    // Line and column
    position: (usize, usize),
}

impl Lexer {
    pub fn from_source_path(source_path: &String) -> Result<Self, ChaiError> {
        let source = match fs::read_to_string(source_path) {
            Err(_) => {
                return Err(ChaiError::StandardError(format!(
                    "Failed to open file '{}' for reading",
                    source_path
                )));
            }
            Ok(s) => s,
        };

        Ok(Self {
            source,
            source_path: source_path.clone(),
            index: 0,
            position: (0, 0),
        })
    }

    fn reached_end(&self) -> bool {
        self.index >= self.source.len()
    }

    fn peek(&self) -> char {
        self.source.chars().nth(self.index).unwrap()
    }

    fn advance(&mut self) -> char {
        let c = self.peek();
        match c {
            '\n' => {
                self.position.0 += 1;
                self.position.1 = 0;
            }
            _ => {
                self.position.1 += 1;
            }
        }
        self.index += 1;
        c
    }

    fn skip_whitespace(&mut self) {
        while !self.reached_end() && self.peek().is_whitespace() {
            self.advance();
        }
    }

    fn collect_number(&mut self) -> Result<Token, ChaiError> {
        let start = self.index;
        let position = self.position;

        while !self.reached_end() && !self.peek().is_whitespace() {
            self.advance();
        }

        let end = self.index;
        let lexemme = self.source.get(start..end).unwrap();
        match lexemme.parse::<u64>() {
            Err(_) => Err(ChaiError::SourceError(
                self.source_path.clone(),
                position,
                format!(
                "Failed to convert '{}' to number literal.",
                lexemme
            ))),
            Ok(v) => Ok(Token {
                kind: TokenKind::Number(v),
                source: self.source_path.clone(),
                position,
            }),
        }
    }

    fn collect_word(&mut self) -> Result<Token, ChaiError> {
        let start = self.index;
        let position = self.position;

        while !self.reached_end() && !self.peek().is_whitespace() {
            self.advance();
        }

        let end = self.index;
        let lexemme = self.source.get(start..end).unwrap();
        match WORD_TOKEN_MAP.get(lexemme) {
            None => Err(ChaiError::SourceError(
                self.source_path.clone(),
                position,
                format!(
                "Unknown word '{}' found.",
                lexemme
            ))),
            Some(k) => Ok(Token {
                kind: k.clone(),
                source: self.source_path.clone(),
                position,
            }),
        }
    }

    fn collect_token(&mut self) -> Result<Token, ChaiError> {
        let c = self.peek();

        if c.is_ascii_digit() {
            self.collect_number()
        } else {
            self.collect_word()
        }
    }

    pub fn collect_tokens(&mut self) -> Option<Vec<Token>> {
        let mut tokens = Vec::new();
        let mut has_error = false;

        loop {
            // Jump to next word boundary
            self.skip_whitespace();
            if self.reached_end() {
                break;
            }

            match self.collect_token() {
                Ok(t) => tokens.push(t),
                Err(e) => {
                    eprintln!("{}", e);
                    has_error = true;
                }
            }
        }

        if has_error {
            None
        } else {
            Some(tokens)
        }
    }
}
