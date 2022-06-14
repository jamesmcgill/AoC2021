const std = @import("std");

//--------------------------------------------------------------------------------------------------
const Entry = struct {
    total_count: u64,
    spawn_count: u64,
    spawn_pair_left: [2]u8,
    spawn_pair_right: [2]u8,
};

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    var timer = try std.time.Timer.start();

    const file = std.fs.cwd().openFile("data/day14_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var map = std.AutoHashMap([2]u8, Entry).init(allocator);
    defer {
        map.deinit();
    }

    var template_buf: [20]u8 = undefined;
    var template_slice: ?[]u8 = undefined;
    {
        var reader = std.io.bufferedReader(file.reader());
        var istream = reader.reader();
        var buf: [20]u8 = undefined;

        // Read template
        template_slice = try istream.readUntilDelimiterOrEof(&template_buf, '\n');
        std.debug.assert(template_slice != null);

        // Read insertion rules
        while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            if (line.len == 0) {
                continue;
            }
            var it = std.mem.split(u8, line, " -> ");
            const pattern = it.next().?;
            //std.log.info("pattern: {c}", .{pattern});
            const insertion = it.next().?;
            //std.log.info("insertion: {c}", .{insertion});

            // Add all rules into the map
            const entry = Entry{
                .total_count = 0,
                .spawn_count = 0,
                .spawn_pair_left = [2]u8{ pattern[0], insertion[0] },
                .spawn_pair_right = [2]u8{ insertion[0], pattern[1] },
            };
            var key = [2]u8{ pattern[0], pattern[1] };
            try map.put(key, entry);
        }
    }
    //std.log.info("template: {c}", .{template_slice});

    // Prime map with initial entries from the template
    // NOTE: The second iteration will create a pair that duplicates the last letter
    // from the first iteration e.g. CFBV -> CF FB BV
    // This means every letter is duplicated by the pairing except the first and last.
    // This needs to be accounted for during the counting stage.
    {
        var key: [2]u8 = undefined;
        var i: usize = 1;
        while (i < template_slice.?.len) : (i += 1) {
            key[0] = template_slice.?[i - 1];
            key[1] = template_slice.?[i];
            map.getPtr(key).?.total_count += 1;
        }
    }

    // Apply steps
    {
        const part1_iterations: u32 = 10;
        const part2_iterations: u32 = 40;

        var i: usize = 0;
        while (i < part2_iterations) : (i += 1) {
            if (i == part1_iterations) {
                std.log.info("Part 1: {d}", .{calc_min_max_diff(map, template_slice.?)});
            }

            // Expand each `current` pair of letters to spawn 2 new pairs
            // These 2 new pairs will replace the current pair on the next iteration
            // NOTE: this means from 2 letters we spawn 4 letters (not just 3)
            // e.g. CF FB BV -> CxxF FyyB BzzV
            // Therefore we continue to have double the amount of letters (excluding first/last).
            {
                var it = map.iterator();
                while (it.next()) |pair| {
                    const value_ptr = pair.value_ptr;

                    const left = &value_ptr.spawn_pair_left;
                    const right = &value_ptr.spawn_pair_right;

                    map.getPtr(left.*).?.spawn_count += value_ptr.total_count;
                    map.getPtr(right.*).?.spawn_count += value_ptr.total_count;
                }
            }

            // Now spawn all new pairs we found in the last pass
            {
                var it = map.iterator();
                while (it.next()) |pair| {
                    const value_ptr = pair.value_ptr;

                    // Replace `current` pairs with only the pairs that were spawned
                    // in this iteration.
                    value_ptr.total_count = value_ptr.spawn_count;
                    value_ptr.spawn_count = 0;
                }
            }
        }
    }
    std.log.info("Part 2: {d}", .{calc_min_max_diff(map, template_slice.?)});
    std.log.info("Completed in {d:.2}ms\n", .{@intToFloat(f32, timer.lap()) / 1.0e+6});
}

//--------------------------------------------------------------------------------------------------
fn calc_min_max_diff(map: std.AutoHashMap([2]u8, Entry), template: []u8) u64 {
    var letters = [_]u64{0} ** 27;
    // As we have double counted the letters except for the first and last,
    // we should increase the count of the first and last letters, so that
    // everything is double counted (for now).
    letters[template[0] - 'A'] += 1;
    letters[template[template.len - 1] - 'A'] += 1;

    // For all the `current` pairs, count the individual letters
    var it = map.iterator();
    while (it.next()) |pair| {
        const key = pair.key_ptr.*;
        const value_ptr = pair.value_ptr;

        letters[key[0] - 'A'] += value_ptr.total_count;
        letters[key[1] - 'A'] += value_ptr.total_count;
    }

    var min: u64 = std.math.maxInt(u64);
    var max: u64 = 0;

    // Find the max and mins
    for (letters) |count| {
        if (count != 0 and min > count) {
            min = count;
        }

        if (max < count) {
            max = count;
        }
    }

    // NOTE: half the counts because we double counted everything.
    return (max - min) / 2;
}

//--------------------------------------------------------------------------------------------------
