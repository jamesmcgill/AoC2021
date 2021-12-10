const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

//--------------------------------------------------------------------------------------------------
pub fn illegal_char_points(char: u8) u32 {
    return switch (char) {
        ')' => 3,
        ']' => 57,
        '}' => 1197,
        '>' => 25137,
        else => 0,
    };
}

//--------------------------------------------------------------------------------------------------
pub fn completion_points(char: u8) u32 {
    return switch (char) {
        ')' => 1,
        ']' => 2,
        '}' => 3,
        '>' => 4,
        else => 0,
    };
}

//--------------------------------------------------------------------------------------------------
pub fn matching_opening(char: u8) u8 {
    return switch (char) {
        ')' => '(',
        ']' => '[',
        '}' => '{',
        '>' => '<',
        else => '!',
    };
}

//--------------------------------------------------------------------------------------------------
pub fn matching_closing(char: u8) u8 {
    return switch (char) {
        '(' => ')',
        '[' => ']',
        '{' => '}',
        '<' => '>',
        else => '!',
    };
}

//--------------------------------------------------------------------------------------------------
pub fn part1() anyerror!void {
    const file = std.fs.cwd().openFile("data/day10_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var completion_scores = ArrayList(u64).init(&arena.allocator);
    completion_scores.deinit();

    var num_error: u32 = 0;
    var num_incomplete: u32 = 0;

    var error_score: u32 = 0;
    {
        var reader = std.io.bufferedReader(file.reader());
        var istream = reader.reader();
        var buf: [128]u8 = undefined;

        var stack = ArrayList(u8).init(&arena.allocator);
        stack.deinit();

        while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            for (line) |char| {
                const is_opening = (char == '{') or (char == '[') or (char == '<') or (char == '(');
                if (is_opening) {
                    try stack.append(char);
                } else {
                    const len = stack.items.len;
                    if (len == 0 or (matching_opening(char) != stack.items[len - 1])) {
                        error_score += illegal_char_points(char);
                        num_error += 1;
                        break;
                    } else {
                        _ = stack.popOrNull();
                    }
                }

                // reached until eol without corruption
            } else {
                if (stack.items.len != 0) { // incomplete
                    num_incomplete += 1;

                    var score: u64 = 0;
                    while (stack.popOrNull()) |opening| {
                        score *= 5;
                        score += completion_points(matching_closing(opening));
                    }
                    try completion_scores.append(score);
                }
            } // for char
            stack.clearRetainingCapacity(); // line finished
        } //while line

    }

    std.sort.sort(u64, completion_scores.items, {}, comptime std.sort.asc(u64));
    const part2_final = completion_scores.items[completion_scores.items.len / 2];

    std.log.info("Part 1 score: {d}", .{error_score});
    std.log.info("Part 2 score: {d}", .{part2_final});
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    try part1();
}

//--------------------------------------------------------------------------------------------------
