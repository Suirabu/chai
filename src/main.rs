pub mod error;
pub mod expr;
pub mod interpreter;
pub mod lexer;
pub mod parser;
pub mod token;

use crate::error::ChaiError;
use crate::interpreter::interpret_program;
use crate::lexer::Lexer;
use crate::parser::Parser;
use std::{env, process::ExitCode};

fn main() -> ExitCode {
    let args: Vec<String> = env::args().collect();

    // Get source path
    if args.len() < 2 {
        eprintln!(
            "{}",
            ChaiError::StandardError("No input file provided.".to_owned())
        );
        return ExitCode::FAILURE;
    }
    let source_path = args.get(1).unwrap();

    let mut lexer = match Lexer::from_source_path(source_path) {
        Err(e) => {
            eprintln!("{}", e);
            return ExitCode::FAILURE;
        }
        Ok(l) => l,
    };
    let tokens = match lexer.collect_tokens() {
        None => return ExitCode::FAILURE,
        Some(t) => t,
    };

    let mut parser = Parser::from_tokens(tokens);
    let exprs = match parser.collect_exprs() {
        None => return ExitCode::FAILURE,
        Some(e) => e,
    };

    match interpret_program(exprs) {
        Err(e) => {
            eprintln!("{}", e);
            return ExitCode::FAILURE;
        }
        Ok(_) => {}
    };

    ExitCode::SUCCESS
}
