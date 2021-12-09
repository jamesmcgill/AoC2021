const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

//--------------------------------------------------------------------------------------------------
pub fn part1() anyerror!void {
    const file = std.fs.cwd().openFile("data/day09_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var istream = reader.reader();

    var buf: [100]u8 = undefined;
    var heightmap: [100][100]u8 = undefined;
    {
        var row: usize = 0;
        while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (row += 1) {
            for (line) |char, col| {
                heightmap[row][col] = std.fmt.parseInt(u8, buf[col .. col + 1], 10) catch 0;
                //std.log.info("[{d}][{d}] = {d}", .{ row, col, heightmap[row][col] });
            }
        }
    }

    var sum: u32 = 0;
    for (heightmap) |row, i| {
        var decreasing = true;

        for (row) |entry, j| {
            const is_last = (j == row.len - 1);
            const will_increase = if (is_last) true else (row[j + 1] > entry);
            const will_decrease = if (is_last) false else (row[j + 1] < entry); // NB. notice this isn't exactly !will_increase as that would include equals

            // setup next loop iteration, keep previous values for logic below
            const was_decreasing = decreasing;
            decreasing = will_decrease;

            if (was_decreasing and will_increase) {
                // At this point the previous value is a minimum in Left and Right direction

                // Check Up. If up exists and it's lower, then we are not the min
                if ((i > 0) and (heightmap[i - 1][j] < entry)) {
                    continue;
                }
                // Check Down. If down exists and it's lower, then we are not the min
                if ((i < heightmap.len - 1) and (heightmap[i + 1][j] < entry)) {
                    continue;
                }
                // If we reached here we are really the minimum
                sum += (entry + 1);
            }
        }
    }

    std.log.info("Part 1 sum: {d}", .{sum});
}

//--------------------------------------------------------------------------------------------------
pub fn flood_fill(heightmap: *[100][100]u16, marker: u16, row: usize, col: usize) void {
    if (heightmap[row][col] == marker) {
        return;
    }
    if (heightmap[row][col] == 9) {
        return;
    }
    heightmap[row][col] = marker;

    if (col < 98) {
        flood_fill(heightmap, marker, row, col + 1);
    }
    if (col > 0) {
        flood_fill(heightmap, marker, row, col - 1);
    }
    if (row < 98) {
        flood_fill(heightmap, marker, row + 1, col);
    }
    if (row > 0) {
        flood_fill(heightmap, marker, row - 1, col);
    }
}
//--------------------------------------------------------------------------------------------------
pub fn part2() anyerror!void {
    const file = std.fs.cwd().openFile("data/day09_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var istream = reader.reader();

    var buf: [100]u8 = undefined;
    var heightmap: [100][100]u16 = undefined;
    {
        var row: usize = 0;
        while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (row += 1) {
            for (line) |char, col| {
                heightmap[row][col] = std.fmt.parseInt(u8, buf[col .. col + 1], 10) catch 0;
            }
        }
    }

    // Mark out basins
    var marker: u16 = 10; // mark starting from 10
    {
        var i: usize = 0;
        while (i < heightmap.len) : (i += 1) {
            var j: usize = 0;
            while (j < heightmap[i].len) : (j += 1) {
                if (heightmap[i][j] >= 9) {
                    continue;
                }
                flood_fill(&heightmap, marker, i, j);
                marker += 1;
            }
        }
    }

    // Count basin sizes
    const marker_end = marker;
    marker = 10; // restart marker starting from 10
    var counts = [_]u32{0} ** 3;

    // TODO: hashmap would have been much better here
    while (marker < marker_end) : (marker += 1) {
        var count: u32 = 0;
        for (heightmap) |row, i| {
            for (row) |entry, j| {
                if (entry == marker) {
                    count += 1;
                }
            }
        }
        // place the count into the array, if it is a new maximum
        if (count > counts[0]) {
            // shift right
            counts[2] = counts[1];
            counts[1] = counts[0];
            counts[0] = count;
        } else if (count > counts[1]) {
            counts[2] = counts[1];
            counts[1] = count;
        } else if (count > counts[2]) {
            counts[2] = count;
        }
    }

    // for (heightmap) |row, i| {
    //     std.log.info("{d}", .{row});
    // }
    std.log.info("Part 2 sum: {d}", .{counts[0] * counts[1] * counts[2]});
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    try part1();
    try part2();
}
//--------------------------------------------------------------------------------------------------
