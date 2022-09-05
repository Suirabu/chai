const std = @import("std");
const mem = std.mem;
const ArgIterator = std.process.ArgIterator;
const File = std.fs.File;

pub const ArgOptions = struct {
    source_path: ?[]const u8,
    output_path: ?[]const u8,
};

pub fn parse_args(_args: ArgIterator) !ArgOptions {
    // This is a hack to get around the Zig compiler incorrectly marking the _args parameter as const
    var args = _args;

    // Because we are only targetting POSIX systems for now we can be sure that
    // our arguments will contain at least one element, namely the path of
    // our executable, which we can safely ignore
    _ = args.skip();

    var opts = ArgOptions{
        .source_path = null,
        .output_path = null,
    };

    while (args.next()) |arg| {
        if (eql(arg, "-h") or eql(arg, "--help")) {
            var stdout = std.io.getStdOut();
            try display_help(stdout);
            std.process.exit(0);
        } else if (eql(arg, "-o") or eql(arg, "--output")) {
            opts.output_path = args.next() orelse {
                std.log.err("Expected output path after '{s}' flag", .{arg});
                return error.NoOutputPath;
            };
        } else if (opts.source_path == null) {
            opts.source_path = arg;
        } else {
            std.log.err("Unknown argument '{s}'", .{arg});
            return error.UnknownArgument;
        }
    }

    return opts;
}

fn display_usage(stream: File) !void {
    var writer = stream.writer();
    try writer.print(
        \\chai - Chai programming language compiler
        \\ 
        \\Usage:
        \\    chai [options] <input>
        \\
        \\Use `chai --help` to view all available options
        \\
    , .{});
}

fn display_help(stream: File) !void {
    var writer = stream.writer();
    try writer.print(
        \\chai - Chai programming language compiler
        \\ 
        \\Usage:
        \\    chai [options] <input>
        \\
        \\Options:
        \\    -h, --help            View listing of all available options
        \\    -o, --output <file>   Specify executable output path
        \\
    , .{});
}

fn eql(arg: []const u8, pattern: []const u8) bool {
    return mem.eql(u8, arg, pattern);
}
