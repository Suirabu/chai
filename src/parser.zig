const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const token = @import("token.zig");
const TokenKind = token.TokenKind;
const TokenKindTag = token.TokenKindTag;
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

    fn expect(self: *Self, kind: TokenKindTag) !Token {
        if (self.reachedEnd()) {
            std.log.err("{}: Expected {}, found end of file instead", .{ self.tokens[self.tokens.len - 1].src_loc, kind });
            return error.ParserError;
        }

        const tok = self.advance();
        if (tok.kind != kind) {
            std.log.err("{}: Expected {}, found {} instead", .{ tok.src_loc, kind, tok.kind });
            return error.ParserError;
        }

        return tok;
    }

    fn collectSimpleExpr(self: *Self) !Expr {
        const tok = self.advance();
        return Expr{ .kind = try ExprKind.fromTokenKind(tok.kind), .src_loc = tok.src_loc };
    }

    fn collectBody(self: *Self) ![]Expr {
        _ = try self.expect(.LeftBrace);

        // TODO: Figure out if this is leaking memory or not
        // These cannot be deallocated before the codegen phase as this invokes
        // undefined behavior
        var exprs = std.ArrayList(Expr).init(self.allocator);
        while (!self.reachedEnd() and self.peek().kind != .RightBrace) {
            try exprs.append(try self.collectExpr());
        }

        _ = try self.expect(.RightBrace);
        return exprs.items;
    }

    fn collectIf(self: *Self) !Expr {
        const tok = try self.expect(.If);
        const body = try self.collectBody();

        var else_body: ?[]Expr = null;
        if (!self.reachedEnd() and self.peek().kind == .Else) {
            _ = self.advance();
            else_body = try self.collectBody();
        }

        return Expr{ .kind = ExprKind{ .If = .{ .main_body = body, .else_body = else_body } }, .src_loc = tok.src_loc };
    }

    fn collectExpr(self: *Self) !Expr {
        return switch (self.peek().kind) {
            // zig fmt really loves screwing this one up
            .BooleanLiteral, .CharacterLiteral, .IntegerLiteral, .FloatLiteral, .StringLiteral, .Plus, .Minus, .Star, .Slash, .Perc, .Neg, .Equal, .Less, .LessEqual, .Greater, .GreaterEqual, .Not, .And, .Or, .Drop, .Dup, .Over, .Swap, .Rot, .Print => return self.collectSimpleExpr(),
            .If => self.collectIf(),

            .Identifier, .LeftBrace, .RightBrace, .Else => {
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
