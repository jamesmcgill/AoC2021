const std = @import("std");

//--------------------------------------------------------------------------------------------------
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Range = struct { first: u16, last: u16, value: u16 };
const Ranges = ArrayList(Range);
const MapType = [1000][1000]u16;

//--------------------------------------------------------------------------------------------------
pub fn insert_vertical(x: u16, y1: u16, y2: u16, map: *MapType) void {
    const min_y = std.math.min(y1, y2);
    const max_y = std.math.max(y1, y2);

    var idx: u16 = min_y;
    while (idx <= max_y) : (idx += 1) {
        map[x][idx] += 1;
    }
}

//--------------------------------------------------------------------------------------------------
pub fn insert_horizontal(y: u16, x1: u16, x2: u16, map: *MapType) void {
    const min_x = std.math.min(x1, x2);
    const max_x = std.math.max(x1, x2);

    var idx: u16 = min_x;
    while (idx <= max_x) : (idx += 1) {
        map[idx][y] += 1;
    }
}

//--------------------------------------------------------------------------------------------------
pub fn insert_diagonal(x1: u16, y1: u16, x2: u16, y2: u16, map: *MapType) void {
    const is_reversed = (x1 > x2);
    const min_x = if (is_reversed) x2 else x1;
    const max_x = if (is_reversed) x1 else x2;

    const y_start = if (is_reversed) y2 else y1;
    const y_finish = if (is_reversed) y1 else y2;
    const inc_y: i32 = if (y_start > y_finish) -1 else 1;

    var x: i32 = @as(i32, min_x);
    var y: i32 = @as(i32, y_start);
    while (x <= max_x) : ({
        x += 1;
        y += inc_y;
    }) {
        const i = @intCast(usize, x);
        const j = @intCast(usize, y);
        map[i][j] += 1;
    }
}

//--------------------------------------------------------------------------------------------------
pub fn count_overlaps(map: *MapType) u16 {
    var res: u16 = 0;
    var x: u16 = 0;
    while (x < 1000) : (x += 1) {
        var y: u16 = 0;
        while (y < 1000) : (y += 1) {
            if (map[x][y] > 1) {
                res += 1;
            }
        }
    }
    return res;
}

//--------------------------------------------------------------------------------------------------
pub fn part1() anyerror!void {
    const file = std.fs.cwd().openFile("data/day05_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    std.log.info("File size {}", .{file_size});

    var reader = std.io.bufferedReader(file.reader());
    var istream = reader.reader();

    var buf: [20]u8 = undefined;
    var line_count: u32 = 0;

    var values: [4]u16 = undefined;

    var map = [_][1000]u16{.{0} ** 1000} ** 1000;
    while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        //std.log.info("{s}", .{line});
        var it = std.mem.tokenize(u8, line, ", ->");
        var idx: u32 = 0;
        while (it.next()) |value| : ({
            idx += 1;
            idx = idx % 4;
        }) {
            values[idx] = std.fmt.parseInt(u16, value, 10) catch 0;
            //std.log.info("value: {d} : (idx:{d})", .{ values[idx], idx });
        }
        std.log.info("value: {d}", .{values});
        var x1: u16 = values[0];
        var y1: u16 = values[1];
        var x2: u16 = values[2];
        var y2: u16 = values[3];

        if (x1 == x2) {
            insert_vertical(x1, y1, y2, &map);
        } else if (y1 == y2) {
            insert_horizontal(y1, x1, x2, &map);
        } else {
            insert_diagonal(x1, y1, x2, y2, &map);
        }

        line_count += 1;
    }

    const overlaps = count_overlaps(&map);
    std.log.info("overlaps: {d}", .{overlaps});

    //std.log.info("map size: {d}", .{map.count()});
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    try part1();
}
//--------------------------------------------------------------------------------------------------
