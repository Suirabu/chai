const std = @import("std");
const fs = std.fs;

const Lexer = @import("lexer.zig").Lexer;

const log_level: std.log.Level = .debug;

pub fn main() !void {
    // Collect command line arguments
    var args_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer args_allocator.deinit();
    var args = try std.process.argsWithAllocator(args_allocator.allocator());
    // Because we are only targetting POSIX systems for now we can be sure that
    // our arguments will contain at least one element, namely the path of
    // our executable, which we can safely ignore
    _ = args.skip();
    const source_path = args.next() orelse {
        std.log.err("Expected source path", .{});
        return error.MissingSourcePath;
    };

    var file_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer file_allocator.deinit();
    const source_file = fs.cwd().openFile(source_path, .{}) catch |err| {
        std.log.err("Failed to open file '{s}' for reading", .{source_path});
        return err;
    };
    const source = try source_file.readToEndAlloc(file_allocator.allocator(), 1 << 32);

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

    var lexer = Lexer.initFromSource(source, source_path, arena.allocator());
    const tokens = try lexer.collectTokens();

    // Debug: Display lexer results
    for (tokens) |tok| {
        std.debug.print("{}\n", .{tok});
    }
}
