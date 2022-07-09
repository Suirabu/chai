#[derive(Debug)]
pub enum ExprKind {
    Push(u64),
    Add,
    Print,
}

pub struct Expr {
    pub kind: ExprKind,
    pub source: String,
    pub position: (usize, usize),
}
