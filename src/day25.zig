//--------------------------------------------------------------------------------------------------
// Features used:
//
// - File loading and parsing
//--------------------------------------------------------------------------------------------------
//
//--------------------------------------------------------------------------------------------------
const std = @import("std");
const Allocator = std.mem.Allocator;

const Line = std.ArrayList(u2);
const Map = std.ArrayList(Line);

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    var timer = try std.time.Timer.start();

    // Read entire file into huge buffer and get a slice to the populated part
    var buffer: [140 * 140]u8 = undefined;
    const buffer_populated = try std.fs.cwd().readFile("data/day25_input.txt", buffer[0..]);
    std.debug.assert(buffer_populated.len < buffer.len); // Otherwise buffer is too small

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var map = Map.init(allocator);
    defer {
        for (map.items) |line| {
            line.deinit();
        }
        map.deinit();
    }
    //----------------------------------------------------------------------------------------------
    // Parse the input data
    {
        var line_idx: usize = 0;
        var it = std.mem.tokenize(u8, buffer_populated, "\r\n");
        while (it.next()) |line| : (line_idx += 1) {
            std.debug.assert(line.len != 0);

            // compress u8 -> u2
            // > == 0b01
            // v == 0b10
            // . == 0b00
            var map_line = Line.init(allocator);
            for (line) |c| {
                if (c == '>') {
                    try map_line.append(1);
                } else if (c == 'v') {
                    try map_line.append(2);
                } else {
                    try map_line.append(0);
                }
            }
            try map.append(map_line);
        }
        // std.log.info("Initial  ----------------------------------", .{});
        // print_map(map);
    }
    //----------------------------------------------------------------------------------------------
    // Evolve the map
    {
        var moves: usize = 0;
        while (true) : (moves += 1) {
            if (!tick_map(&map)) {
                break;
            }

            //std.log.info("after move:{d}  ----------------------------------", .{moves + 1});
            //print_map(map);
        }
        std.log.info("Moves:{d}", .{moves + 1});
    }

    std.log.info("Completed in {d:.2}ms", .{@intToFloat(f32, timer.lap()) / 1.0e+6});
}

//--------------------------------------------------------------------------------------------------
pub fn print_map(map: Map) void {
    var out = std.io.getStdOut().writer(); // can write directly to this
    var buffer = std.io.bufferedWriter(out);
    var o = buffer.writer(); // or with this, but remember to call buffer.flush()

    for (map.items) |line| {
        for (line.items) |c| {
            if (c == 0) {
                o.print(".", .{}) catch unreachable;
            } else if (c == 1) {
                o.print(">", .{}) catch unreachable;
            } else if (c == 2) {
                o.print("v", .{}) catch unreachable;
            } else {
                o.print("X", .{}) catch unreachable;
            }
        }
        o.print("\n", .{}) catch unreachable;
    }
    buffer.flush() catch unreachable;
}

//--------------------------------------------------------------------------------------------------
pub fn tick_map(map: *Map) bool {
    var something_moved = false;

    // ">" items first (lines)
    for (map.items) |line| {
        // Need cached version as this is the state before we moved
        // We move as we go here in a single round, but really we should have
        // looked and decided in a round, then move in the next round.
        const was_first_occupied = (line.items[0] != 0);

        var previous_move = false;
        for (line.items) |c, i| {

            // If we moved the previous item, then it will have moved to here.
            // To avoid moving it again we can skip this item.
            if (previous_move) {
                previous_move = false;
                continue;
            }

            if (c == 1) { // '>'
                const is_last = (i == (line.items.len - 1));
                const next_occupied = if (is_last) was_first_occupied else (line.items[i + 1] != 0);
                if (!next_occupied) {
                    const next_idx = if (is_last) 0 else i + 1;
                    line.items[i] = 0;
                    line.items[next_idx] = 1; // '>'
                    something_moved = true;
                    previous_move = true;
                }
            }
        }
    }

    // "v" items first (columns - TODO: not cache friendly access)
    const num_columns = map.items[0].items.len;
    var column: usize = 0;
    while (column < num_columns) : (column += 1) {
        // Need cached version as this is the state before we moved
        // We move as we go here in a single round, but really we should have
        // looked and decided in a round, then move in the next round.
        const was_first_occupied = (map.items[0].items[column] != 0); // line 0 is top

        var previous_move = false;
        for (map.items) |line, i| {
            // If we moved the previous item, then it will have moved to here.
            // To avoid moving it again we can skip this item.
            if (previous_move) {
                previous_move = false;
                continue;
            }

            const c = line.items[column];
            if (c == 2) { // 'v'
                const is_last = (i == (map.items.len - 1));

                const next_occupied = if (is_last)
                    was_first_occupied
                else
                    (map.items[i + 1].items[column] != 0);
                if (!next_occupied) {
                    const next_idx = if (is_last) 0 else i + 1;
                    map.items[i].items[column] = 0;
                    map.items[next_idx].items[column] = 2; // 'v'
                    something_moved = true;
                    previous_move = true;
                }
            }
        } // for lines
    } // while column
    return something_moved;
}

//--------------------------------------------------------------------------------------------------
