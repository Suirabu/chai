const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

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
    type_stack: std.ArrayList(ValueTag),
    allocator: Allocator,

    pub fn init(exprs: []Expr, allocator: Allocator) Self {
        return Self{
            .exprs = exprs,
            .cursor = 0,
            .type_stack = std.ArrayList(ValueTag).init(allocator),
            .allocator = allocator,
        };
    }

    fn reachedEnd(self: Self) bool {
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

    fn expectMinimumElements(self: Self, e: Expr, min: usize) !void {
        const stack_len = self.type_stack.items.len;

        if (stack_len < min) {
            std.log.err("{}: Expression '{s}' expected at least {d} element(s) on stack, found {d} instead", .{ e.src_loc, e.kind.getHumanName(), min, stack_len });
            return error.NotEnoughElements;
        }
    }

    fn expectType(self: *Self, e: Expr, valid_types: anytype) !ValueTag {
        const t = self.type_stack.pop();
        inline for (valid_types) |valid_type| {
            if (t == valid_type) {
                return t;
            }
        }

        // TODO: Include allowed types in diagnostic
        std.log.err("{}: Invalid type '{s}' used with expression '{s}'", .{ e.src_loc, t.getHumanName(), e.kind.getHumanName() });
        return error.InvalidType;
    }

    pub fn checkProgram(self: *Self) !void {
        while (!self.reachedEnd()) {
            try self.checkExpr(self.advance());
        }

        if (self.type_stack.items.len != 0) {
            std.log.err("Expected 0 elements left remaining on stack before exiting, found {d}", .{self.type_stack.items.len});
            return error.RemainingElements;
        }

        self.type_stack.deinit();
    }

    // TODO: Reduce code repitition
    fn checkExpr(self: *Self, e: Expr) !void {
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
                try self.expectMinimumElements(e, 2);

                // Make sure the correct types are being used
                const t2 = try self.expectType(e, .{ .Integer, .Float, .Ptr });
                const t1 = try self.expectType(e, .{ .Integer, .Float, .Ptr });

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
                try self.expectMinimumElements(e, 2);

                // Make sure the correct types are being used
                const t2 = try self.expectType(e, .{ .Integer, .Float, .Ptr });
                const t1 = try self.expectType(e, .{ .Integer, .Float, .Ptr });

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
                try self.expectMinimumElements(e, 2);

                // Make sure the correct types are being used
                const t2 = try self.expectType(e, .{ .Integer, .Float });
                const t1 = try self.expectType(e, .{ .Integer, .Float });

                // Make sure the correct type combinations are being used
                if (t1 == t2) {
                    try self.type_stack.append(t1);
                } else {
                    std.log.err("{}: Cannot use types {s} and {s} together in {s} operation", .{ e.src_loc, t1.getHumanName(), t2.getHumanName(), e.kind.getHumanName() });
                    return error.InvalidTypeCombination;
                }
            },
            .Mod => {
                try self.expectMinimumElements(e, 2);

                // Make sure the correct types are being used
                _ = try self.expectType(e, .{.Integer});
                _ = try self.expectType(e, .{.Integer});

                try self.type_stack.append(.Integer);
            },
            .Neg => {
                try self.expectMinimumElements(e, 1);
                const t = try self.expectType(e, .{.Integer});
                try self.type_stack.append(t);
            },
            .Equal => {
                try self.expectMinimumElements(e, 2);
                const t1 = try self.expectType(e, .{ .Integer, .Float, .Bool });
                const t2 = try self.expectType(e, .{ .Integer, .Float, .Bool });
                if (t1 != t2) {
                    // TODO: Checking if two types are equal is a really common pattern used in typechecking. Consider making a function for this.
                    std.log.err("{}: Cannot use types {s} and {s} together in equal operation", .{ e.src_loc, t1.getHumanName(), t2.getHumanName() });
                    return error.InvalidTypeCombination;
                }
                try self.type_stack.append(.Bool);
            },
            .Less, .LessEqual, .Greater, .GreaterEqual => {
                try self.expectMinimumElements(e, 2);
                const t1 = try self.expectType(e, .{ .Integer, .Float });
                const t2 = try self.expectType(e, .{ .Integer, .Float });
                if (t1 != t2) {
                    // TODO: Checking if two types are equal is a really common pattern used in typechecking. Consider making a function for this.
                    std.log.err("{}: Cannot use types {s} and {s} together in {s} operation", .{ e.src_loc, t1.getHumanName(), t2.getHumanName(), e.kind.getHumanName() });
                    return error.InvalidTypeCombination;
                }
                try self.type_stack.append(.Bool);
            },
            .Not => {
                try self.expectMinimumElements(e, 1);
                _ = try self.expectType(e, .{.Bool});
                try self.type_stack.append(.Bool);
            },
            .And, .Or => {
                try self.expectMinimumElements(e, 2);
                _ = try self.expectType(e, .{.Bool});
                _ = try self.expectType(e, .{.Bool});
                try self.type_stack.append(.Bool);
            },
            .Drop => {
                try self.expectMinimumElements(e, 1);
                _ = self.type_stack.pop();
            },
            .Dup => {
                try self.expectMinimumElements(e, 1);
                const t = self.type_stack.pop();
                try self.type_stack.append(t);
                try self.type_stack.append(t);
            },
            .Over => {
                try self.expectMinimumElements(e, 2);
                const t2 = self.type_stack.pop();
                const t1 = self.type_stack.pop();
                try self.type_stack.append(t1);
                try self.type_stack.append(t2);
                try self.type_stack.append(t1);
            },
            .Swap => {
                try self.expectMinimumElements(e, 2);
                const t2 = self.type_stack.pop();
                const t1 = self.type_stack.pop();
                try self.type_stack.append(t2);
                try self.type_stack.append(t1);
            },
            .Rot => {
                try self.expectMinimumElements(e, 3);
                const t3 = self.type_stack.pop();
                const t2 = self.type_stack.pop();
                const t1 = self.type_stack.pop();
                try self.type_stack.append(t2);
                try self.type_stack.append(t3);
                try self.type_stack.append(t1);
            },
            .Print => {
                try self.expectMinimumElements(e, 1);
                _ = try self.expectType(e, .{.Integer});
            },
            .If => |stmt| {
                try self.expectMinimumElements(e, 1);
                _ = try self.expectType(e, .{.Bool});

                // Ensure that all possible paths affect the stack in the same way for type safety reasons
                var state = try self.type_stack.clone();
                defer state.deinit();

                for (stmt.main_body) |se| {
                    try self.checkExpr(se);
                }

                // Get assumed type signature
                var type_signature = try self.type_stack.clone();
                defer type_signature.deinit();

                if (stmt.else_body) |else_body| {
                    // Reset type stack to test alternate paths
                    self.type_stack = state;

                    for (else_body) |se| {
                        try self.checkExpr(se);
                    }

                    // Compare type stack to type signature
                    if (!mem.eql(ValueTag, self.type_stack.items, type_signature.items)) {
                        std.log.err("{}: Code paths return different values", .{e.src_loc});
                        return error.UnequalSignatures;
                    }
                }
            },
            .While => |body| {
                try self.expectMinimumElements(e, 1);

                var state = try self.type_stack.clone();
                defer state.deinit();

                _ = try self.expectType(e, .{.Bool});

                for (body) |se| {
                    try self.checkExpr(se);
                }

                // Ensure while loop does not modify the type stack on completion
                if (!mem.eql(ValueTag, self.type_stack.items, state.items)) {
                    std.log.err("{}: While expression modifies stack on completion", .{e.src_loc});
                    return error.ModifiedTypeStack; // Weird error name
                }

                _ = self.type_stack.pop(); // Conditional will always be popped of the stack
            },
        }
    }
};
