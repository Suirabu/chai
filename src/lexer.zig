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

    fn reachedEnd(self: Self) bool {
        return self.cursor >= self.source.len;
    }

    /// Returns a character from `source` at the curent position of the cursor.
    /// Assumes that `cursor` is not greater than `source.len`.
    fn peek(self: Self) u8 {
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

    fn atWordBoundary(self: Self) bool {
        if (ascii.isSpace(self.peek()) or self.peek() == '.') {
            return true;
        } else {
            return false;
        }
    }

    fn skipWhitespace(self: *Self) void {
        while (!self.reachedEnd() and ascii.isSpace(self.peek())) {
            _ = self.advance();
        }
    }

    fn collectWord(self: *Self) []const u8 {
        const start = self.cursor;

        while (!self.reachedEnd() and !self.atWordBoundary()) {
            _ = self.advance();
        }

        const end = self.cursor;
        return self.source[start..end];
    }

    fn collectNumberLiteral(self: *Self) !Token {
        const src_loc = self.src_loc;
        const start = self.cursor; // Used for collecting float literals
        var lexemme = self.collectWord();

        if (!self.reachedEnd() and self.peek() == '.') {
            // Collect float literal
            _ = self.advance(); // Skip period

            if (self.reachedEnd()) {
                std.log.err("{}: Float literal cannot end with a trailing period. Try adding a '0' to the end instead?", .{src_loc});
                return error.LexerError;
            }
            _ = self.collectWord(); // Skip decimal

            const end = self.cursor;
            lexemme = self.source[start..end];

            const float_result = std.fmt.parseFloat(f64, lexemme) catch |err| {
                std.log.err("{}: Failed to parse '{s}' as a float literal", .{ src_loc, lexemme });
                return err;
            };
            return Token{ .kind = TokenKind{ .FloatLiteral = float_result }, .src_loc = src_loc };
        } else {
            // Collect integer literal
            const int_result = std.fmt.parseInt(isize, lexemme, 0) catch |err| {
                std.log.err("{}: Failed to parse '{s}' as an integer literal", .{ src_loc, lexemme });
                return err;
            };
            return Token{ .kind = TokenKind{ .IntegerLiteral = int_result }, .src_loc = src_loc };
        }
    }

    fn collectStringLiteral(self: *Self) !Token {
        const src_loc = self.src_loc;

        _ = self.advance(); // Skip leading double-quote

        const start = self.cursor;

        while (!self.reachedEnd() and self.peek() != '"') {
            _ = self.advance();
        }

        const end = self.cursor;

        if (self.reachedEnd()) {
            std.log.err("{}: Expected closing double-quote, found end of file instead", .{self.src_loc});
            return error.LexerError;
        }

        _ = self.advance(); // Skip trailing double-quote

        const lexemme = self.source[start..end];
        return Token{ .kind = TokenKind{ .StringLiteral = lexemme }, .src_loc = src_loc };
    }

    fn collectCharacterLiteral(self: *Self) !Token {
        const src_loc = self.src_loc;
        _ = self.advance();

        if (self.reachedEnd()) {
            std.log.err("{}: Expected complete character literal, found end of file instead", .{self.src_loc});
            return error.LexerError;
        }

        const c = self.advance();
        if (c == '\'') {
            std.log.err("{}: Expected complete character literal", .{self.src_loc});
            return error.LexerError;
        }

        if (self.reachedEnd()) {
            std.log.err("{}: Expected closing single-quote, found end of file instead", .{self.src_loc});
            return error.LexerError;
        }
        const closing = self.advance();
        if (closing != '\'') {
            std.log.err("{}: Expected closing single-quote, found '{c}' instead", .{ self.src_loc, closing });
            return error.LexerError;
        }

        return Token{ .kind = TokenKind{ .CharacterLiteral = c }, .src_loc = src_loc };
    }

    fn collectToken(self: *Self) !Token {
        const src_loc = self.src_loc;
        const c = self.peek();

        if (ascii.isDigit(c)) {
            return self.collectNumberLiteral();
        } else if (self.peek() == '"') {
            return self.collectStringLiteral();
        } else if (self.peek() == '\'') {
            return self.collectCharacterLiteral();
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
