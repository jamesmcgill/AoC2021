const std = @import("std");

//--------------------------------------------------------------------------------------------------
pub fn part1() anyerror!void
{
    const file = std.fs.cwd().openFile("data/day01_input.txt", .{}) catch |err| label:
    {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    std.log.info("File size {}", .{file_size});

    //var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    //defer arena.deinit();
    //const allocator = &arena.allocator;

    //const contents = try file.readToEndAlloc(allocator, file_size);
    //defer allocator.free(contents);

    var reader = std.io.bufferedReader(file.reader());
    var istream = reader.reader();
    var buf: [8]u8 = undefined;
    var increase_count: u32 = 0;
    var last_val: u32 = std.math.maxInt(u32);
    
    while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line|
    {
        //std.log.info("{s}", .{line});
        var current_val = std.fmt.parseInt(u32, line, 10) catch std.math.minInt(u32);
        if (current_val > last_val)
        {
            increase_count += 1;
        }
        last_val = current_val;
    }
    std.log.info("Part 1 increases: {d}", .{increase_count});
}

//--------------------------------------------------------------------------------------------------
pub fn part2() anyerror!void
{
    const file = std.fs.cwd().openFile("data/day01_input.txt", .{}) catch |err| label:
    {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    var reader = std.io.bufferedReader(file.reader());
    var istream = reader.reader();
    var buf: [8]u8 = undefined;
    var increase_count: u32 = 0;

    var head_pos: u32 = 0;
    var window: [3]u32 = undefined;
    var total: u32 = 0;

    while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line|
    {
        var current_val = std.fmt.parseInt(u32, line, 10) catch std.math.minInt(u32);
        // Priming the window for the first few round
        if (head_pos < 3) {
            window[head_pos] = current_val;
            total += current_val;
            head_pos += 1;
        }
        else
        {
            var new_total = total + current_val - window[0];
            if (new_total > total)
            {
                increase_count += 1;
            }
            // Slide the 'sliding window'
            window[0] = window[1];
            window[1] = window[2];
            window[2] = current_val;
            total = new_total;
        }
    }
    std.log.info("Part 2: increases: {d}", .{increase_count});
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void
{
    try part1();
    try part2();
}
//--------------------------------------------------------------------------------------------------