use crate::error::ChaiError;
use crate::expr::{Expr, ExprKind};

pub fn interpret_program(exprs: Vec<Expr>) -> Result<(), ChaiError> {
    let mut stack = Vec::new();

    for expr in exprs {
        match expr.kind {
            ExprKind::Push(v) => stack.push(v),

            ExprKind::Add => {
                if stack.len() < 2 {
                    return Err(ChaiError::SourceError(
                        expr.source,
                        expr.position,
                        "Expected 2 or more elements on stack.".to_owned(),
                    ));
                }

                let a = stack.pop().unwrap();
                let b = stack.pop().unwrap();
                stack.push(a + b);
            }
            ExprKind::Print => {
                if stack.len() < 1 {
                    return Err(ChaiError::SourceError(
                        expr.source,
                        expr.position,
                        "Expected 1 or more elements on stack.".to_owned(),
                    ));
                }

                println!("{}", stack.pop().unwrap());
            }
        }
    }

    Ok(())
}
