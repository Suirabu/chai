const std = @import("std");
const File = std.fs.File;

const expr = @import("expr.zig");
const Expr = expr.Expr;
const ExprKind = expr.ExprKind;
const ExprKindTag = expr.ExprKindTag;
const Value = expr.Value;
const ValueTag = expr.ValueTag;

pub const CodeGenerator = struct {
    const Self = @This();

    /// This counter is used to assign a unique number to labels as needed
    counter: usize,
    exprs: []Expr,
    out_file: File,

    pub fn init(exprs: []Expr, out_file: File) Self {
        return Self{
            .counter = 0,
            .exprs = exprs,
            .out_file = out_file,
        };
    }

    pub fn incrementCounter(self: *Self) usize {
        const val = self.counter;
        self.counter += 1;
        return val;
    }

    pub fn generate_x86_64_intel_linux(self: *Self) !void {
        var writer = self.out_file.writer();

        // Generate preamble
        try writer.print(
            \\;; Generated by the Chai compiler <https://github.com/Suirabu/chai>
            \\section .text
            \\global _start
            \\
            \\print:
            \\    mov r9, -3689348814741910323
            \\    sub rsp, 40
            \\    mov BYTE [rsp+31], 10
            \\    lea rcx, [rsp+30]
            \\
            \\.print_L2:
            \\    mov rax, rdi
            \\    lea r8, [rsp+32]
            \\    mul r9
            \\    mov rax, rdi
            \\    sub r8, rcx
            \\    shr rdx, 3
            \\    lea rsi, [rdx+rdx*4]
            \\    add rsi, rsi
            \\    sub rax, rsi
            \\    add eax, 48
            \\    mov BYTE [rcx], al
            \\    mov rax, rdi
            \\    mov rdi, rdx
            \\    mov rdx, rcx
            \\    sub rcx, 1
            \\    cmp rax, 9
            \\    ja  .print_L2
            \\    lea rax, [rsp+32]
            \\    mov edi, 1
            \\    sub rdx, rax
            \\    xor eax, eax
            \\    lea rsi, [rsp+32+rdx]
            \\    mov rdx, r8
            \\    mov rax, 1
            \\    syscall
            \\
            \\    add rsp, 40
            \\    ret
            \\
            \\_start:
            \\
        , .{});

        for (self.exprs) |e| {
            try self.write_instruction_x86_64_intel_linux(e, writer);
        }

        // Generate post-amble
        try writer.print(
            \\    ;; Exit program with exit code 0
            \\    mov rax, 60
            \\    mov rdi, 0
            \\    syscall
            \\
        , .{});
    }

    pub fn write_instruction_x86_64_intel_linux(self: *Self, e: Expr, writer: anytype) !void {
        try writer.print("    ;; {s}\n", .{e.kind});

        switch (e.kind) {
            .Push => |value| {
                const tag: ValueTag = value;
                switch (tag) {
                    .Integer => {
                        try writer.print(
                            \\    mov rax, {d}
                            \\    push rax
                            \\
                        , .{value});
                    },
                    .Bool => {
                        // I don't understand how if expressions work :'(
                        var numValue: usize = undefined;
                        if (value.Bool) {
                            numValue = 1;
                        } else {
                            numValue = 0;
                        }

                        try writer.print(
                            \\    mov rax, {d}
                            \\    push rax
                            \\
                        , .{numValue});
                    },
                    else => {
                        std.log.err("{}: Codegen for {} expression is unimplemented", .{ e.src_loc, e.kind });
                        return error.Unimplemented;
                    },
                }
            },
            .Plus => {
                try writer.print(
                    \\    pop rbx
                    \\    pop rax
                    \\    add rax, rbx
                    \\    push rax
                    \\
                , .{});
            },
            .Minus => {
                try writer.print(
                    \\    pop rbx
                    \\    pop rax
                    \\    sub rax, rbx
                    \\    push rax
                    \\
                , .{});
            },
            .Multiply => {
                try writer.print(
                    \\    pop rbx
                    \\    pop rax
                    \\    mul rbx
                    \\    push rax
                    \\
                , .{});
            },
            .Divide => {
                try writer.print(
                    \\    pop rbx
                    \\    pop rax
                    \\    div rbx
                    \\    push rax
                    \\
                , .{});
            },
            .Mod => {
                try writer.print(
                    \\    mov rdx, 0
                    \\    pop rbx
                    \\    pop rax
                    \\    div rbx
                    \\    push rdx
                    \\
                , .{});
            },
            .Neg => {
                try writer.print(
                    \\    pop rax
                    \\    neg rax
                    \\    push rax
                    \\
                , .{});
            },

            .Drop => {
                try writer.print(
                    \\    pop rax
                    \\
                , .{});
            },
            .Dup => {
                try writer.print(
                    \\    pop rax
                    \\    push rax
                    \\    push rax
                    \\
                , .{});
            },
            .Over => {
                try writer.print(
                    \\    pop rbx
                    \\    pop rax
                    \\    push rax
                    \\    push rbx
                    \\    push rax
                    \\
                , .{});
            },
            .Swap => {
                try writer.print(
                    \\    pop rbx
                    \\    pop rax
                    \\    push rbx
                    \\    push rax
                    \\
                , .{});
            },
            .Rot => {
                try writer.print(
                    \\    pop rcx
                    \\    pop rbx
                    \\    pop rax
                    \\    push rbx
                    \\    push rcx
                    \\    push rax
                    \\
                , .{});
            },

            .Print => {
                try writer.print(
                    \\    pop rdi
                    \\    call print
                    \\
                , .{});
            },

            .If => |exprs| {
                const label_value = self.incrementCounter();

                try writer.print(
                    \\    pop rax
                    \\    cmp rax, 0
                    \\    je .if_{d}
                    \\
                , .{label_value});

                for (exprs) |se| {
                    try self.write_instruction_x86_64_intel_linux(se, writer);
                }

                try writer.print(
                    \\.if_{d}:
                    \\
                , .{label_value});
            },
        }
    }
};
