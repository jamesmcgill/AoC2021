const std = @import("std");
const Allocator = std.mem.Allocator;

//--------------------------------------------------------------------------------------------------
const NonLeaf = struct {
    left_idx: usize,
    right_idx: usize,
};
const NodeTag = enum { value, nonLeaf };
const Node = union(NodeTag) {
    value: u32,
    nonLeaf: NonLeaf,
};

//--------------------------------------------------------------------------------------------------
pub fn addNode(new_node: Node, nodes: *std.ArrayList(Node), parent_nodes: *std.ArrayList(usize), left_side: *bool) void {
    nodes.append(new_node) catch unreachable;
    const new_idx = nodes.items.len - 1;

    // Parent node (if any) should point to the newly created node
    if (parent_nodes.items.len > 0) {
        const parent_idx = parent_nodes.items[parent_nodes.items.len - 1];
        var parent_node = &nodes.items[parent_idx];
        std.debug.assert(parent_node.* == .nonLeaf);

        if (left_side.*) {
            // std.log.info("parent({d} -> L child{d}", .{ parent_idx, new_idx });
            parent_node.*.nonLeaf.left_idx = new_idx;
        } else {
            // std.log.info("parent({d} -> R child{d}", .{ parent_idx, new_idx });
            parent_node.*.nonLeaf.right_idx = new_idx;
        }
    }

    if (new_node == .nonLeaf) {
        // std.log.info("push parent: {d}", .{new_idx});
        parent_nodes.append(new_idx) catch unreachable;
    }
}

//--------------------------------------------------------------------------------------------------
pub fn parseChar(char: u8, nodes: *std.ArrayList(Node), parent_nodes: *std.ArrayList(usize), left_side: *bool) void {
    switch (char) {
        '[' => {
            const new_node = Node{ .nonLeaf = NonLeaf{ .left_idx = 9999, .right_idx = 9999 } };
            addNode(new_node, nodes, parent_nodes, left_side);
            left_side.* = true;
            // std.log.info("push", .{});
        },

        ']' => {
            std.debug.assert(parent_nodes.items.len > 0);
            _ = parent_nodes.pop();
            // std.log.info("pop", .{});
        },

        ',' => {
            // std.log.info("go r", .{});
            left_side.* = false;
        },

        '0'...'9' => {
            const value: u32 = switch (char) {
                '0' => 0,
                '1' => 1,
                '2' => 2,
                '3' => 3,
                '4' => 4,
                '5' => 5,
                '6' => 6,
                '7' => 7,
                '8' => 8,
                '9' => 9,
                else => unreachable,
            };
            std.debug.assert(value < 10);

            const new_node = Node{ .value = value };
            addNode(new_node, nodes, parent_nodes, left_side);
            // std.log.info("push: {d}", .{value});
        },

        else => unreachable,
    }
}

//--------------------------------------------------------------------------------------------------
pub fn calculateMagnitude(nodes: *const std.ArrayList(Node), idx: usize) u32 {
    std.debug.assert(idx < nodes.items.len);
    const node = nodes.items[idx];

    if (node == .value) {
        // std.log.info("Return: {d}", .{node.value});
        return node.value;
    }
    std.debug.assert(node == .nonLeaf);

    const left_idx = node.nonLeaf.left_idx;
    const right_idx = node.nonLeaf.right_idx;
    std.debug.assert(left_idx < nodes.items.len);
    std.debug.assert(right_idx < nodes.items.len);
    // std.log.info("left:{d} - right:{d}", .{ left_idx, right_idx });

    return (3 * calculateMagnitude(nodes, left_idx)) + (2 * calculateMagnitude(nodes, right_idx));
}

//--------------------------------------------------------------------------------------------------
pub fn print(nodes: *const std.ArrayList(Node), head_idx: usize, allocator: Allocator) void {
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    print_imp(nodes, head_idx, &buffer);
    std.log.info("{s}", .{buffer.items});
}

