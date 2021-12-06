const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Fish = ArrayList(u8);

//--------------------------------------------------------------------------------------------------
pub fn part1() anyerror!void {
    const file = std.fs.cwd().openFile("data/day06_input.txt", .{}) catch |err| label: {
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
    var fish = Fish.init(allocator);

    var buf: [1024]u8 = undefined;
    while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var it = std.mem.tokenize(line, ",");
        while (it.next()) |value| {
            fish.append(std.fmt.parseInt(u8, value, 10) catch 0) catch unreachable;
        }
    }

    std.log.info("num fish before: {d}", .{fish.items.len});
    //std.log.info("{d}", .{fish.items});

    var day: u32 = 0;
    while (day < 80) : (day += 1) {
        for (fish.items) |*item| {
            if (item.* > 0) {
                item.* -= 1;
            } else {
                item.* = 6;
                try fish.append(8); // +1 because we will decrement the end of the list too
            }
        }
    }
    std.log.info("num fish after: {d}", .{fish.items.len});
}

//--------------------------------------------------------------------------------------------------
pub fn part2() anyerror!void {
    const file = std.fs.cwd().openFile("data/day06_input.txt", .{}) catch |err| label: {
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
    var fish = [_]u64{0} ** 9;

    var buf: [1024]u8 = undefined;
    while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var it = std.mem.tokenize(line, ",");
        while (it.next()) |value| {
            const gen = std.fmt.parseInt(u8, value, 10) catch 0;
            fish[gen] += 1;
        }
    }

    var sum: u64 = 0;
    for (fish) |count| {
        sum += count;
    }
    std.log.info("num fish before: {d}", .{sum});

    var day: u32 = 0;
    while (day < 256) : (day += 1) {
        const num_birthers = fish[0];
        var i: u32 = 0;
        while (i < 9 - 1) : (i += 1) {
            fish[i] = fish[i + 1]; // shift left, means timer reduced by one
        }
        fish[6] += num_birthers; // timer starts again
        fish[8] = num_birthers; // new births
    }

    sum = 0;
    for (fish) |count| {
        sum += count;
    }
    std.log.info("num fish after: {d}", .{sum});
}
//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    try part1();
    try part2();
}
//--------------------------------------------------------------------------------------------------
