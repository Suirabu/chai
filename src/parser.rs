use crate::error::ChaiError;
use crate::expr::{Expr, ExprKind};
use crate::token::{Token, TokenKind};

#[derive(Debug)]
pub struct Parser {
    tokens: Vec<Token>,
    index: usize,
}

impl Parser {
    pub fn from_tokens(tokens: Vec<Token>) -> Self {
        Self { tokens, index: 0 }
    }

    fn reached_end(&self) -> bool {
        self.index >= self.tokens.len()
    }

    fn peek(&self) -> Token {
        self.tokens[self.index].clone()
    }

    fn advance(&mut self) -> Token {
        let t = self.peek();
        self.index += 1;
        t
    }

    fn collect_expr(&mut self) -> Result<Expr, ChaiError> {
        let token = self.advance();
        match token.kind {
            TokenKind::Number(v) => Ok(Expr {
                source: token.source,
                position: token.position,
                kind: ExprKind::Push(v),
            }),
            TokenKind::Plus => Ok(Expr {
                source: token.source,
                position: token.position,
                kind: ExprKind::Add,
            }),
            TokenKind::Print => Ok(Expr {
                source: token.source,
                position: token.position,
                kind: ExprKind::Print,
            }),
        }
    }

    pub fn collect_exprs(&mut self) -> Option<Vec<Expr>> {
        let mut exprs = Vec::new();
        let mut has_error = false;

        while !self.reached_end() {
            match self.collect_expr() {
                Ok(e) => exprs.push(e),
                Err(e) => {
                    eprintln!("{}", e);
                    has_error = true;
                }
            }
        }

        if has_error {
            None
        } else {
            Some(exprs)
        }
    }
}
