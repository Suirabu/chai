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

    fn collectPush(self: *Self) !Expr {
        const tok = self.advance();
        return Expr{ .kind = ExprKind{ .Push = try Value.fromTokenKind(tok.kind) }, .src_loc = tok.src_loc };
    }

    fn collectPlus(self: *Self) !Expr {
        const tok = self.advance();
        return Expr{ .kind = .Plus, .src_loc = tok.src_loc };
    }

    fn collectMinus(self: *Self) !Expr {
        const tok = self.advance();
        return Expr{ .kind = .Minus, .src_loc = tok.src_loc };
    }
    fn collectMultiply(self: *Self) !Expr {
        const tok = self.advance();
        return Expr{ .kind = .Multiply, .src_loc = tok.src_loc };
    }
    fn collectDivide(self: *Self) !Expr {
        const tok = self.advance();
        return Expr{ .kind = .Divide, .src_loc = tok.src_loc };
    }
    fn collectMod(self: *Self) !Expr {
        const tok = self.advance();
        return Expr{ .kind = .Mod, .src_loc = tok.src_loc };
    }
    fn collectNeg(self: *Self) !Expr {
        const tok = self.advance();
        return Expr{ .kind = .Neg, .src_loc = tok.src_loc };
    }

    fn collectDrop(self: *Self) !Expr {
        const tok = self.advance();
        return Expr{ .kind = .Drop, .src_loc = tok.src_loc };
    }
    fn collectDup(self: *Self) !Expr {
        const tok = self.advance();
        return Expr{ .kind = .Dup, .src_loc = tok.src_loc };
    }
    fn collectOver(self: *Self) !Expr {
        const tok = self.advance();
        return Expr{ .kind = .Over, .src_loc = tok.src_loc };
    }
    fn collectSwap(self: *Self) !Expr {
        const tok = self.advance();
        return Expr{ .kind = .Swap, .src_loc = tok.src_loc };
    }
    fn collectRot(self: *Self) !Expr {
        const tok = self.advance();
        return Expr{ .kind = .Rot, .src_loc = tok.src_loc };
    }

    fn collectPrint(self: *Self) !Expr {
        const tok = self.advance();
        return Expr{ .kind = .Print, .src_loc = tok.src_loc };
    }

    fn collectExpr(self: *Self) !Expr {
        return switch (self.peek().kind) {
            .BooleanLiteral, .CharacterLiteral, .IntegerLiteral, .FloatLiteral, .StringLiteral => return self.collectPush(),
            .Plus => self.collectPlus(),
            .Minus => self.collectMinus(),
            .Star => self.collectMultiply(),
            .Slash => self.collectDivide(),
            .Perc => self.collectMod(),
            .Neg => self.collectNeg(),

            .Drop => self.collectDrop(),
            .Dup => self.collectDup(),
            .Over => self.collectOver(),
            .Swap => self.collectSwap(),
            .Rot => self.collectRot(),

            .Print => self.collectPrint(),

            else => {
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
