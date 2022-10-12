const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
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
    allocator: Allocator,

    pub fn init(exprs: []Expr, allocator: Allocator) Self {
        return Self{
            .exprs = exprs,
            .cursor = 0,
            .type_stack = ValueTagArrayList.init(allocator),
            .allocator = allocator,
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

    fn expect_minimum_elements(self: Self, e: Expr, min: usize) !void {
        const stack_len = self.type_stack.items.len;

        if (stack_len < min) {
            std.log.err("{}: Expression '{s}' expected at least {d} element(s) on stack, found {d} instead", .{ e.src_loc, e.kind.getHumanName(), min, stack_len });
            return error.NotEnoughElements;
        }
    }

    pub fn check_program(self: *Self) !void {
        while (!self.reached_end()) {
            try self.check_expr(self.advance());
        }

        if (self.type_stack.items.len != 0) {
            std.log.err("Expected 0 elements left remaining on stack before exiting, found {d}", .{self.type_stack.items.len});
            return error.RemainingElements;
        }
    }

    // TODO: Reduce code repitition
    fn check_expr(self: *Self, e: Expr) !void {
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
                try self.expect_minimum_elements(e, 2);
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
                try self.expect_minimum_elements(e, 2);
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
                try self.expect_minimum_elements(e, 2);
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
                try self.expect_minimum_elements(e, 2);
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
                try self.expect_minimum_elements(e, 1);
                const t = self.type_stack.pop();
                if (t != .Integer) {
                    std.log.err("{}: Invalid type {s} used with negation operation. Negation operations may only be performed on integers", .{ e.src_loc, t.getHumanName() });
                    return error.InvalidType;
                }
                try self.type_stack.append(t);
            },

            .Drop => {
                try self.expect_minimum_elements(e, 1);
                _ = self.type_stack.pop();
            },
            .Dup => {
                try self.expect_minimum_elements(e, 1);
                const t = self.type_stack.pop();
                try self.type_stack.append(t);
                try self.type_stack.append(t);
            },
            .Over => {
                try self.expect_minimum_elements(e, 2);
                const t2 = self.type_stack.pop();
                const t1 = self.type_stack.pop();
                try self.type_stack.append(t1);
                try self.type_stack.append(t2);
                try self.type_stack.append(t1);
            },
            .Swap => {
                try self.expect_minimum_elements(e, 2);
                const t2 = self.type_stack.pop();
                const t1 = self.type_stack.pop();
                try self.type_stack.append(t2);
                try self.type_stack.append(t1);
            },
            .Rot => {
                try self.expect_minimum_elements(e, 3);
                const t3 = self.type_stack.pop();
                const t2 = self.type_stack.pop();
                const t1 = self.type_stack.pop();
                try self.type_stack.append(t2);
                try self.type_stack.append(t3);
                try self.type_stack.append(t1);
            },
            .Print => {
                try self.expect_minimum_elements(e, 1);
                const t = self.type_stack.pop();
                if (t != .Integer) {
                    std.log.err("{}: Invalid type {s} used with print operation. Print operations may only be performed on integers", .{ e.src_loc, t.getHumanName() });
                    return error.InvalidType;
                }
            },
            .If => |stmt| {
                try self.expect_minimum_elements(e, 1);
                const t = self.type_stack.pop();
                if (t != .Bool) {
                    std.log.err("{}: Invalid type {s} used in if statement. If statements only accept boolean values", .{ e.src_loc, t.getHumanName() });
                    return error.InvalidType;
                }

                // Ensure that all possible paths affect the stack in the same way for type safety reasons
                var state = try self.type_stack.clone();

                for (stmt.main_body) |se| {
                    try self.check_expr(se);
                }

                // Get assumed type signature
                var type_signature = try self.type_stack.clone();

                if (stmt.else_body) |else_body| {
                    // Reset type stack to test alternate paths
                    self.type_stack = state;

                    for (else_body) |se| {
                        try self.check_expr(se);
                    }

                    // Compare type stack to type signature
                    if (!mem.eql(ValueTag, self.type_stack.items, type_signature.items)) {
                        std.log.err("{}: Code paths return different values", .{e.src_loc});
                        return error.UnequalSignatures;
                    }
                }
            },
        }
    }
};
