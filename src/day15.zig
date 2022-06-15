const std = @import("std");
const Allocator = std.mem.Allocator;

//--------------------------------------------------------------------------------------------------
const Entry = struct {
    idx: u32,
    total_risk: u16,
    risk: u16,
};

//--------------------------------------------------------------------------------------------------
fn lessThan(context: void, a: Entry, b: Entry) std.math.Order {
    _ = context;
    return std.math.order(a.total_risk, b.total_risk);
}
const ToVisitQueue = std.PriorityQueue(Entry, void, lessThan);

//--------------------------------------------------------------------------------------------------
const Cavern = struct {
    width: u32,
    height: u32,
    entries: std.ArrayList(Entry),

    const Self = @This();
    pub fn initCapacity(allocator: Allocator, num: usize) Allocator.Error!Self {
        return Self{
            .width = 0,
            .height = 0,
            .entries = try std.ArrayList(Entry).initCapacity(allocator, num),
        };
    }
    pub fn deinit(self: Self) void {
        self.entries.deinit();
    }
};

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    var timer = try std.time.Timer.start();

    const file = std.fs.cwd().openFile("data/day15_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var cavern = try Cavern.initCapacity(allocator, 100 * 100);
    defer cavern.deinit();
    {
        var reader = std.io.bufferedReader(file.reader());
        var istream = reader.reader();
        var buf: [128]u8 = undefined;

        // Read lines
        var idx: u32 = 0;
        while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            if (line.len == 0) {
                continue;
            }
            cavern.width = @intCast(u32, line.len);

            // Convert line into array of ints
            for (line) |char| {
                const risk = std.fmt.charToDigit(char, 10) catch 0;
                const entry = Entry{
                    .idx = idx,
                    .risk = risk,
                    .total_risk = std.math.maxInt(u16),
                };
                cavern.entries.append(entry) catch unreachable;
                idx += 1;
            }
            cavern.height += 1;
        }
    }

    var cavern2 = try Cavern.initCapacity(allocator, 500 * 500);
    defer cavern2.deinit();
    {
        cavern2.width = cavern.width * 5;
        cavern2.height = cavern.height * 5;
        const dest_size: u32 = cavern2.width * cavern2.height;

        // Copy the first cavern but with repetitions
        var dest_idx: u32 = 0;
        while (dest_idx < dest_size) : (dest_idx += 1) {
            const dest_x = dest_idx % cavern2.width;
            const dest_y = dest_idx / cavern2.width;

            const source_x = dest_idx % cavern.width;
            const source_y = dest_y % cavern.height;

            const x_repeat = dest_x / cavern.width;
            const y_repeat = dest_y / cavern.height;

            const source_idx = (source_y * cavern.width) + source_x;
            const source_risk = cavern.entries.items[source_idx].risk;

            const risk_inc: u16 = @intCast(u16, x_repeat + y_repeat);
            const new_risk = ((source_risk + risk_inc - 1) % 9) + 1; // wrap around

            const entry = Entry{
                .idx = dest_idx,
                .risk = new_risk,
                .total_risk = std.math.maxInt(u16),
            };
            cavern2.entries.append(entry) catch unreachable;
        }
    }

    const part1_risk = search(&cavern, allocator) catch 0;
    std.log.info("Part 1 Found exit: Total risk {d}\n", .{part1_risk});

    const part2_risk = search(&cavern2, allocator) catch 0;
    std.log.info("Part 2 Found exit: Total risk {d}\n", .{part2_risk});

    std.log.info("Completed in {d:.2}ms\n", .{@intToFloat(f32, timer.lap()) / 1.0e+6});
}

//--------------------------------------------------------------------------------------------------
fn search(cavern: *Cavern, allocator: Allocator) anyerror!u32 {
    //std.log.info("cavern.width: {d}", .{cavern.width});
    //std.log.info("cavern.height: {d}", .{cavern.height});
    //std.log.info("cavern.len: {d}", .{cavern.entries.items.len});

    const start_idx = 0;
    const exit_idx = cavern.entries.items.len - 1;

    var to_visit = ToVisitQueue.init(allocator, {});
    defer to_visit.deinit();

    cavern.entries.items[start_idx].total_risk = 0;
    try to_visit.add(cavern.entries.items[start_idx]);

    while (to_visit.len != 0) {
        var visit_ptr = to_visit.remove();
        const visit_idx = visit_ptr.idx;
        const x = visit_ptr.idx % cavern.width;
        const y = visit_ptr.idx / cavern.width;
        const current_risk = visit_ptr.total_risk;
        //std.log.info("Visiting: idx:{d} - {}x{}\n", .{ visit_idx, x, y });

        if (visit_idx == exit_idx) {
            return current_risk;
        }

        // for each neighbour, check if we `can` move there
        const north_idx: ?u32 = if (y > 0) visit_idx - cavern.width else null;
        const south_idx: ?u32 = if (y < cavern.height - 1) visit_idx + cavern.width else null;
        const west_idx: ?u32 = if (x > 0) visit_idx - 1 else null;
        const east_idx: ?u32 = if (x < cavern.width - 1) visit_idx + 1 else null;

        // then move there only if it's currently the cheapest route to there
        if (north_idx) |idx| {
            try move_if_cheaper(idx, cavern, &to_visit, current_risk);
        }
        if (south_idx) |idx| {
            try move_if_cheaper(idx, cavern, &to_visit, current_risk);
        }
        if (west_idx) |idx| {
            try move_if_cheaper(idx, cavern, &to_visit, current_risk);
        }
        if (east_idx) |idx| {
            try move_if_cheaper(idx, cavern, &to_visit, current_risk);
        }
    }
    return 0;

    //std.log.info("Part 2: {d}", .{calc_min_max_diff(map, template_slice.?)});
}

//--------------------------------------------------------------------------------------------------
fn move_if_cheaper(to_idx: u32, cavern: *Cavern, to_visit: *ToVisitQueue, current_risk: u16) anyerror!void {
    const risk = cavern.entries.items[to_idx].risk;
    const new_total = current_risk + risk;
    if (new_total < cavern.entries.items[to_idx].total_risk) {
        cavern.entries.items[to_idx].total_risk = new_total;

        // TODO: what happens if we already marked this place to visit
        try to_visit.add(cavern.entries.items[to_idx]);
    }
}

//--------------------------------------------------------------------------------------------------

