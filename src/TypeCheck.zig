const std = @import("std");
const Allocator = std.mem.Allocator;
const ValueTagArrayList = std.ArrayList(ValueTag);

const expr = @import("expr.zig");
const Expr = expr.Expr;
const ExprKind = expr.ExprKind;
const ExprKindTag = expr.ExprKindTag;
const Value = expr.Value;
const ValueTag = expr.ValueTag;

pub fn type_check_exprs(exprs: []Expr, allocator: Allocator) !void {
    var type_stack = ValueTagArrayList.init(allocator);

    for (exprs) |e| {
        switch (e.kind) {
            .Push => |value| try type_stack.append(@as(ValueTag, value)),
            .Plus, .Minus, .Multiply, .Divide => {
                if (type_stack.items.len < 2) {
                    std.log.err("{}: Expected at least 2 elements on stack, found {d} instead", .{ e.src_loc, type_stack.items.len });
                    return error.TypeCheckError;
                }
                const t2 = type_stack.pop();
                const t1 = type_stack.pop();
                if (t1 != .Integer and t1 != .Float) {
                    std.log.err("{}: Expected either float or integer value, found {s} instead", .{ e.src_loc, t1.getHumanName() });
                    return error.TypeCheckError;
                }
                if (t2 != .Integer and t2 != .Float) {
                    std.log.err("{}: Expected either float or integer value, found {s} instead", .{ e.src_loc, t2.getHumanName() });
                    return error.TypeCheckError;
                }
                if (t1 != t2) {
                    std.log.err("{}: Expected both values to be of the same type, found {s} and {s} instead", .{ e.src_loc, t1.getHumanName(), t2.getHumanName() });
                    return error.TypeCheckError;
                }
                // Both t1 and t2 are guaranteed to be the same, so we can just re-push one of their values here
                try type_stack.append(t1);
            },
            .Mod => {
                if (type_stack.items.len < 2) {
                    std.log.err("{}: Expected at least 2 elements on stack, found {d} instead", .{ e.src_loc, type_stack.items.len });
                    return error.TypeCheckError;
                }
                const t2 = type_stack.pop();
                const t1 = type_stack.pop();
                if (t1 != .Integer) {
                    std.log.err("{}: Expected integer value, found {s} instead", .{ e.src_loc, t1.getHumanName() });
                    return error.TypeCheckError;
                }
                if (t2 != .Integer) {
                    std.log.err("{}: Expected integer value, found {s} instead", .{ e.src_loc, t2.getHumanName() });
                    return error.TypeCheckError;
                }
                try type_stack.append(.Integer);
            },
        }
    }
}
