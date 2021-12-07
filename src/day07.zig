const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Crabs = ArrayList(u16);

//--------------------------------------------------------------------------------------------------
pub fn sort(crabs: *Crabs) void {
    var i: usize = 1;
    while (i < crabs.items.len) : (i += 1) {
        const x = crabs.items[i];
        var j: usize = i;

        while (j > 0 and x < crabs.items[j - 1]) : (j -= 1) {
            crabs.items[j] = crabs.items[j - 1];
        }
        crabs.items[j] = x;
    }
}

//--------------------------------------------------------------------------------------------------
pub fn part1() anyerror!void {
    const file = std.fs.cwd().openFile("data/day07_input.txt", .{}) catch |err| label: {
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
    var crabs = Crabs.init(allocator);

    var buf: [4096]u8 = undefined;
    while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var it = std.mem.tokenize(line, ",");
        while (it.next()) |value| {
            crabs.append(std.fmt.parseInt(u16, value, 10) catch 0) catch unreachable;
        }
    }

    std.log.info("num crabs: {d}", .{crabs.items.len});
    sort(&crabs);
    //std.log.info("{d}", .{crabs.items});

    const median_idx = crabs.items.len / 2;
    var median = crabs.items[median_idx];
    if (crabs.items.len % 2 == 0) {
        median += crabs.items[median_idx - 1];
        median /= 2;
    }
    std.log.info("final median: {d}", .{median});

    var fuel: u32 = 0;
    for (crabs.items) |item| {
        fuel += if (item > median) item - median else median - item;
    }
    std.log.info("Part 1: fuel: {d}", .{fuel});

    // Part 2
    var sum: u64 = 0;
    for (crabs.items) |item| {
        sum += item;
    }
    const denom: u32 = @intCast(u32, crabs.items.len);
    const m: u32 = @divTrunc(@intCast(u32, sum), denom);
    const mean: u32 = m; //if (m * denom != sum) m + 1 else m; // Rounded up value was incorrect answer!?

    //std.log.info("sum: {d}", .{sum});
    std.log.info("mean: {d}", .{mean});

    fuel = 0;
    for (crabs.items) |item| {
        const dist: u32 = if (item > mean) item - mean else mean - item;
        // Closed form solution => [(n^2 - n) / 2] + n
        fuel += (((dist * dist) - dist) / 2) + dist;
    }
    std.log.info("Part 2: fuel: {d}", .{fuel});
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    try part1();
}
//--------------------------------------------------------------------------------------------------
