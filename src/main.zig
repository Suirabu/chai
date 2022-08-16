const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;

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

    // Lex debug program
    const program =
        \\ 5 10
    ;
    const program_path = "test.chai"; // Fake name for debugging purposes

    var lexer = Lexer.initFromSource(program, program_path, arena.allocator());

    // Debug: Display lexer results
    for (try lexer.collectTokens()) |tok| {
        std.debug.print("{}\n", .{tok});
    }
}
