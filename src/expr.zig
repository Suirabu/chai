const std = @import("std");
const fmt = std.fmt;

const token = @import("token.zig");
const TokenKind = token.TokenKind;
const SrcLoc = token.SrcLoc;

pub const ValueTag = enum {
    Bool,
    Character,
    Integer,
    Float,
    String,
    Ptr,
};

pub const Value = union(ValueTag) {
    const Self = @This();

    Bool: bool,
    Character: u8,
    Integer: i64,
    Float: f64,
    String: []const u8,
    Ptr: u64,

    pub fn fromTokenKind(kind: TokenKind) !Value {
        return switch (kind) {
            .BooleanLiteral => |value| Value{ .Bool = value },
            .CharacterLiteral => |value| Value{ .Character = value },
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
            .Character => |value| try fmt.format(writer, "'{c}'", .{value}),
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
};

pub const ExprKind = union(ExprKindTag) {
    const Self = @This();

    Push: Value,

    Plus,
    Minus,
    Multiply,
    Divide,
    Mod,

    pub fn getHumanName(self: Self) []const u8 {
        return switch (self) {
            .Push => "push",

            .Plus => "plus",
            .Minus => "minus",
            .Multiply => "multiply",
            .Divide => "divide",
            .Mod => "mod",
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
};
