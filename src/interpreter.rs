use crate::error::ChaiError;
use crate::expr::{Expr, ExprKind, Value};

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

                let val = stack.pop().unwrap();
                let a = match val {
                    Value::Number(n) => n,
                    _ => {
                        return Err(ChaiError::SourceError(
                            expr.source,
                            expr.position,
                            format!("Expected Value::Number(), found {:?} instead.", val),
                        ));
                    }
                };
                let val = stack.pop().unwrap();
                let b = match val {
                    Value::Number(n) => n,
                    _ => {
                        return Err(ChaiError::SourceError(
                            expr.source,
                            expr.position,
                            format!("Expected Value::Number(), found {:?} instead.", val),
                        ));
                    }
                };
                stack.push(Value::Number(a + b));
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
