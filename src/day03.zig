const std = @import("std");

//--------------------------------------------------------------------------------------------------
pub fn part1() anyerror!void {
    const file = std.fs.cwd().openFile("data/day03_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    std.log.info("File size {}", .{file_size});

    var reader = std.io.bufferedReader(file.reader());
    var istream = reader.reader();

    var buf: [12]u8 = undefined;
    var counts = [_]u32{0} ** 12;
    var line_count: u32 = 0;

    while (try istream.readUntilDelimiterOrEof(&buf, '\n')) {
        //std.log.info("{s}", .{line});
        line_count += 1;

        for (buf) |char, i| {
            if (char == '1') {
                counts[i] += 1;
            }
        }
    }

    var gamma_rate: u16 = 0;
    var epsilon_rate: u16 = 0;
    for (counts) |count, i| {
        if (count > line_count / 2) { // most common bit is 1
            gamma_rate |= (@as(u16, 1) << @truncate(u4, 11 - i));
        } else {
            epsilon_rate |= (@as(u16, 1) << @truncate(u4, 11 - i)); // least common bit is 1
        }
    }

    std.log.info("Part 1 counts={d}, gamma_rate={b}, epsilon_rate={b}, answer={d}", .{ counts, gamma_rate, epsilon_rate, gamma_rate * @as(u32, epsilon_rate) });
}

//--------------------------------------------------------------------------------------------------
pub fn copy_array(input: [12]u8) [12]u8 {
    var res = [_]u8{0} ** 12;

    var i: u32 = 0;
    while (i < 12) : (i += 1) {
        res[i] = input[i];
    }
    return res;
}

//--------------------------------------------------------------------------------------------------
pub fn eq_array(lhs: [12]u8, rhs: [12]u8, limit: u32) bool {
    var i: u32 = 0;
    while (i < 12 and i < limit) : (i += 1) {
        if (lhs[i] != rhs[i]) {
            return false;
        }
    }
    return true;
}

//--------------------------------------------------------------------------------------------------
pub fn array_to_int(input: [12]u8) u32 {
    var res: u32 = 0;

    var i: u32 = 0;
    while (i < 12) : (i += 1) {
        if (input[i] == '1') {
            res |= (@as(u32, 1) << @truncate(u4, 11 - i));
        }
    }
    return res;
}

//--------------------------------------------------------------------------------------------------
pub fn part2() anyerror!void {
    const file = std.fs.cwd().openFile("data/day03_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    std.log.info("File size {}", .{file_size});

    var reader = std.io.bufferedReader(file.reader());
    var buf: [12]u8 = undefined;

    var oxygen = [_]u8{'0'} ** 12;
    var oxygen_lines_count: u32 = 0;
    var oxygen_set_count: u32 = 0;

    var co2 = [_]u8{'0'} ** 12;
    var co2_lines_count: u32 = 0;
    var co2_set_count: u32 = 0;

    var final_oxygen = [_]u8{'0'} ** 12;
    var final_co2 = [_]u8{'0'} ** 12;

    for (buf) |digit, col_idx| {
        _ = digit;

        oxygen_lines_count = 0;
        oxygen_set_count = 0;
        co2_lines_count = 0;
        co2_set_count = 0;

        // Read the whole file. But just examining one column (digit)
        try file.seekTo(0);
        var istream = reader.reader();
        while (try istream.readUntilDelimiterOrEof(&buf, '\n')) {
            //std.log.info("{s}", .{line});
            var is_oxygen = eq_array(oxygen, buf, @truncate(u32, col_idx));
            var is_co2 = eq_array(co2, buf, @truncate(u32, col_idx));

            if (is_oxygen) {
                final_oxygen = copy_array(buf);
                oxygen_lines_count += 1;
                // Total count of 1 digits
                if (buf[col_idx] == '1') {
                    oxygen_set_count += 1;
                }
            }

            if (is_co2) {
                co2_lines_count += 1;
                final_co2 = copy_array(buf);
                // Total count of 1 digits
                if (buf[col_idx] == '1') {
                    co2_set_count += 1;
                }
            }
        } // while file

        // Calculate the most common bit (oxygen) and place it into a filter
        if (oxygen_set_count >= (oxygen_lines_count - oxygen_set_count)) { // most common bit is 1
            oxygen[col_idx] = '1';
        }

        if (co2_set_count < (co2_lines_count - co2_set_count)) { // least common bit is 1
            co2[col_idx] = '1';
        }
    } // for digit

    const res_oxygen = array_to_int(final_oxygen);
    const res_co2 = array_to_int(final_co2);
    const answer = res_oxygen * res_co2;

    std.log.info("Part 2 oxygen={b}, co2={b}, answer={d}", .{ res_oxygen, res_co2, answer });
}

//--------------------------------------------------------------------------------------------------
const Allocator = std.mem.Allocator;

//--------------------------------------------------------------------------------------------------
const Node = struct {
    value: u32,
    l: ?*Node,
    r: ?*Node,

    pub fn init() Node {
        return Node{
            .value = 0,
            .l = null,
            .r = null,
        };
    }
};

//--------------------------------------------------------------------------------------------------
pub fn create_node(allocator: *Allocator) ?*Node {
    const ptr: ?*Node = allocator.create(Node) catch return null;
    ptr.?.* = Node.init();
    return ptr;
}

//--------------------------------------------------------------------------------------------------
pub fn tree_add(head: *Node, input: []u8, allocator: *Allocator) void {
    (head.*).value += 1;

    if (input.len == 0) {
        return;
    } else if (input[0] == '1') {
        if (head.l == null) {
            head.l = create_node(allocator).?;
        }
        tree_add(head.l.?, input[1..], allocator);
    } else {
        if (head.r == null) {
            head.r = create_node(allocator).?;
        }
        tree_add(head.r.?, input[1..], allocator);
    }
}

//--------------------------------------------------------------------------------------------------
pub fn tree_print(head: *Node) void {
    std.log.info("val={d}", .{head.value});
    if (head.l != null) {
        tree_print(head.l.?);
    }
    if (head.r != null) {
        tree_print(head.r.?);
    }
}

//--------------------------------------------------------------------------------------------------
pub fn tree_most_common(head: *Node, result: []u8) void {
    var left_count: u32 = 0;
    var right_count: u32 = 0;

    if (head.l != null) {
        left_count = head.l.?.value;
    }
    if (head.r != null) {
        right_count = head.r.?.value;
    }

    // Go left (1) on tie breaker
    if (left_count >= right_count and head.l != null) {
        //std.log.info("1 <= {d}/{d}", .{ left_count, right_count });
        result[0] = '1';
        tree_most_common(head.l.?, result[1..]);
    } else if (head.r != null) {
        //std.log.info("0 <= {d}/{d}", .{ left_count, right_count });
        result[0] = '0';
        tree_most_common(head.r.?, result[1..]);
    }
}

//--------------------------------------------------------------------------------------------------
pub fn tree_least_common(head: *Node, result: []u8) void {
    var left_count: u32 = 0;
    var right_count: u32 = 0;

    if (head.l != null) {
        left_count = head.l.?.value;
    }
    if (head.r != null) {
        right_count = head.r.?.value;
    }

    // Go right (0) on tie breaker
    if ((right_count == 0 or left_count < right_count) and head.l != null) {
        //std.log.info("1 <= {d}/{d}", .{ left_count, right_count });
        result[0] = '1';
        tree_least_common(head.l.?, result[1..]);
    } else if (head.r != null) {
        //std.log.info("0 <= {d}/{d}", .{ left_count, right_count });
        result[0] = '0';
        tree_least_common(head.r.?, result[1..]);
    }
}

//--------------------------------------------------------------------------------------------------
pub fn part2_with_tree() anyerror!void {
    const file = std.fs.cwd().openFile("data/day03_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var reader = std.io.bufferedReader(file.reader());
    var istream = reader.reader();
    var buf: [12]u8 = undefined;
    var head = create_node(&allocator).?;

    // Traverse file and build tree
    while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        _ = line;
        tree_add(head, buf[0..12], &allocator);
    } // while file

    var most_common_result: [12]u8 = undefined;
    var least_common_result: [12]u8 = undefined;

    tree_most_common(head, most_common_result[0..]);
    tree_least_common(head, least_common_result[0..]);

    //tree_print(head);
    const oxygen: u32 = array_to_int(most_common_result);
    const co2: u32 = array_to_int(least_common_result);
    std.log.info("Part 2 oxygen={s}, co2={s}, answer={d}", .{ most_common_result, least_common_result, oxygen * co2 });
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    //try part1();
    try part2_with_tree();
}
//--------------------------------------------------------------------------------------------------