//--------------------------------------------------------------------------------------------------
pub fn print_imp(nodes: *const std.ArrayList(Node), idx: usize, buffer: *std.ArrayList(u8)) void {
    std.debug.assert(idx < nodes.items.len);
    const node = nodes.items[idx];

    if (node == .value) {
        buffer.writer().print("{d}", .{node.value}) catch unreachable;
        return;
    }
    std.debug.assert(node == .nonLeaf);

    const left_idx = node.nonLeaf.left_idx;
    const right_idx = node.nonLeaf.right_idx;
    std.debug.assert(left_idx < nodes.items.len);
    std.debug.assert(right_idx < nodes.items.len);

    buffer.append('[') catch unreachable;
    print_imp(nodes, left_idx, buffer);

    buffer.append(',') catch unreachable;
    print_imp(nodes, right_idx, buffer);

    buffer.append(']') catch unreachable;
}

//--------------------------------------------------------------------------------------------------
pub fn explode(nodes: *const std.ArrayList(Node), idx: usize, prev_value_idx: *?usize, value_to_add: *?u32, depth: u32) bool {
    std.debug.assert(idx < nodes.items.len);
    var node = nodes.items[idx];

    if (node == .value) {
        // This optional is only set when we are in the second phase
        // of exploding. I.e. after pair was discovered and left side added
        if (value_to_add.*) |val| {
            // std.log.info("EXPLODE: depth:{d}, idx:{d} val:{d}+{d}", .{ depth, idx, node.value, val });
            nodes.items[idx].value += val;
            return true; // Discontinue - Finished exploding
        }

        // Keep track of the last value found, so we can quickly explode left
        prev_value_idx.* = idx;
        return false; // Continue
    }
    std.debug.assert(node == .nonLeaf);

    const left_idx = node.nonLeaf.left_idx;
    const right_idx = node.nonLeaf.right_idx;
    std.debug.assert(left_idx < nodes.items.len);
    std.debug.assert(right_idx < nodes.items.len);
    const left_node = nodes.items[left_idx];
    const right_node = nodes.items[right_idx];

    if (value_to_add.* == null and depth > 3 and left_node == .value and right_node == .value) {
        // std.log.info("EXPLODE: idx:{d},  depth:{d}, add_left:{d}, add_right{d}", .{ idx, depth, left_node.value, right_node.value });
        // Explode
        // Add to last value (if any)
        if (prev_value_idx.*) |prev| {
            nodes.items[prev].value += left_node.value;
        }

        // Add to next value (if any)
        // This is done by continuing the current recursion and moving into a Second stage
        value_to_add.* = right_node.value;

        // Kill the pair and turn the parent into a value node (ZERO)
        nodes.items[idx] = Node{ .value = 0 };

        return false; // Continue - BUT don't explode anymore, now we are in Second stage
    }

    if (explode(nodes, left_idx, prev_value_idx, value_to_add, depth + 1)) {
        return true; // Discontinue
    }
    return explode(nodes, right_idx, prev_value_idx, value_to_add, depth + 1);
}

//--------------------------------------------------------------------------------------------------
pub fn split(nodes: *std.ArrayList(Node), idx: usize) bool {
    std.debug.assert(idx < nodes.items.len);
    var node = nodes.items[idx];

    if (node == .value) {
        if (node.value > 9) {
            const l_val = std.math.divFloor(u32, node.value, 2) catch unreachable;
            const r_val = std.math.divCeil(u32, node.value, 2) catch unreachable;

            // create 2 new nodes for the split
            nodes.append(Node{ .value = l_val }) catch unreachable;
            const left_idx = nodes.items.len - 1;

            nodes.append(Node{ .value = r_val }) catch unreachable;
            const right_idx = nodes.items.len - 1;

            // convert this node into their parent
            const new_node = Node{ .nonLeaf = NonLeaf{ .left_idx = left_idx, .right_idx = right_idx } };
            nodes.items[idx] = new_node;

            return true; // Discontinue (finished split)
        }
        return false; // Pop and continue
    }

    // Recursion
    std.debug.assert(node == .nonLeaf);

    const left_idx = node.nonLeaf.left_idx;
    const right_idx = node.nonLeaf.right_idx;
    std.debug.assert(left_idx < nodes.items.len);
    std.debug.assert(right_idx < nodes.items.len);

    if (split(nodes, left_idx)) {
        return true; // Discontinue
    }
    return split(nodes, right_idx);
}

