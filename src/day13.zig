const std = @import("std");

//--------------------------------------------------------------------------------------------------
const Vec2 = struct {
    x: u16,
    y: u16,

    pub fn init(x: u16, y: u16) Vec2 {
        return Vec2{ .x = x, .y = y };
    }
};

//--------------------------------------------------------------------------------------------------
pub fn print(points: []Vec2) void {
    var x: u32 = std.math.maxInt(u32);
    var y: u32 = std.math.maxInt(u32);

    const row_len: u32 = 40; // TODO: could find the max x value
    for (points) |point| {
        // Avoid printing the duplicates
        if (point.x == x and point.y == y) {
            continue;
        }
        // Fill in empty cells between points
        if (x == std.math.maxInt(u32)) {
            x = 0;
            y = 0;
        }
        const y_diff = point.y - y;
        if (y_diff != 0) {
            // Complete remainder of row
            var i: usize = 0;
            while (i < (row_len - x)) : (i += 1) {
                std.debug.print(".", .{});
            }
            std.debug.print("\n", .{});

            // Draw complete rows
            i = 1; // +1 because we 'completed' the remainer of one row elsewhere
            while (i < y_diff) : (i += 1) {
                var j: usize = 0;
                while (j < row_len) : (j += 1) {
                    std.debug.print(".", .{});
                }
                std.debug.print("\n", .{});
            }

            // Pad last row until x
            i = 0;
            while (i < point.x) : (i += 1) {
                std.debug.print(".", .{});
            }
            //
        } else {
            // Pad row
            const x_diff = point.x - x;
            var i: usize = 1; // +1 because we want to leave space for the point itself
            while (i < x_diff) : (i += 1) {
                std.debug.print(".", .{});
            }
        }

        // Ready to draw the new point
        x = point.x;
        y = point.y;
        std.debug.print("#", .{});
    }

    std.debug.print("\n", .{});
}

//--------------------------------------------------------------------------------------------------
pub fn count_unique(points: []Vec2) u32 {
    var count: u32 = 0;
    var i: usize = 0;
    while (i < points.len) : (i += 1) {
        var j: usize = i + 1;
        const unique: bool = while (j < points.len) : (j += 1) {
            if (points[i].x == points[j].x and points[i].y == points[j].y) {
                break false;
            }
        } else true;

        if (unique) {
            count += 1;
        }
    }
    return count;
}

//--------------------------------------------------------------------------------------------------
pub fn sort_pred(comptime T: type) fn (void, T, T) bool {
    const impl = struct {
        fn inner(context: void, a: T, b: T) bool {
            _ = context;
            if (a.y == b.y) {
                return a.x < b.x;
            } else {
                return a.y < b.y;
            }
        }
    };

    return impl.inner;
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    const file = std.fs.cwd().openFile("data/day13_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    var points: [877]Vec2 = undefined;
    var point_count: usize = 0;
    var folds: [12]Vec2 = undefined;
    var fold_count: usize = 0;
    {
        var reader = std.io.bufferedReader(file.reader());
        var istream = reader.reader();
        var buf: [16]u8 = undefined;

        while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            if (line.len == 0) {
                continue;
            }
            const fold_prefix = "fold along ";
            const flen = fold_prefix.len;
            if (line.len > flen and std.mem.eql(u8, line[0..flen], fold_prefix)) {
                var x: u16 = 0;
                var y: u16 = 0;
                if (std.mem.eql(u8, line[flen .. flen + 1], "x")) {
                    x = std.fmt.parseInt(u16, line[flen + 2 ..], 10) catch unreachable;
                } else {
                    y = std.fmt.parseInt(u16, line[flen + 2 ..], 10) catch unreachable;
                }
                folds[fold_count] = Vec2.init(x, y);
                fold_count += 1;
            } else {
                var it = std.mem.tokenize(u8, line, ",");
                const x = std.fmt.parseInt(u16, it.next().?, 10) catch unreachable;
                const y = std.fmt.parseInt(u16, it.next().?, 10) catch unreachable;
                points[point_count] = Vec2.init(x, y);
                point_count += 1;
            }
        }
    }

    // Perform folds
    for (folds) |fold| {
        for (points) |*point| {
            if (fold.x != 0) {
                if (point.x > fold.x) {
                    point.x = fold.x - (point.x - fold.x);
                }
            } else {
                if (point.y > fold.y) {
                    point.y = fold.y - (point.y - fold.y);
                }
            }
        }
        const unique = count_unique(points[0..point_count]);
        std.log.info("Unique: {d}", .{unique});
    }

    std.sort.sort(Vec2, points[0..point_count], {}, comptime sort_pred(Vec2));
    print(points[0..point_count]);

    //std.log.info("points: {d}", .{points});
}

//--------------------------------------------------------------------------------------------------
