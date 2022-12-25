const std = @import("std");
const fmt = std.fmt;
const Allocator = std.mem.Allocator;

const token = @import("token.zig");
const TokenKind = token.TokenKind;
const SrcLoc = token.SrcLoc;

pub const ValueTag = enum {
    const Self = @This();

    Bool,
    Integer,
    Float,
    String,
    Ptr,

    pub fn getHumanName(self: Self) []const u8 {
        return switch (self) {
            .Bool => "bool",
            .Integer => "integer",
            .Float => "float",
            .String => "string",
            .Ptr => "pointer",
        };
    }
};

pub const Value = union(ValueTag) {
    const Self = @This();

    Bool: bool,
    Integer: i64,
    Float: f64,
    String: []const u8,
    Ptr: u64,

    pub fn fromTokenKind(kind: TokenKind) !Value {
        return switch (kind) {
            .BooleanLiteral => |value| Value{ .Bool = value },
            .CharacterLiteral => |value| Value{ .Integer = value },
            .IntegerLiteral => |value| Value{ .Integer = value },
            .FloatLiteral => |value| Value{ .Float = value },
            .StringLiteral => |value| Value{ .String = value },
            else => {
                std.log.err("Failed to convert token of kind '{s}' to value", .{kind.getHumanName()});
                return error.ValueConversion;
            },
        };
    }

    pub fn format(self: Self, comptime layout: []const u8, opts: fmt.FormatOptions, writer: anytype) !void {
        _ = layout;
        _ = opts;

        switch (self) {
            .Bool => |value| {
                // There must be a better way of doing this... right?
                const str = switch (value) {
                    true => "true",
                    false => "false",
                };
                try fmt.format(writer, "{s}", .{str});
            },
            .Integer => |value| try fmt.format(writer, "{d}", .{value}),
            .Float => |value| try fmt.format(writer, "{d}", .{value}),
            .String => |value| try fmt.format(writer, "\"{s}\"", .{value}),
            .Ptr => |value| try fmt.format(writer, "0x{X}", .{value}),
        }
    }
};

pub const ExprKindTag = enum {
    Push,

    Plus,
    Minus,
    Multiply,
    Divide,
    Mod,
    Neg,

    Equal,
    Less,
    LessEqual,
    Greater,
    GreaterEqual,
    Not,
    And,
    Or,

    Drop,
    Dup,
    Over,
    Swap,
    Rot,

    Print,

    If,
};

pub const ExprKind = union(ExprKindTag) {
    const Self = @This();

    Push: Value,

    Plus,
    Minus,
    Multiply,
    Divide,
    Mod,
    Neg,

    Equal,
    Less,
    LessEqual,
    Greater,
    GreaterEqual,
    Not,
    And,
    Or,

    Drop,
    Dup,
    Over,
    Swap,
    Rot,

    Print,

    If: struct { main_body: []Expr, else_body: ?[]Expr },

    pub fn getHumanName(self: Self) []const u8 {
        return switch (self) {
            .Push => "push",

            .Plus => "plus",
            .Minus => "minus",
            .Multiply => "multiply",
            .Divide => "divide",
            .Mod => "mod",
            .Neg => "neg",

            .Equal => "equal",
            .Less => "less than",
            .LessEqual => "less than or equal",
            .Greater => "greater than",
            .GreaterEqual => "greater than or equal",
            .Not => "not",
            .And => "and",
            .Or => "or",

            .Drop => "drop",
            .Dup => "dup",
            .Over => "over",
            .Swap => "swap",
            .Rot => "rot",

            .Print => "print",

            .If => "if",
        };
    }

    pub fn fromTokenKind(kind: TokenKind) !ExprKind {
        return switch (kind) {
            .BooleanLiteral, .CharacterLiteral, .IntegerLiteral, .FloatLiteral, .StringLiteral => ExprKind{ .Push = try Value.fromTokenKind(kind) },

            .Plus => .Plus,
            .Minus => .Minus,
            .Star => .Multiply,
            .Slash => .Divide,
            .Perc => .Mod,
            .Neg => .Neg,

            .Equal => .Equal,
            .Less => .Less,
            .LessEqual => .LessEqual,
            .Greater => .Greater,
            .GreaterEqual => .GreaterEqual,
            .Not => .Not,
            .And => .And,
            .Or => .Or,

            .Drop => .Drop,
            .Dup => .Dup,
            .Over => .Over,
            .Swap => .Swap,
            .Rot => .Rot,

            .Print => .Print,

            else => {
                std.log.err("Failed to convert token of kind '{s}' to expr", .{kind.getHumanName()});
                return error.ExprConversion;
            },
        };
    }

    pub fn format(self: Self, comptime layout: []const u8, opts: fmt.FormatOptions, writer: anytype) !void {
        _ = layout;
        _ = opts;

        switch (self) {
            .Push => |value| try fmt.format(writer, "{s} ({})", .{ self.getHumanName(), value }),
            else => try fmt.format(writer, "{s}", .{self.getHumanName()}),
        }
    }
};

pub const Expr = struct {
    const Self = @This();

    kind: ExprKind,
    src_loc: SrcLoc,

    pub fn format(self: Self, comptime layout: []const u8, opts: fmt.FormatOptions, writer: anytype) !void {
        _ = layout;
        _ = opts;

        try fmt.format(writer, "expr: {}: {}", .{ self.src_loc, self.kind });
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        switch (self.kind) {
            .If => |stmt| {
                allocator.free(stmt.main_body);
                if (stmt.else_body) |else_body| {
                    allocator.free(else_body);
                }
            },
            else => {},
        }
    }
};
