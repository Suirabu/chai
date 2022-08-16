const std = @import("std");
const ascii = std.ascii;
const mem = std.mem;
const Allocator = mem.Allocator;

const token = @import("token.zig");
const TokenKindTag = token.TokenKindTag;
const TokenKind = token.TokenKind;
const Token = token.Token;
const SrcLoc = token.SrcLoc;

pub const Lexer = struct {
    const Self = @This();
    const TokenArrayList = std.ArrayList(Token);

    source: []const u8,
    cursor: usize,
    src_loc: SrcLoc,
    allocator: Allocator,

    pub fn initFromSource(source: []const u8, source_path: []const u8, allocator: Allocator) Self {
        return Self{
            .source = source,
            .cursor = 0,
            .src_loc = SrcLoc{
                .line = 0,
                .column = 0,
                .path = source_path,
            },
            .allocator = allocator,
        };
    }

    fn reachedEnd(self: *Self) bool {
        return self.cursor >= self.source.len;
    }

    /// Returns a character from `source` at the curent position of the cursor.
    /// Assumes that `cursor` is not greater than `source.len`.
    fn peek(self: *Self) u8 {
        return self.source[self.cursor];
    }

    /// Returns a character from `source` at the curent position of the cursor, subsequently
    /// incrementing `cursor` and updating the `line` and `column` fields as needed.
    /// Assumes that `cursor` is not greater than `source.len`.
    fn advance(self: *Self) u8 {
        const c = self.peek();
        self.cursor += 1;

        if (c == '\n') {
            self.src_loc.line += 1;
            self.src_loc.column = 0;
        } else {
            self.src_loc.column += 1;
        }

        return c;
    }

    fn skipWhitespace(self: *Self) void {
        while (!self.reachedEnd() and ascii.isSpace(self.peek())) {
            _ = self.advance();
        }
    }

    fn collectWord(self: *Self) []const u8 {
        const start = self.cursor;

        while (!self.reachedEnd() and !ascii.isSpace(self.peek())) {
            _ = self.advance();
        }

        const end = self.cursor;
        return self.source[start..end];
    }

    fn collectIntegerLiteral(self: *Self) !Token {
        const src_loc = self.src_loc;
        const lexemme = self.collectWord();
        const int_result = std.fmt.parseInt(isize, lexemme, 0) catch |err| {
            std.log.err("{}: Failed to parse '{s}' as an integer literal", .{ src_loc, lexemme });
            return err;
        };

        return Token{ .kind = TokenKind{ .IntegerLiteral = int_result }, .src_loc = src_loc };
    }

    fn collectToken(self: *Self) !Token {
        const src_loc = self.src_loc;
        const c = self.peek();

        if (ascii.isDigit(c)) {
            return self.collectIntegerLiteral();
        }

        std.log.err("{}: Lexing non-integer literals is not yet supported", .{src_loc});
        unreachable;
    }

    pub fn collectTokens(self: *Self) ![]Token {
        var tokens = TokenArrayList.init(self.allocator);
        var has_error = false;

        while (!self.reachedEnd()) {
            self.skipWhitespace(); // Advance to beginning of next token
            if (self.reachedEnd()) {
                break;
            }

            if (self.collectToken()) |tok| {
                try tokens.append(tok);
            } else |_| {
                has_error = true;
            }
        }

        if (has_error) {
            return error.LexerError;
        } else {
            return tokens.items;
        }
    }
};
