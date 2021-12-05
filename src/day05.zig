const std = @import("std");

//--------------------------------------------------------------------------------------------------
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Range = struct { first: u16, last: u16, value: u16 };
const Ranges = ArrayList(Range);
//const MapType = std.AutoHashMap(u16, Ranges);
const MapType = [1000][1000]u16;
//--------------------------------------------------------------------------------------------------
pub fn cleanup_map(map: *MapType) void {
    var it = map.iterator();
    while (it.next()) |entry| {
        entry.value_ptr.deinit();
    }
}
//--------------------------------------------------------------------------------------------------
pub fn merge_range(new: Range, existing_ranges: *Ranges) void {
    // Merge cases               |======| existing  (** new), (oo overlapping)
    // 1) starts before   |******|oo|===|  1->3
    // 2) starts match           |oo|===|  1->2
    // 3) starts after           |=|oo|=|  1->3

    //TODO: part after needs to recursively check for overlap
    // 4) starts before   |******|oooooo|****|  1->3
    // 5) starts match           |oooooo|****|  1->2
    // 6) starts after           |=|oooo|****|  1->3

    for (existing_ranges.items) |*existing| {
        const is_first_inside: bool = new.first >= existing.first and new.first <= existing.last;
        const is_last_inside: bool = new.last >= existing.first and new.last <= existing.last;
        const is_overlapping = is_first_inside or is_last_inside;
        if (is_overlapping) {
            const is_start_match = new.first == existing.first;
            const is_start_before = !is_first_inside and !is_start_match;
            const is_start_after = new.first > existing.first;

            // part before overlap
            if (is_start_before) {
                const pre_range = .{ .first = new.first, .last = existing.first - 1, .value = 1 };
            }
            // overlapping part
            const overlap_start = std.math.max(new.first, existing.first);
            const overlap_end = std.math.min(new.last, existing.last);
            const overlap_range = .{ .first = overlap_start, .last = overlap_end, .value = existing.value + 1 };
            if (is_start_after) {
                // Existing is BEFORE (and maybe AFTER) overlap
                // Truncate ending of existing one to fit new one after
                const old_last = existing.last;
                existing.last = new.first - 1;
            } else {
                // No existing range before overlap Delete it
                // Overlap will start from the beginning of the existing one
                // Simply insert the new overlap range and truncate the existing to afterward
                // TODO: maybe the existing range is gone??
                existing.first = new.last + 1;
            }
            // TODO: Second existing one needs deleted if new.last >= existing.last
        }
    }
}

//--------------------------------------------------------------------------------------------------
// pub fn insert_vertical(x: u16, y1: u16, y2: u16, map: *MapType, alloc: *Allocator) void {
//     const min_y = std.math.min(y1, y2);
//     const max_y = std.math.max(y1, y2);
//     const new_range = .{ .first = min_y, .last = max_y, .value = 1 };

//     // Check if we overlap with an existing range
//     if (map.getPtr(x)) |entry| {
//         merge_range(new_range, entry);
//     } else {
//         // Create a new entry
//         var r = Ranges.init(alloc);
//         r.append(new_range) catch unreachable;
//         map.put(x, r) catch unreachable;
//     }
// }

//--------------------------------------------------------------------------------------------------
// pub fn insert_horizontal(y: u16, x1: u16, x2: u16, map: *MapType, alloc: *Allocator) void {
//     const min_x = std.math.min(x1, x2);
//     const max_x = std.math.max(x1, x2);
//     const len = max_x - min_x;

//     // TODO: need to check if we overlap with an existing range
//     var x_idx: u16 = min_x;
//     while (x_idx <= max_x) : (x_idx += 1) {
//         var r = Ranges.init(alloc);
//         r.append(.{ .first = y, .last = y, .value = 1 }) catch unreachable;
//         map.put(x_idx, r) catch unreachable;
//     }
// }

//--------------------------------------------------------------------------------------------------
pub fn insert_vertical(x: u16, y1: u16, y2: u16, map: *MapType) void {
    const min_y = std.math.min(y1, y2);
    const max_y = std.math.max(y1, y2);
    const new_range = .{ .first = min_y, .last = max_y, .value = 1 };

    var idx: u16 = min_y;
    while (idx <= max_y) : (idx += 1) {
        map[x][idx] += 1;
    }
}

//--------------------------------------------------------------------------------------------------
pub fn insert_horizontal(y: u16, x1: u16, x2: u16, map: *MapType) void {
    const min_x = std.math.min(x1, x2);
    const max_x = std.math.max(x1, x2);
    const len = max_x - min_x;

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

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const file_size = try file.getEndPos();
    std.log.info("File size {}", .{file_size});

    var reader = std.io.bufferedReader(file.reader());
    var istream = reader.reader();

    var buf: [20]u8 = undefined;
    var line_count: u32 = 0;

    var values: [4]u16 = undefined;

    // x values
    //var map = MapType.init(allocator);
    //defer map.deinit();
    var map = [_][1000]u16{.{0} ** 1000} ** 1000;
    while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        //std.log.info("{s}", .{line});
        var it = std.mem.tokenize(line, ", ->");
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
    //cleanup_map(&map);
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    try part1();
}
//--------------------------------------------------------------------------------------------------
