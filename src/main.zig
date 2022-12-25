const std = @import("std");
const fs = std.fs;

const parse_args = @import("args.zig").parse_args;
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const TypeChecker = @import("typecheck.zig").TypeChecker;
const CodeGenerator = @import("codegen.zig").CodeGenerator;

const log_level: std.log.Level = .debug;

pub fn main() !void {
    // Initialize allocators
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked) {
            _ = gpa.detectLeaks();
        }
    }
    var allocator = gpa.allocator();

    // Collect command line arguments
    var args = try std.process.argsWithAllocator(allocator);
    const opts = try parse_args(args);
    const source_path = opts.source_path orelse {
        std.log.err("No source path provied", .{});
        return error.MissingSourcePath;
    };

    if (!std.mem.endsWith(u8, source_path, ".chai")) {
        std.log.err("Source file must use '.chai' file extension", .{});
        return error.InvalidFileExtension;
    }

    const source_file = fs.cwd().openFile(source_path, .{}) catch |err| {
        std.log.err("Failed to open file '{s}' for reading", .{source_path});
        return err;
    };
    defer source_file.close();
    const source = try source_file.readToEndAlloc(allocator, 1 << 32);
    defer allocator.free(source);

    var lexer = Lexer.initFromSource(source, source_path, allocator);
    defer lexer.deinit();
    const tokens = try lexer.collectTokens();
    defer allocator.free(tokens);

    var parser = Parser.init(allocator, tokens);
    const exprs = try parser.collectExprs();
    defer {
        for (exprs) |*expr| {
            expr.deinit(allocator);
        }
        allocator.free(exprs);
    }

    var type_checker = TypeChecker.init(exprs, allocator);
    try type_checker.check_program();

    // Code generation
    {
        var out_file = try fs.cwd().createFile(".chai_out.asm", .{});
        defer out_file.close();

        var code_generator = CodeGenerator.init(exprs, out_file);
        try code_generator.generate_x86_64_intel_linux();
    }

    _ = try std.ChildProcess.exec(.{ .allocator = allocator, .argv = &.{ "yasm", "-f", "elf64", ".chai_out.asm", "-o", ".chai_out.o" } });
    defer {
        fs.cwd().deleteFile(".chai_out.o") catch unreachable;
    }
    const executable_name = opts.output_path orelse source_path[0 .. source_path.len - 5];
    _ = try std.ChildProcess.exec(.{ .allocator = allocator, .argv = &.{ "ld", ".chai_out.o", "-o", executable_name } });
}
