const std = @import("std");
const Allocator = std.mem.Allocator;

const token = @import("token.zig");
const TokenTag = token.TokenTag;
const Token = token.Token;
const expr = @import("expr.zig");
const ExprKindTag = expr.ExprKindTag;
const ExprKind = expr.ExprKind;
const Expr = expr.Expr;
const ValueTag = expr.ValueTag;
const Value = expr.Value;

pub const Parser = struct {
    const Self = @This();

    tokens: []Token,
    cursor: usize,
    allocator: Allocator,

    pub fn init(allocator: Allocator, tokens: []Token) Self {
        return Self{
            .tokens = tokens,
            .cursor = 0,
            .allocator = allocator,
        };
    }

    fn reachedEnd(self: Self) bool {
        return self.cursor >= self.tokens.len;
    }

    fn peek(self: Self) Token {
        return self.tokens[self.cursor];
    }

    fn advance(self: *Self) Token {
        const e = self.peek();
        self.cursor += 1;
        return e;
    }

    fn collectSimpleExpr(self: *Self) !Expr {
        const tok = self.advance();
        return Expr{ .kind = try ExprKind.fromTokenKind(tok.kind), .src_loc = tok.src_loc };
    }

    fn collectExpr(self: *Self) !Expr {
        return switch (self.peek().kind) {
            // zig fmt really loves screwing this one up
            .BooleanLiteral, .CharacterLiteral, .IntegerLiteral, .FloatLiteral, .StringLiteral, .Plus, .Minus, .Star, .Slash, .Perc, .Neg, .Drop, .Dup, .Over, .Swap, .Rot, .Print => return self.collectSimpleExpr(),

            .Identifier => {
                std.log.err("{}: Cannot parse expression from token '{s}'", .{ self.peek().src_loc, self.peek().kind.getHumanName() });
                _ = self.advance();
                return error.ParserError;
            },
        };
    }

    pub fn collectExprs(self: *Self) ![]Expr {
        var exprs = std.ArrayList(Expr).init(self.allocator);
        var has_error = false;

        while (!self.reachedEnd()) {
            if (self.collectExpr()) |e| {
                try exprs.append(e);
            } else |_| {
                has_error = true;
            }
        }

        if (has_error) {
            return error.ParserError;
        } else {
            return exprs.items;
        }
    }
};
