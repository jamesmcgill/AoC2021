const std = @import("std");

//--------------------------------------------------------------------------------------------------
pub fn is_winning_board(board: [5][5]?u32) bool {
    // Check if entire row is cleared
    for (board) |row, row_idx| {
        var is_row_empty = true;
        for (row) |cell| {
            if (cell != null) {
                is_row_empty = false;
                break;
            }
        }
        if (is_row_empty) {
            return true;
        }
    }

    // Check if entire column is cleared
    var col_idx: u32 = 0;
    while (col_idx < 5) : (col_idx += 1) {
        var is_column_empty = true;
        var row_idx: u32 = 0;
        while (row_idx < 5) : (row_idx += 1) {
            var cell = board[row_idx][col_idx];
            if (cell != null) {
                is_column_empty = false;
                break;
            }
        }
        if (is_column_empty) {
            return true;
        }
    }

    return false;
}

//--------------------------------------------------------------------------------------------------
pub fn unpack_board(input: [25]?u32) [5][5]?u32 {
    var res: [5][5]?u32 = undefined;

    var i: u32 = 0;
    while (i < 25) : (i += 1) {
        res[i / 5][i % 5] = input[i];
    }
    return res;
}

//--------------------------------------------------------------------------------------------------
pub fn remaining_sum(input: [25]?u32) u32 {
    var res: u32 = 0;
    var i: u32 = 0;
    while (i < 25) : (i += 1) {
        res += input[i] orelse 0;
    }
    return res;
}

//--------------------------------------------------------------------------------------------------
pub fn is_already_won(board_idx: usize, winners: []usize) bool {
    for (winners) |idx| {
        if (idx == board_idx) {
            return true;
        }
    }
    return false;
}

//--------------------------------------------------------------------------------------------------
pub fn part1() anyerror!void {
    const file = std.fs.cwd().openFile("data/day04_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    std.log.info("File size {}", .{file_size});

    var reader = std.io.bufferedReader(file.reader());
    var istream = reader.reader();

    var buf: [1024]u8 = undefined;
    var counts = [_]u32{0} ** 12;
    var line_count: u32 = 0;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var input = std.ArrayList(u32).init(allocator);
    defer input.deinit();

    //var card = std.ArrayList(?u32).init(allocator);
    //defer card.deinit();

    var cards = std.ArrayList([25]?u32).init(allocator);
    defer cards.deinit();

    var cur_values = [_]?u32{0} ** 25;
    var cur_values_idx: u32 = 0;

    while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        //std.log.info("{s}", .{line});

        // Store the input from the first line in input
        if (line_count == 0) {
            var it = std.mem.tokenize(line, ", ");
            while (it.next()) |value| {
                input.append(std.fmt.parseInt(u32, value, 10) catch 0) catch unreachable;
                //std.log.info("Value {d}", .{current_val});
            }
            std.log.info("ArrayList size {}", .{input.items.len});
        } else if (line.len > 0) {
            var it = std.mem.tokenize(line, " ");
            while (it.next()) |value| {
                cur_values[cur_values_idx] = std.fmt.parseInt(u32, value, 10) catch 0;
                cur_values_idx += 1;
                if (cur_values_idx >= 25) {
                    cur_values_idx = 0;
                    try cards.append(cur_values);
                }
                //std.log.info("Value {d}", .{current_val});
            }
        }

        line_count += 1;
    }
    //std.log.info("Cards {d}", .{cards.items});
    //std.log.info("Cards size {}", .{cards.items.len});

    var winners = std.ArrayList(usize).init(allocator);
    defer winners.deinit();

    for (input.items) |check_val| {
        //std.log.info("Check {d}", .{check_val});
        for (cards.items) |*card, card_idx| {
            if (is_already_won(card_idx, winners.items)) {
                continue;
            }
            for (card.*) |*val| {
                if (check_val == val.* orelse null) {
                    val.* = null;
                    // Check if we are a winner
                    if (is_winning_board(unpack_board(card.*))) {
                        try winners.append(card_idx);
                        //if (num_winners = 1) {
                        var sum: u32 = remaining_sum(card.*);
                        std.log.info("Part 1: winning board idx={d}, last_number={d}, sum={d}, answer={d}", .{ card_idx, check_val, sum, check_val * sum });
                        //}
                    }
                }
            }
        }
    }

    // std.log.info("Part 1 counts={d}, gamma_rate={b}, epsilon_rate={b}, answer={d}", .{ counts, gamma_rate, epsilon_rate, gamma_rate * @as(u32, epsilon_rate) });
}

//--------------------------------------------------------------------------------------------------
pub fn copy_array(input: [12]u8) [12]u8 {
    var res = [_]u8{0} ** 12;

    var i: u32 = 0;
    while (i < 12) : (i += 1) {
        res[i] = input[i];
    }
    return res;
}

//--------------------------------------------------------------------------------------------------
pub fn eq_array(lhs: [12]u8, rhs: [12]u8, limit: u32) bool {
    var i: u32 = 0;
    while (i < 12 and i < limit) : (i += 1) {
        if (lhs[i] != rhs[i]) {
            return false;
        }
    }
    return true;
}

//--------------------------------------------------------------------------------------------------
pub fn array_to_int(input: [12]u8) u32 {
    var res: u32 = 0;

    var i: u32 = 0;
    while (i < 12) : (i += 1) {
        if (input[i] == '1') {
            res |= (@as(u32, 1) << @truncate(u4, 11 - i));
        }
    }
    return res;
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    try part1();
    //try part2();
}
//--------------------------------------------------------------------------------------------------
