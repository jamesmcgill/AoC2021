const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

//--------------------------------------------------------------------------------------------------
pub fn print(grid: [10][10]u8) void {
    for (grid) |row| {
        std.log.info("{d}", .{row});
    }
    std.log.info("--------------------------------", .{});
}

//--------------------------------------------------------------------------------------------------
pub fn increment(grid: *[10][10]u8) void {
    for (grid) |*row| {
        for (row.*) |*item| {
            item.* += 1;
        }
    }
}

//--------------------------------------------------------------------------------------------------
pub fn increment_adjacent(grid: *[10][10]u8, x: usize, y: usize) bool {
    const start_x = if (x > 0) x - 1 else x;
    const start_y = if (y > 0) y - 1 else y;
    const end_x = if (x < 9) x + 1 else x;
    const end_y = if (y < 9) y + 1 else y;

    var new_flashes = false;
    var j: usize = start_y;
    while (j <= end_y) : (j += 1) {
        var i: usize = start_x;
        while (i <= end_x) : (i += 1) {
            if (grid[j][i] != 0) {
                grid[j][i] += 1;
                if (grid[j][i] > 9) {
                    new_flashes = true;
                }
            }
        }
    }
    return new_flashes;
}

//--------------------------------------------------------------------------------------------------
pub fn perform_flashes(grid: *[10][10]u8) void {
    var new_flashes = true;
    while (new_flashes) {
        new_flashes = false;
        for (grid) |*row, y| {
            for (row.*) |*item, x| {
                if (item.* > 9) {
                    item.* = 0;
                    if (increment_adjacent(grid, x, y)) {
                        new_flashes = true;
                    }
                }
            } // x
        } // y
    } // while (new_flashes)
}

//--------------------------------------------------------------------------------------------------
pub fn count_flashed(grid: [10][10]u8) u32 {
    var sum: u32 = 0;
    for (grid) |row| {
        for (row) |item| {
            if (item == 0) {
                sum += 1;
            }
        }
    }
    return sum;
}

//--------------------------------------------------------------------------------------------------
pub fn part1() anyerror!void {
    const file = std.fs.cwd().openFile("data/day11_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    var octopuses = [_][10]u8{.{0} ** 10} ** 10;
    {
        var reader = std.io.bufferedReader(file.reader());
        var istream = reader.reader();
        var buf: [10]u8 = undefined;

        var row: usize = 0;
        while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (row += 1) {
            for (line) |char, col| {
                _ = char;
                octopuses[row][col] = std.fmt.parseInt(u8, buf[col .. col + 1], 10) catch 9;
            }
        }
    }

    var flashes: u32 = 0;
    var step: u32 = 0;
    while (step < 100) : (step += 1) {
        increment(&octopuses);
        perform_flashes(&octopuses);
        flashes += count_flashed(octopuses);
    }
    std.log.info("steps: {d}", .{step});
    std.log.info("Part 1 flashes: {d}", .{flashes});
}

//--------------------------------------------------------------------------------------------------
pub fn part2() anyerror!void {
    const file = std.fs.cwd().openFile("data/day11_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    var octopuses = [_][10]u8{.{0} ** 10} ** 10;
    {
        var reader = std.io.bufferedReader(file.reader());
        var istream = reader.reader();
        var buf: [10]u8 = undefined;

        var row: usize = 0;
        while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (row += 1) {
            for (line) |char, col| {
                _ = char;
                octopuses[row][col] = std.fmt.parseInt(u8, buf[col .. col + 1], 10) catch 9;
            }
        }
    }

    var step: u32 = 0;
    while (true) : (step += 1) {
        increment(&octopuses);
        perform_flashes(&octopuses);
        const flashes: u32 = count_flashed(octopuses);
        if (flashes == (10 * 10)) {
            step += 1; // Continuation won't happen if we break
            break;
        }
    }
    print(octopuses);
    std.log.info("Part 2 steps: {d}", .{step});
}
//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    try part1();
    try part2();
}

//--------------------------------------------------------------------------------------------------
