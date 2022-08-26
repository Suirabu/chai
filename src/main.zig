const std = @import("std");
const fs = std.fs;

const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const TypeChecker = @import("typecheck.zig").TypeChecker;

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

    const source_file = fs.cwd().openFile(source_path, .{}) catch |err| {
        std.log.err("Failed to open file '{s}' for reading", .{source_path});
        return err;
    };
    const source = try source_file.readToEndAlloc(arena.allocator(), 1 << 32);

    var lexer = Lexer.initFromSource(source, source_path, arena.allocator());
    const tokens = try lexer.collectTokens();

    var parser = Parser.init(arena.allocator(), tokens);
    const exprs = try parser.collectExprs();

    // Debug: Display parser results
    for (exprs) |expr| {
        std.debug.print("{}\n", .{expr});
    }

    std.debug.print("Begin type checking...\n", .{});
    var type_checker = TypeChecker.init(exprs, arena.allocator());
    try type_checker.check();
}
