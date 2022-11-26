//--------------------------------------------------------------------------------------------------
// Features used:
// - IntegerBitSet
// - Bit packing (Vec3 -> hashmap_key)
// - Hashmap
// - ArrayList with allocator
// - File loading and parsing
//--------------------------------------------------------------------------------------------------
const std = @import("std");
const Allocator = std.mem.Allocator;

//--------------------------------------------------------------------------------------------------
const Vec2 = struct {
    x: i16,
    y: i16,
};
const Algo = std.bit_set.IntegerBitSet(512);
const Points = std.AutoHashMap(u32, u8);

const Grid = struct {
    max_range: Vec2,
    min_range: Vec2,
    points: Points,
};
const Grids = std.ArrayList(Grid);

//--------------------------------------------------------------------------------------------------
pub fn make_grid(allocator: Allocator) Grid {
    return Grid{
        .points = Points.init(allocator),
        .max_range = Vec2{
            .x = std.math.minInt(i16),
            .y = std.math.minInt(i16),
        },
        .min_range = Vec2{
            .x = std.math.maxInt(i16),
            .y = std.math.maxInt(i16),
        },
    };
}
//--------------------------------------------------------------------------------------------------
pub fn populate_single(x: i16, y: i16, grid: Grid, next_grid: *Grid, algo: Algo, store_lit_pixels: bool) void {
    const hash_coord = hash_from_coord(x, y);
    if (next_grid.points.contains(hash_coord)) {
        return;
    }

    // Assumes store_lit_pixels alternates between grid and next_grid
    // So here we PUT into `next_grid` based on store_lit_pixels
    // But assume that we GET the value from `grid`, using the inverse of what
    // store_lit_pixels is currently.
    //
    // This only works for this particular input data because all empty space will produce index 0.
    // And index 0 has a lit value (#) in the algorithm, so all (infinite) empty space becomes lit
    // But then, also for the input data, 9 lit pixels produces idx 512, which is set to empty (.)
    // So on the next round, the infinite lit area will become switched off.
    const idx = getValueAt(x, y, grid, !store_lit_pixels);

    // PUT into `next_grid`. Either sparse storing only the lit pixels, or only the unlit pixels
    // depending on store_lit_pixels. We don't want to store infinite number of objects, but at the
    // beginning the lit objects are finite. On the next round they become infinite, but the unlit
    // pixels become finite, so we store those instead.
    if ((algo.isSet(idx) and store_lit_pixels) or
        (!algo.isSet(idx) and !store_lit_pixels))
    {
        next_grid.*.points.put(hash_coord, 0) catch unreachable;
        add_to_grid_range(x, y, &(next_grid.*).min_range, &(next_grid.*).max_range);
    }
}

//--------------------------------------------------------------------------------------------------
pub fn getValueAt(x: i16, y: i16, grid: Grid, store_lit_pixels: bool) u16 {
    var result: u16 = 0;
    var bit_value: u16 = 1;

    // Start with least significant bit (bottom-right)
    var current_y = y + 1;
    while (current_y >= y - 1) {
        var current_x = x + 1;

        while (current_x >= x - 1) {
            const hash = hash_from_coord(current_x, current_y);
            if ((grid.points.contains(hash) and store_lit_pixels) or
                (!grid.points.contains(hash) and !store_lit_pixels))
            {
                result += bit_value;
            }
            bit_value = bit_value << 1;
            current_x -= 1;
        }

        current_y -= 1;
    }
    return result;
}

//--------------------------------------------------------------------------------------------------
pub fn hash_from_coord(x: i16, y: i16) u32 {
    const x_shift: u32 = @intCast(u32, @bitCast(u16, x)) << 16;
    return x_shift | @bitCast(u16, y);
}

//--------------------------------------------------------------------------------------------------
pub fn coord_from_hash(hash: u32) Vec2 {
    return Vec2{
        .x = @bitCast(i16, @intCast(u16, hash >> 16)),
        .y = @bitCast(i16, @intCast(u16, hash & 0xFFFF)),
    };
}

//--------------------------------------------------------------------------------------------------
pub fn add_to_grid_range(x: i16, y: i16, min_range: *Vec2, max_range: *Vec2) void {
    if (x > max_range.*.x) {
        max_range.*.x = x;
    }
    if (y > max_range.*.y) {
        max_range.*.y = y;
    }
    if (x < min_range.*.x) {
        min_range.*.x = x;
    }
    if (y < min_range.*.y) {
        min_range.*.y = y;
    }
}
//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    var timer = try std.time.Timer.start();

    // Read entire file into huge buffer and get a slice to the populated part
    var buffer: [512 * 105]u8 = undefined;
    const buffer_populated = try std.fs.cwd().readFile("data/day20_input.txt", buffer[0..]);
    std.debug.assert(buffer_populated.len < buffer.len); // Otherwise buffer is too small

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var algo = Algo.initEmpty();

    var grids = Grids.init(allocator);
    defer {
        for (grids.items) |*grid| {
            grid.points.deinit();
        }
        grids.deinit();
    }
    //----------------------------------------------------------------------------------------------
    // Parse the input data
    {
        var starting_grid = make_grid(allocator);

        var line_idx: usize = 0;
        var it = std.mem.split(u8, buffer_populated, "\n");
        while (it.next()) |line| {
            line_idx += 1;
            if (line.len == 0) {
                continue;
            }

            // Parse algorithm
            if (line_idx == 1) {
                std.debug.assert(line.len <= algo.capacity());
                for (line) |c, idx| {
                    if (c == '#') {
                        algo.set(idx);
                    }
                }
                continue;
            }

            // Parse image
            for (line) |c, i| {
                if (c == '#') {
                    const x = @intCast(i16, i);
                    const y = @intCast(i16, line_idx - 3); // y coordinate doesn't need to start at 0

                    const hashed_coord = hash_from_coord(x, y);
                    try starting_grid.points.put(hashed_coord, 0);
                    add_to_grid_range(x, y, &starting_grid.min_range, &starting_grid.max_range);
                }
            }
        }
        try grids.append(starting_grid);
        std.log.info("Start Grid.count: {d}", .{starting_grid.points.count()});
    }

    //----------------------------------------------------------------------------------------------
    var generation: usize = 0;
    while (generation < 50) {
        const grid = grids.items[grids.items.len - 1];

        const x_start = grid.min_range.x - 1;
        const y_start = grid.min_range.y - 1;
        const x_last = grid.max_range.x + 1;
        const y_last = grid.max_range.y + 1;

        var next_grid = make_grid(allocator);

        // Alternate between sparse storing the lit objects or the unlit objects.
        // With this particular input data, each generation alternates which of these is infinite in number.
        // See populate_single() for more info.
        const store_lit_pixels: bool = (generation % 2) == 1;

        var y = y_start;
        while (y <= y_last) {
            var x = x_start;
            while (x <= x_last) {
                populate_single(x, y, grid, &next_grid, algo, store_lit_pixels);
                x += 1;
            }
            y += 1;
        }

        try grids.append(next_grid);
        generation += 1;
        std.log.info("Grid.count after {d} enhancements: {d}", .{ generation, next_grid.points.count() });
    }

    std.log.info("Completed in {d:.2}ms", .{@intToFloat(f32, timer.lap()) / 1.0e+6});
}

//--------------------------------------------------------------------------------------------------