//--------------------------------------------------------------------------------------------------
pub fn sum_numbers(nodes: *std.ArrayList(Node), head_left: usize, head_right: usize) usize {
    std.debug.assert(head_left < nodes.items.len);
    std.debug.assert(head_right < nodes.items.len);

    // Addition is achieved by creating a new parent node and making the existing numbers
    // children of it
    const new_node = Node{ .nonLeaf = NonLeaf{ .left_idx = head_left, .right_idx = head_right } };
    nodes.append(new_node) catch unreachable;
    return nodes.items.len - 1;
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    var timer = try std.time.Timer.start();

    // Read entire file into huge buffer and get a slice to the populated part
    var buffer: [64 * 100]u8 = undefined;
    const buffer_populated = try std.fs.cwd().readFile("data/day18_input.txt", buffer[0..]);
    std.debug.assert(buffer_populated.len < buffer.len); // Otherwise buffer is too small

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    // Split into lines
    var lines = std.ArrayList([]const u8).init(allocator);
    defer lines.deinit();
    {
        var it = std.mem.split(u8, buffer_populated, "\n");
        while (it.next()) |line| {
            if (line.len > 0) {
                try lines.append(line);
            }
        }
        // std.log.info("Number of lines read: {d}", .{lines.items.len});
        // for (lines.items) |line| {
        //     std.log.info("{s}", .{line});
        // }
    }

    // Part 1
    {
        var nodes = std.ArrayList(Node).init(allocator);
        defer nodes.deinit();
        var current_root: usize = 0;
        {
            // Read line by line
            for (lines.items) |line| {
                var parent_nodes = std.ArrayList(usize).init(allocator);
                defer parent_nodes.deinit();

                var left_side: bool = true;
                var next_root: usize = nodes.items.len;

                // Read char by char to create a number (tree)
                for (line) |char| {
                    parseChar(char, &nodes, &parent_nodes, &left_side);
                }

                // Do addition with previous number (if any)
                if (current_root != next_root) {
                    current_root = sum_numbers(&nodes, current_root, next_root);

                    // Reduce
                    while (true) {
                        var prev_idx: ?usize = null;
                        var add_val: ?u32 = null;
                        if (explode(&nodes, current_root, &prev_idx, &add_val, 0)) {
                            continue;
                        }
                        if (split(&nodes, current_root)) {
                            continue;
                        }
                        break; // no work performed, time to escape
                    }
                }
            }
        }
        print(&nodes, current_root, allocator);
        const mag = calculateMagnitude(&nodes, current_root);
        std.log.info("Part 1: Magnitude: {d}", .{mag});
    }

    // Part 2
    {
        var max_mag: u32 = 0;

        const line_count = lines.items.len;
        var first: usize = 0;
        while (first < line_count) : (first += 1) {
            var second: usize = 0;
            while (second < line_count) : (second += 1) {
                if (first == second) {
                    continue;
                }
                var nodes = std.ArrayList(Node).init(allocator);
                defer nodes.deinit();

                const first_root = nodes.items.len;
                // Parse first
                {
                    var parent_nodes = std.ArrayList(usize).init(allocator);
                    defer parent_nodes.deinit();
                    var left_side: bool = true;
                    for (lines.items[first]) |char| {
                        parseChar(char, &nodes, &parent_nodes, &left_side);
                    }
                }
                const second_root = nodes.items.len;
                // Parse second
                {
                    var parent_nodes = std.ArrayList(usize).init(allocator);
                    defer parent_nodes.deinit();
                    var left_side: bool = true;
                    for (lines.items[second]) |char| {
                        parseChar(char, &nodes, &parent_nodes, &left_side);
                    }
                }

                // Do addition
                const sum_root = sum_numbers(&nodes, first_root, second_root);

                // Reduce
                while (true) {
                    var prev_idx: ?usize = null;
                    var add_val: ?u32 = null;
                    if (explode(&nodes, sum_root, &prev_idx, &add_val, 0)) {
                        continue;
                    }
                    if (split(&nodes, sum_root)) {
                        continue;
                    }
                    break; // no work performed, time to escape
                }
                const mag = calculateMagnitude(&nodes, sum_root);
                if (mag > max_mag) {
                    max_mag = mag;
                }
            }
        }

        std.log.info("Part 2: Max magnitude: {d}", .{max_mag});
    }

    std.log.info("Completed in {d:.2}ms", .{@intToFloat(f32, timer.lap()) / 1.0e+6});
}

//--------------------------------------------------------------------------------------------------

