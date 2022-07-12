use std::fmt;

#[derive(Debug)]
pub enum ExprKind {
    Push(Value),
    Add,
    Print,
}

pub struct Expr {
    pub kind: ExprKind,
    pub source: String,
    pub position: (usize, usize),
}

#[derive(Debug)]
pub enum Value {
    Number(u64),
    String(String),
}

impl fmt::Display for Value {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Value::Number(n) => f.write_str(n.to_string().as_str()),
            Value::String(s) => f.write_str(s.as_str()),
        }
    }
}
