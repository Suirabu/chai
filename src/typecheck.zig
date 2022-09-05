const std = @import("std");
const Allocator = std.mem.Allocator;
const ValueTagArrayList = std.ArrayList(ValueTag);

const expr = @import("expr.zig");
const Expr = expr.Expr;
const ExprKind = expr.ExprKind;
const ExprKindTag = expr.ExprKindTag;
const Value = expr.Value;
const ValueTag = expr.ValueTag;

pub const TypeChecker = struct {
    const Self = @This();

    exprs: []Expr,
    cursor: usize,
    type_stack: ValueTagArrayList,

    pub fn init(exprs: []Expr, allocator: Allocator) Self {
        return Self{
            .exprs = exprs,
            .cursor = 0,
            .type_stack = ValueTagArrayList.init(allocator),
        };
    }

    fn reached_end(self: Self) bool {
        return self.cursor >= self.exprs.len;
    }

    fn peek(self: Self) Expr {
        return self.exprs[self.cursor];
    }

    fn advance(self: *Self) Expr {
        const e = self.peek();
        self.cursor += 1;
        return e;
    }

    pub fn check(self: *Self) !void {
        while (!self.reached_end()) {
            const e = self.advance();
            switch (e.kind) {
                .Push => |value| {
                    if (value == .String) {
                        try self.type_stack.append(.Ptr);
                        try self.type_stack.append(.Integer);
                    } else {
                        try self.type_stack.append(value);
                    }
                },
                .Plus => {
                    if (self.type_stack.items.len < 2) {
                        std.log.err("{}: Expected at least 2 elements on stack, found {d} instead", .{ e.src_loc, self.type_stack.items.len });
                        return error.NotEnoughElements;
                    }
                    const t2 = self.type_stack.pop();
                    const t1 = self.type_stack.pop();
                    // Make sure the correct types are being used
                    if (t1 != .Integer and t1 != .Float and t1 != .Ptr) {
                        std.log.err("{}: Invalid type {s} used with plus operation. Valid types include integers, floats, and pointers", .{ e.src_loc, t2.getHumanName() });
                        return error.InvalidType;
                    }
                    if (t2 != .Integer and t2 != .Float and t1 != .Ptr) {
                        std.log.err("{}: Invalid type {s} used with plus operation. Valid types include integers, floats, and pointers", .{ e.src_loc, t2.getHumanName() });
                        return error.InvalidType;
                    }
                    // Make sure the correct type combinations are being used
                    if ((t1 == .Ptr and t2 == .Integer) or (t1 == .Integer and t2 == .Ptr)) {
                        try self.type_stack.append(.Ptr);
                    } else if (t1 == t2 and t1 != .Ptr) { // Allow int + int, and float + float, but not ptr + ptr
                        try self.type_stack.append(t1);
                    } else {
                        std.log.err("{}: Cannot use types {s} and {s} together in plus operation", .{ e.src_loc, t1.getHumanName(), t2.getHumanName() });
                        return error.InvalidTypeCombination;
                    }
                },
                .Minus => {
                    if (self.type_stack.items.len < 2) {
                        std.log.err("{}: Expected at least 2 elements on stack, found {d} instead", .{ e.src_loc, self.type_stack.items.len });
                        return error.NotEnoughElements;
                    }
                    const t2 = self.type_stack.pop();
                    const t1 = self.type_stack.pop();
                    // Make sure the correct types are being used
                    if (t1 != .Integer and t1 != .Float and t1 != .Ptr) {
                        std.log.err("{}: Invalid type {s} used with minus operation. Valid types include integers, floats, and pointers", .{ e.src_loc, t2.getHumanName() });
                        return error.InvalidType;
                    }
                    if (t2 != .Integer and t2 != .Float and t1 != .Ptr) {
                        std.log.err("{}: Invalid type {s} used with minus operation. Valid types include integers, floats, and pointers", .{ e.src_loc, t2.getHumanName() });
                        return error.InvalidType;
                    }
                    // Make sure the correct type combinations are being used
                    if ((t1 == .Ptr and t2 == .Integer) or (t1 == .Integer and t2 == .Ptr)) {
                        try self.type_stack.append(.Ptr);
                    } else if (t1 == t2) {
                        try self.type_stack.append(t1);
                    } else {
                        std.log.err("{}: Cannot use types {s} and {s} together in minus operation", .{ e.src_loc, t1.getHumanName(), t2.getHumanName() });
                        return error.InvalidTypeCombination;
                    }
                },
                .Multiply, .Divide => {
                    if (self.type_stack.items.len < 2) {
                        std.log.err("{}: Expected at least 2 elements on stack, found {d} instead", .{ e.src_loc, self.type_stack.items.len });
                        return error.NotEnoughElements;
                    }
                    const t2 = self.type_stack.pop();
                    const t1 = self.type_stack.pop();
                    // Make sure the correct types are being used
                    if (t1 != .Integer and t1 != .Float) {
                        std.log.err("{}: Invalid type {s} used with {s} operation. Valid types include integers, and floats", .{ e.src_loc, e.kind.getHumanName(), t2.getHumanName() });
                        return error.InvalidType;
                    }
                    if (t2 != .Integer and t2 != .Float) {
                        std.log.err("{}: Invalid type {s} used with {s} operation. Valid types include integers, and floats", .{ e.src_loc, e.kind.getHumanName(), t2.getHumanName() });
                        return error.InvalidType;
                    }
                    // Make sure the correct type combinations are being used
                    if (t1 == t2) {
                        try self.type_stack.append(t1);
                    } else {
                        std.log.err("{}: Cannot use types {s} and {s} together in {s} operation", .{ e.src_loc, t1.getHumanName(), t2.getHumanName(), e.kind.getHumanName() });
                        return error.InvalidTypeCombination;
                    }
                },
                .Mod => {
                    if (self.type_stack.items.len < 2) {
                        std.log.err("{}: Expected at least 2 elements on stack, found {d} instead", .{ e.src_loc, self.type_stack.items.len });
                        return error.NotEnoughElements;
                    }
                    const t2 = self.type_stack.pop();
                    const t1 = self.type_stack.pop();
                    // Make sure the correct types are being used
                    if (t1 != .Integer) {
                        std.log.err("{}: Invalid type {s} used with mod operation. Modulo operations may only be performed on integers", .{ e.src_loc, t2.getHumanName() });
                        return error.InvalidType;
                    }
                    if (t2 != .Integer) {
                        std.log.err("{}: Invalid type {s} used with mod operation. Modulo operations may only be performed on integers", .{ e.src_loc, t2.getHumanName() });
                        return error.InvalidType;
                    }
                    try self.type_stack.append(t1);
                },
                .Neg => {
                    if (self.type_stack.items.len < 1) {
                        std.log.err("{}: Expected at least 1 elements on stack, found {d} instead", .{ e.src_loc, self.type_stack.items.len });
                        return error.NotEnoughElements;
                    }
                    const t = self.type_stack.pop();
                    if (t != .Integer) {
                        std.log.err("{}: Invalid type {s} used with negation operation. Negation operations may only be performed on integers", .{ e.src_loc, t.getHumanName() });
                        return error.InvalidType;
                    }
                    try self.type_stack.append(t);
                },

                .Drop => {
                    if (self.type_stack.items.len < 1) {
                        std.log.err("{}: Expected at least 1 elements on stack, found {d} instead", .{ e.src_loc, self.type_stack.items.len });
                        return error.NotEnoughElements;
                    }
                    _ = self.type_stack.pop();
                },
                .Dup => {
                    if (self.type_stack.items.len < 1) {
                        std.log.err("{}: Expected at least 1 elements on stack, found {d} instead", .{ e.src_loc, self.type_stack.items.len });
                        return error.NotEnoughElements;
                    }
                    const t = self.type_stack.pop();
                    try self.type_stack.append(t);
                    try self.type_stack.append(t);
                },
                .Over => {
                    if (self.type_stack.items.len < 2) {
                        std.log.err("{}: Expected at least 1 elements on stack, found {d} instead", .{ e.src_loc, self.type_stack.items.len });
                        return error.NotEnoughElements;
                    }
                    const t2 = self.type_stack.pop();
                    const t1 = self.type_stack.pop();
                    try self.type_stack.append(t1);
                    try self.type_stack.append(t2);
                    try self.type_stack.append(t1);
                },
                .Swap => {
                    if (self.type_stack.items.len < 1) {
                        std.log.err("{}: Expected at least 1 elements on stack, found {d} instead", .{ e.src_loc, self.type_stack.items.len });
                        return error.NotEnoughElements;
                    }
                    const t2 = self.type_stack.pop();
                    const t1 = self.type_stack.pop();
                    try self.type_stack.append(t2);
                    try self.type_stack.append(t1);
                },
                .Rot => {
                    if (self.type_stack.items.len < 1) {
                        std.log.err("{}: Expected at least 1 elements on stack, found {d} instead", .{ e.src_loc, self.type_stack.items.len });
                        return error.NotEnoughElements;
                    }
                    const t3 = self.type_stack.pop();
                    const t2 = self.type_stack.pop();
                    const t1 = self.type_stack.pop();
                    try self.type_stack.append(t2);
                    try self.type_stack.append(t3);
                    try self.type_stack.append(t1);
                },
                .Print => {
                    if (self.type_stack.items.len < 1) {
                        std.log.err("{}: Expected at least 1 elements on stack, found {d} instead", .{ e.src_loc, self.type_stack.items.len });
                        return error.NotEnoughElements;
                    }
                    const t = self.type_stack.pop();
                    if (t != .Integer) {
                        std.log.err("{}: Invalid type {s} used with print operation. Print operations may only be performed on integers", .{ e.src_loc, t.getHumanName() });
                        return error.InvalidType;
                    }
                },
            }
        }

        if (self.type_stack.items.len != 0) {
            std.log.err("Expected 0 elements left remaining on stack before exiting, found {d}", .{self.type_stack.items.len});
            return error.RemainingElements;
        }
    }
};
