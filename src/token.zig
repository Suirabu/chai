const std = @import("std");
const fmt = std.fmt;

pub const TokenKindTag = enum {
    const Self = @This();

    IntegerLiteral,
    FloatLiteral,
    StringLiteral,
    CharacterLiteral,
    BooleanLiteral,
};

pub const TokenKind = union(TokenKindTag) {
    const Self = @This();

    IntegerLiteral: isize,
    FloatLiteral: f64,
    StringLiteral: []const u8,
    CharacterLiteral: u8,
    BooleanLiteral: bool,

    pub fn getHumanName(self: Self) []const u8 {
        const tag: TokenKindTag = self;

        return switch (tag) {
            .IntegerLiteral => "integer literal",
            .FloatLiteral => "float literal",
            .StringLiteral => "string literal",
            .CharacterLiteral => "character literal",
            .BooleanLiteral => "boolean literal",
        };
    }
};

pub const Token = struct {
    const Self = @This();

    kind: TokenKind,
    src_loc: SrcLoc,

    fn getBooleanAsString(value: bool) []const u8 {
        return switch (value) {
            true => "true",
            false => "false",
        };
    }

    pub fn format(self: Self, comptime layout: []const u8, opts: fmt.FormatOptions, writer: anytype) !void {
        _ = layout;
        _ = opts;

        switch (self.kind) {
            .IntegerLiteral => |value| try fmt.format(writer, "Token: {}: {s} ({d})", .{ self.src_loc, self.kind.getHumanName(), value }),
            .FloatLiteral => |value| try fmt.format(writer, "Token: {}: {s} ({e})", .{ self.src_loc, self.kind.getHumanName(), value }),
            .StringLiteral => |value| try fmt.format(writer, "Token: {}: {s} (\"{s}\")", .{ self.src_loc, self.kind.getHumanName(), value }),
            .CharacterLiteral => |value| try fmt.format(writer, "Token: {}: {s} ('{c}')", .{ self.src_loc, self.kind.getHumanName(), value }),
            .BooleanLiteral => |value| try fmt.format(writer, "Token: {}: {s} ({s})", .{ self.src_loc, self.kind.getHumanName(), getBooleanAsString(value) }),
        }
    }
};

pub const SrcLoc = struct {
    const Self = @This();

    line: usize,
    column: usize,
    path: []const u8,

    pub fn format(self: Self, comptime layout: []const u8, opts: fmt.FormatOptions, writer: anytype) !void {
        _ = layout;
        _ = opts;
        try fmt.format(writer, "{s} ({d},{d})", .{ self.path, self.line + 1, self.column });
    }
};
