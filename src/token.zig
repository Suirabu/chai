const std = @import("std");
const fmt = std.fmt;

pub const TokenKindTag = enum {
    const Self = @This();

    IntegerLiteral,
    FloatLiteral,
};

pub const TokenKind = union(TokenKindTag) {
    const Self = @This();

    IntegerLiteral: isize,
    FloatLiteral: f64,

    pub fn getHumanName(self: Self) []const u8 {
        const tag: TokenKindTag = self;
        return switch (tag) {
            .IntegerLiteral => "integer literal",
            .FloatLiteral => "float literal",
        };
    }
};

pub const Token = struct {
    const Self = @This();

    kind: TokenKind,
    src_loc: SrcLoc,

    pub fn format(self: Self, comptime layout: []const u8, opts: fmt.FormatOptions, writer: anytype) !void {
        _ = layout;
        _ = opts;
        try fmt.format(writer, "Token: {}: {s}", .{ self.src_loc, self.kind.getHumanName() });
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
