const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

//--------------------------------------------------------------------------------------------------
pub fn part1() anyerror!void {
    const file = std.fs.cwd().openFile("data/day08_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    std.log.info("File size {}", .{file_size});

    var reader = std.io.bufferedReader(file.reader());
    var istream = reader.reader();

    var buf: [128]u8 = undefined;
    var counts = [_]u16{0} ** 10;
    var codes: [14][]const u8 = undefined;

    while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var i: usize = 0;
        var it = std.mem.tokenize(u8, line, " |");
        while (it.next()) |value| : (i += 1) {
            codes[i] = value;
        }

        // Evaluate line
        i = 10;
        while (i < 14) : (i += 1) {
            const len = codes[i].len;
            if (len == 2) {
                counts[1] += 1;
            } else if (len == 4) {
                counts[4] += 1;
            } else if (len == 3) {
                counts[7] += 1;
            } else if (len == 7) {
                counts[8] += 1;
            }
        }
    }

    const part1_sum = counts[1] + counts[4] + counts[7] + counts[8];
    std.log.info("Part 1 sum: {d}", .{part1_sum});
}

//--------------------------------------------------------------------------------------------------
const MutableIterator = struct {
    buffer: []u8,
    delimiter_bytes: []const u8,
    index: usize = 0,
    const Self = @This();

    /// Returns a slice of the next token, or null if tokenization is complete.
    pub fn next(self: *Self) ?[]u8 {
        // move to beginning of token
        while (self.index < self.buffer.len and self.isSplitByte(self.buffer[self.index])) : (self.index += 1) {}
        const start = self.index;
        if (start == self.buffer.len) {
            return null;
        }

        // move to end of token
        while (self.index < self.buffer.len and !self.isSplitByte(self.buffer[self.index])) : (self.index += 1) {}
        const end = self.index;

        return self.buffer[start..end];
    }

    fn isSplitByte(self: Self, byte: u8) bool {
        for (self.delimiter_bytes) |delimiter_byte| {
            if (byte == delimiter_byte) {
                return true;
            }
        }
        return false;
    }
};

pub fn tokenize(buffer: []u8, delimiter_bytes: []const u8) MutableIterator {
    return .{
        .index = 0,
        .buffer = buffer,
        .delimiter_bytes = delimiter_bytes,
    };
}

//--------------------------------------------------------------------------------------------------
pub fn contains_all(input: []const u8, search_terms: []const u8) bool {
    if (input.len < search_terms.len) {
        return false;
    }
    for (search_terms) |term| {
        var found = false;
        for (input) |char| {
            if (char == term) {
                found = true;
                break;
            }
        }
        if (found == false) {
            return false;
        }
    }
    return true;
}
//--------------------------------------------------------------------------------------------------
pub fn create_decoder(input: *const [10][]const u8) [10][]const u8 {
    var map: [10][]const u8 = undefined;

    // First pass to get 1, 4, 7, 8 values
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        const len = input[i].len;
        if (len == 2) {
            map[1] = input[i]; // 1
        } else if (len == 4) {
            map[4] = input[i]; // 4
        } else if (len == 3) {
            map[7] = input[i]; // 7
        } else if (len == 7) {
            map[8] = input[i]; // 8
        }
    }

    // Second pass: find 3 and 6
    // 3 contains everything in 7. (2 and 5 do not)
    // 6 doesn't contain everything in 1. (0 and 9 do not)
    i = 0;
    while (i < 10) : (i += 1) {
        const len = input[i].len;
        if (len == 5) { // can be 2, 3 or 5
            if (contains_all(input[i], map[7])) {
                map[3] = input[i];
            }
        } else if (len == 6) { // can be 0, 9 or 6
            if (contains_all(input[i], map[1]) == false) {
                map[6] = input[i];
            }
        }
    }

    // Third pass: find 9 and 5
    // 6 contains everything in 5. (not 2)
    // 9 contains everything in 3. (0 does not)
    i = 0;
    while (i < 10) : (i += 1) {
        const len = input[i].len;
        if (len == 5 and !std.mem.eql(u8, input[i], map[3])) { // can be 2 or 5
            if (contains_all(map[6], input[i])) { // NB. reversed order here
                map[5] = input[i];
            } else {
                map[2] = input[i];
            }
        } else if (len == 6 and !std.mem.eql(u8, input[i], map[6])) { // can be 0 or 9
            if (contains_all(input[i], map[3])) {
                map[9] = input[i];
            } else {
                map[0] = input[i];
            }
        }
    }

    return map;
}

//--------------------------------------------------------------------------------------------------
pub fn decode(input: *const [4][]const u8, decoder: *const [10][]const u8) u32 {
    var digits: [4]u32 = undefined;

    for (input) |digit_to_decode, d| {
        digits[d] = for (decoder) |code, pos| {
            if (std.mem.eql(u8, code, digit_to_decode)) {
                break @intCast(u32, pos);
            }
        } else 0;
    }

    // Sum  digits
    var res: u32 = 0;
    res += (digits[0] * 1000);
    res += (digits[1] * 100);
    res += (digits[2] * 10);
    res += (digits[3] * 1);
    return res;
}

//--------------------------------------------------------------------------------------------------
pub fn part2() anyerror!void {
    const file = std.fs.cwd().openFile("data/day08_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    std.log.info("File size {}", .{file_size});

    var reader = std.io.bufferedReader(file.reader());
    var istream = reader.reader();

    var buf: [128]u8 = undefined;
    var codes: [14][]u8 = undefined;
    var sum: u32 = 0;

    while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var i: usize = 0;
        var it = tokenize(buf[0..line.len], " |");
        while (it.next()) |value| : (i += 1) {
            std.sort.sort(u8, value, {}, comptime std.sort.asc(u8));
            codes[i] = value;
            // std.log.info("{s}", .{value});
        }
        const decoder = create_decoder(codes[0..10]);
        sum += decode(codes[10..14], &decoder);
    }

    std.log.info("Part 2 sum: {d}", .{sum});
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    try part1();
    try part2();
}
//--------------------------------------------------------------------------------------------------
