const std = @import("std");
const fs = std.fs;

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

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    // Collect command line arguments
    var args = try std.process.argsWithAllocator(arena.allocator());
    // Because we are only targetting POSIX systems for now we can be sure that
    // our arguments will contain at least one element, namely the path of
    // our executable, which we can safely ignore
    _ = args.skip();
    const source_path = args.next() orelse {
        std.log.err("Expected source path", .{});
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
    const source = try source_file.readToEndAlloc(arena.allocator(), 1 << 32);

    var lexer = Lexer.initFromSource(source, source_path, arena.allocator());
    const tokens = try lexer.collectTokens();

    var parser = Parser.init(arena.allocator(), tokens);
    const exprs = try parser.collectExprs();

    var type_checker = TypeChecker.init(exprs, arena.allocator());
    try type_checker.check();

    // Code generation
    {
        var out_file = try fs.cwd().createFile(".chai_out.asm", .{});
        defer out_file.close();

        var code_generator = CodeGenerator.init(exprs, out_file);
        try code_generator.generate_x86_64_intel_linux();
    }

    defer {
        fs.cwd().deleteFile(".chai_out.asm") catch unreachable;
    }
    _ = try std.ChildProcess.exec(.{ .allocator = arena.allocator(), .argv = &.{ "yasm", "-f", "elf64", ".chai_out.asm", "-o", ".chai_out.o" } });
    defer {
        fs.cwd().deleteFile(".chai_out.o") catch unreachable;
    }
    const executable_name = source_path[0 .. source_path.len - 5];
    _ = try std.ChildProcess.exec(.{ .allocator = arena.allocator(), .argv = &.{ "ld", ".chai_out.o", "-o", executable_name } });
}
