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
    const KeywordsHashMap = std.StringHashMap(TokenKind);

    source: []const u8,
    cursor: usize,
    src_loc: SrcLoc,
    allocator: Allocator,
    keywords: KeywordsHashMap,

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
            // The `catch unreachable` here is a pretty nasty hack which assumes that allocation
            // will never fail. Idealy this hash map should be constructed at compile time without
            // an allocator for maximum efficiency and to avoid the risk of allocation failure.
            // TODO: Generate hashmap at compile time
            .keywords = getKeywordsHashMap(allocator) catch unreachable,
        };
    }

    fn getKeywordsHashMap(allocator: Allocator) !KeywordsHashMap {
        var map = KeywordsHashMap.init(allocator);

        try map.put("true", TokenKind{ .BooleanLiteral = true });
        try map.put("false", TokenKind{ .BooleanLiteral = false });

        try map.put("+", .Plus);
        try map.put("-", .Minus);
        try map.put("*", .Star);
        try map.put("/", .Slash);
        try map.put("%", .Perc);

        try map.put("drop", .Drop);
        try map.put("dup", .Dup);
        try map.put("over", .Over);
        try map.put("swap", .Swap);
        try map.put("rot", .Rot);

        return map;
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

    fn expect(self: *Self, expected: u8, expected_description: []const u8) !void {
        const src_loc = self.src_loc;

        if (self.reachedEnd()) {
            std.log.err("{}: Expected {s}, found end of file instead", .{ src_loc, expected_description });
            return error.ExpectedCharNotFound;
        }

        const found = self.peek();
        if (found != expected) {
            if (ascii.isGraph(found)) {
                std.log.err("{}: Expected {s}, found '{c}' instead", .{ src_loc, expected_description, found });
            } else {
                const found_description = switch (found) {
                    '\n' => "newline",
                    '\r' => "carriage return",
                    '\t' => "horizontal tab",
                    ' ' => "space",
                    // TODO: Replace with hex representation of character
                    else => "unexpected character",
                };
                std.log.err("{}: Expected {s}, found {s} instead", .{ src_loc, expected_description, found_description });
            }
            return error.ExpectedCharNotFound;
        }

        _ = self.advance();
    }

    fn atWordBoundary(self: Self) bool {
        if (ascii.isSpace(self.peek()) or self.peek() == '.') {
            return true;
        } else {
            return false;
        }
    }

    fn isValidIdentifier(maybe_identifier: []const u8) bool {
        if (!ascii.isAlpha(maybe_identifier[0])) {
            return false;
        }
        for (maybe_identifier) |c| {
            if (!ascii.isAlNum(c) and c != '-') {
                return false;
            }
        }

        return true;
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
        try self.expect('"', "opening double-quote");
        const start = self.cursor;

        while (!self.reachedEnd() and self.peek() != '"') {
            _ = self.advance();
        }

        const end = self.cursor;
        try self.expect('"', "closing double-quote");

        const lexemme = self.source[start..end];
        return Token{ .kind = TokenKind{ .StringLiteral = lexemme }, .src_loc = src_loc };
    }

    fn collectCharacterLiteral(self: *Self) !Token {
        const src_loc = self.src_loc;
        try self.expect('\'', "opening single-quote");

        if (self.reachedEnd()) {
            std.log.err("{}: Expected complete character literal, found end of file instead", .{self.src_loc});
            return error.LexerError;
        }

        const c = self.advance();
        if (c == '\'') {
            std.log.err("{}: Expected complete character literal", .{self.src_loc});
            return error.LexerError;
        }

        try self.expect('\'', "closing single-quote");

        return Token{ .kind = TokenKind{ .CharacterLiteral = c }, .src_loc = src_loc };
    }

    fn collectKeywordOrIdentifier(self: *Self) !Token {
        const src_loc = self.src_loc;
        const lexemme = self.collectWord();
        if (self.keywords.contains(lexemme)) {
            return Token{ .kind = self.keywords.get(lexemme).?, .src_loc = src_loc };
        }

        if (isValidIdentifier(lexemme)) {
            return Token{ .kind = TokenKind{ .Identifier = lexemme }, .src_loc = src_loc };
        } else {
            std.log.err("{}: Invalid identifier '{s}'", .{ src_loc, lexemme });
            return error.InvalidIdentifier;
        }
    }

    fn collectToken(self: *Self) !Token {
        const c = self.peek();

        if (ascii.isDigit(c)) {
            return self.collectNumberLiteral();
        } else if (self.peek() == '"') {
            return self.collectStringLiteral();
        } else if (self.peek() == '\'') {
            return self.collectCharacterLiteral();
        } else {
            return self.collectKeywordOrIdentifier();
        }
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
