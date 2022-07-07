use colored::*;
use std::fmt;

#[derive(Debug)]
pub enum ChaiError {
    StandardError(String),
}

impl fmt::Display for ChaiError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            ChaiError::StandardError(s) => {
                f.write_fmt(format_args!("{} {}", "Error:".red().bold(), s))
            }
        }
    }
}
