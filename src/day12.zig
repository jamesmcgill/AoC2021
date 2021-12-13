const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
//const Nodes = ArrayList(Node);
const Visited = ArrayList([]const u8);

//--------------------------------------------------------------------------------------------------
const Connection = struct {
    a: []const u8,
    b: []const u8,
};

//--------------------------------------------------------------------------------------------------
const Node = struct {
    val: []const u8,
    children: [6]*Node,
    child_count: u8,
    is_small: bool,

    pub fn init(val: []const u8) Node {
        return Node{ .val = val, .children = undefined, .child_count = 0, .is_small = is_small(val) };
    }

    pub fn attach(self: *Node, new: *Node) void {
        self.children[self.child_count] = new;
        self.child_count += 1;
    }

    pub fn has_child(self: *Node, value: []const u8) bool {
        for (self.children[0..self.child_count]) |child| {
            if (std.mem.eql(u8, child.val, value)) {
                return true;
            }
        }
        return false;
    }
};

//--------------------------------------------------------------------------------------------------
pub fn in_list(list: *Visited, value: []const u8) bool {
    for (list.items) |item| {
        if (std.mem.eql(u8, item, value)) {
            return true;
        }
    }
    return false;
}

//--------------------------------------------------------------------------------------------------
pub fn count_in_list(list: *Visited, value: []const u8) u32 {
    var count: u32 = 0;
    for (list.items) |item| {
        if (std.mem.eql(u8, item, value)) {
            count += 1;
        }
    }
    return count;
}

//--------------------------------------------------------------------------------------------------
pub fn is_small(value: []const u8) bool {
    //if (std.mem.eql(u8, value, "end")) {
    //    return false;
    //}

    return (value[0] >= 'a');
}

//--------------------------------------------------------------------------------------------------
pub fn refuse_visit(visited: *Visited, value: []const u8, allowed_twice: *const [2:0]u8) bool {
    if (std.mem.eql(u8, value, "start")) {
        return true;
    }

    if (!is_small(value)) {
        return false;
    }

    const count = count_in_list(visited, value);
    if (count == 0) {
        return false;
    } else if (count == 1 and std.mem.eql(u8, value, allowed_twice)) {
        return false;
    }
    return true;
}

//--------------------------------------------------------------------------------------------------
pub fn attempt_insert(node: *Node, conn: *Connection, allocator: Allocator, visited_in: *Visited, allowed_twice: *const [2:0]u8) bool {
    // Don't attach beyond end nodes
    if (std.mem.eql(u8, node.*.val, "end")) {
        return false;
    }

    var visited = Visited.initCapacity(allocator, visited_in.items.len) catch unreachable;
    defer visited.deinit();
    visited.appendSliceAssumeCapacity(visited_in.items);
    visited.append(node.*.val) catch unreachable;

    // Can it attach to this node?
    if (std.mem.eql(u8, conn.*.a, node.*.val)) {
        if (!node.*.has_child(conn.b)) { // Don't repeat child
            if (!refuse_visit(&visited, conn.b, allowed_twice)) {
                var new_node = allocator.create(Node) catch unreachable;
                new_node.* = Node.init(conn.b);
                node.*.attach(new_node);
                //std.debug.print("visited:{s}", .{visited.items});
                //std.debug.print("->{s}\n", .{new_node.*.val});
                return true;
            }
        }
    } else if (std.mem.eql(u8, conn.*.b, node.*.val)) {
        if (!node.*.has_child(conn.a)) { // Don't repeat child
            if (!refuse_visit(&visited, conn.a, allowed_twice)) {
                var new_node = allocator.create(Node) catch unreachable;
                new_node.* = Node.init(conn.a);
                node.*.attach(new_node);
                //std.debug.print("visited:{s}", .{visited.items});
                //std.debug.print("->{s}\n", .{new_node.*.val});
                return true;
            }
        }
    }

    // Traverse the remainder of the tree looking for a place to insert
    for (node.*.children[0..node.*.child_count]) |child| {
        if (attempt_insert(child, conn, allocator, &visited, allowed_twice)) {
            return true;
        }
    }

    return false;
}

//--------------------------------------------------------------------------------------------------
pub fn print(node: *Node, depth: u32, parent: []const u8) void {
    std.debug.print("({d}){s}->{s}, ", .{ depth, node.*.val, parent });
    if (std.mem.eql(u8, node.*.val, "end")) {
        std.debug.print("\n", .{});
    }
    for (node.*.children[0..node.*.child_count]) |child| {
        print(child, depth + 1, node.*.val);
    }
}

//--------------------------------------------------------------------------------------------------
pub fn print_alt(node: *Node, depth: u32) void {
    std.debug.print("({d}){s}: ", .{ depth, node.*.val });
    for (node.*.children[0..node.*.child_count]) |child| {
        std.debug.print("{s}, ", .{child.*.val});
    }
    std.debug.print("\n", .{});

    for (node.*.children[0..node.*.child_count]) |child| {
        print_alt(child, depth + 1);
    }
}

//--------------------------------------------------------------------------------------------------
pub fn count_paths(node: *Node, count: *u32) void {
    if (std.mem.eql(u8, node.*.val, "end")) {
        count.* += 1;
        return;
    }
    for (node.*.children[0..node.*.child_count]) |child| {
        count_paths(child, count);
    }
}

//--------------------------------------------------------------------------------------------------
pub fn part1() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var buf: [1024]u8 = undefined;
    var buf_size: usize = undefined;
    {
        const file = std.fs.cwd().openFile("data/day12_input.txt", .{}) catch |err| label: {
            std.debug.print("unable to open file: {e}\n", .{err});
            const stderr = std.io.getStdErr();
            break :label stderr;
        };
        defer file.close();
        var reader = std.io.bufferedReader(file.reader());
        var istream = reader.reader();
        buf_size = try istream.readAll(&buf);
    }

    var connections: [23]Connection = undefined;
    {
        var lines = std.mem.tokenize(u8, buf[0..buf_size], "\n");
        var i: usize = 0;
        while (lines.next()) |line| : (i += 1) {
            var nodes = std.mem.tokenize(u8, line, "-");
            connections[i].a = nodes.next().?;
            connections[i].b = nodes.next().?;
            //std.log.info("line:{s}", .{line});
            //std.log.info("connector[{d}] :{s} - {s}", .{ i, connections[i].a, connections[i].b });
        }
    }

    const allowed_twice = [_]*const [2:0]u8{ "yw", "wn", "dc", "ah", "fi", "th" };
    var total_count: u32 = 0;

    for (allowed_twice) |allowed| {
        std.log.info("allowed: {s}", .{allowed});
        var start = try allocator.create(Node);
        start.* = Node.init("start");

        while (true) {
            var was_insertion: bool = false;
            for (connections) |*conn| {
                var visited = Visited.init(allocator);
                defer visited.deinit();
                if (attempt_insert(start, conn, allocator, &visited, allowed)) {
                    was_insertion = true;
                }
            }
            if (!was_insertion) { // exhausted all insertions
                break;
            }
        }
        var count: u32 = 0;
        count_paths(start, &count);
        std.log.info("count: {d}", .{count});
        total_count += count;
    }
    //for (connections) |conn| {
    //    std.log.info("conn: {}", .{conn});
    //}

    std.log.info("Part 2 count: {d}", .{total_count});

    //print_alt(start, 0);
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    try part1();
    //try part2();
}

//--------------------------------------------------------------------------------------------------
