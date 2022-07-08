use crate::error::ChaiError;
use crate::expr::Expr;

pub fn interpret_program(exprs: Vec<Expr>) -> Result<(), ChaiError> {
    let mut stack = Vec::new();

    for expr in exprs {
        match expr {
            Expr::Push(v) => stack.push(v),

            Expr::Add => {
                if stack.len() < 2 {
                    return Err(ChaiError::StandardError(
                        "Expected 2 or more elements on stack.".to_owned(),
                    ));
                }

                let a = stack.pop().unwrap();
                let b = stack.pop().unwrap();
                stack.push(a + b);
            }
            Expr::Print => {
                if stack.len() < 1 {
                    return Err(ChaiError::StandardError(
                        "Expected 1 or more elements on stack.".to_owned(),
                    ));
                }

                println!("{}", stack.pop().unwrap());
            }
        }
    }

    Ok(())
}
