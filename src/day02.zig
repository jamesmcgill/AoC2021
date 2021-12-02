const std = @import("std");

//--------------------------------------------------------------------------------------------------
pub fn part1() anyerror!void {
    const file = std.fs.cwd().openFile("data/day02_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    std.log.info("File size {}", .{file_size});

    var reader = std.io.bufferedReader(file.reader());
    var istream = reader.reader();
    var buf: [32]u8 = undefined;

    var x: u32 = 0;
    var y: u32 = 0;

    while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        //std.log.info("{s}", .{line});
        var it = std.mem.split(line, " ");

        const command = it.next() orelse "none";
        const raw_value = it.next() orelse "0";
        const value = try std.fmt.parseInt(u32, raw_value, 10);
        //std.log.info("Command={s}, Value={d}", .{ command, value });

        if (std.mem.eql(u8, command, "forward")) {
            x += value;
        } else if (std.mem.eql(u8, command, "down")) {
            y += value;
        } else if (std.mem.eql(u8, command, "up")) {
            y -= value;
        }
    }
    std.log.info("Part 1 x={d}, y={d}, answer={d}", .{ x, y, x * y });
}

//--------------------------------------------------------------------------------------------------
pub fn part2() anyerror!void {
    const file = std.fs.cwd().openFile("data/day02_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    //const file_size = try file.getEndPos();
    //std.log.info("File size {}", .{file_size});

    var reader = std.io.bufferedReader(file.reader());
    var istream = reader.reader();
    var buf: [32]u8 = undefined;

    var x: i32 = 0;
    var y: i32 = 0;
    var aim: i32 = 0;

    while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        //std.log.info("{s}", .{line});
        var it = std.mem.split(line, " ");

        const command = it.next() orelse "none";
        const raw_value = it.next() orelse "0";
        const value = try std.fmt.parseInt(i32, raw_value, 10);
        //std.log.info("Command={s}, Value={d}", .{ command, value });

        if (std.mem.eql(u8, command, "forward")) {
            x += value;
            y += aim * value;
        } else if (std.mem.eql(u8, command, "down")) {
            aim += value;
        } else if (std.mem.eql(u8, command, "up")) {
            aim -= value;
        }
    }
    std.log.info("Part 2 x={d}, y={d}, answer={d}", .{ x, y, x * y });
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    try part1();
    try part2();
}
//--------------------------------------------------------------------------------------------------
