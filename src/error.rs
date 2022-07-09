use colored::*;
use std::fmt;

#[derive(Debug)]
pub enum ChaiError {
    StandardError(String),
    SourceError(String, (usize, usize), String),
}

impl fmt::Display for ChaiError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            ChaiError::StandardError(s) => {
                f.write_fmt(format_args!("{} {}", "Error:".red().bold(), s))
            },
            ChaiError::SourceError(source, position, s) => {
                f.write_fmt(format_args!(
                    "{} {} {}",
                    "Error:".red().bold(),
                    format!("{} ({},{}):", source, position.0 + 1, position.1 + 1).bold(),
                    s
                ))
            },
        }
    }
}
