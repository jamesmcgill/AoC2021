const std = @import("std");

const CaveList = [12]Node;
const HashList = [24]u8;

//--------------------------------------------------------------------------------------------------
const Node = struct {
    name: []const u8,
    hash: u8,
    connection_indices: [6]usize,
    connection_count: u8,
    is_small: bool,

    pub fn init(name: []const u8) Node {
        return Node{ .name = name, .hash = cave_hash(name), .connection_indices = undefined, .connection_count = 0, .is_small = is_small_string(name) };
    }

    pub fn attach(self: *Node, index: usize) void {
        self.connection_indices[self.connection_count] = index;
        self.connection_count += 1;
    }
};

//--------------------------------------------------------------------------------------------------
pub fn is_small_string(value: []const u8) bool {
    return (value[0] >= 'a');
}

//--------------------------------------------------------------------------------------------------
pub fn cave_hash(string: []const u8) u8 {
    if (std.mem.eql(u8, string, "end")) {
        return 0;
    }

    var hash: u8 = string[0];
    hash +%= string[1];
    return hash;
}

//--------------------------------------------------------------------------------------------------
pub fn attempt_add_cave(cave_list: *CaveList, cave_count: *usize, new_cave: []const u8) void {
    const hash = cave_hash(new_cave);
    for (cave_list) |existing| {
        if (existing.hash == hash) {
            return; // already exists
        }
    }

    //std.log.info("adding cave {s} at pos {d}", .{ new_cave, cave_count.* });
    cave_list[cave_count.*] = Node.init(new_cave);
    cave_count.* += 1;
}

//--------------------------------------------------------------------------------------------------
pub fn find_cave_idx(cave_list: CaveList, cave_count: usize, find: []const u8) usize {
    _ = cave_count;

    const hash = cave_hash(find);
    for (cave_list) |existing, idx| {
        if (existing.hash == hash) {
            return idx;
        }
    }
    unreachable;
}

//--------------------------------------------------------------------------------------------------
pub fn count_visits(hash: u8, visited: HashList, visited_count: usize) u8 {
    var count: u8 = 0;
    for (visited[0..visited_count]) |visited_hash| {
        if (visited_hash == hash) {
            count += 1;
        }
    }
    return count;
}

//--------------------------------------------------------------------------------------------------
pub fn attach_cave(cave_list: *CaveList, cave_count: usize, node: []const u8, attachee: []const u8) void {
    const a_idx = find_cave_idx(cave_list.*, cave_count, node);
    const b_idx = find_cave_idx(cave_list.*, cave_count, attachee);
    cave_list[a_idx].attach(b_idx);
}

//--------------------------------------------------------------------------------------------------
pub fn count_paths(node_idx: usize, cave_list: CaveList, cave_count: usize, visited: *HashList, visited_count: *usize, allow_double_visit: u8) u32 {
    const hash = cave_list[node_idx].hash;
    if (hash == 0) { // reached end
        // If double visits are allowed, then only return if double visits occurred. This prevents double counting of combinations without double visits
        if (allow_double_visit != 0) {
            const visit_count = count_visits(allow_double_visit, visited.*, visited_count.*);
            if (visit_count != 2) {
                return 0; // excluded as double visit didn't occur
            }
        }
        return 1;
    }
    visited[visited_count.*] = hash;
    visited_count.* += 1;

    const this_cave = cave_list[node_idx];
    const connection_count = this_cave.connection_count;
    var total: u32 = 0;
    for (this_cave.connection_indices[0..connection_count]) |connection_idx| {
        const next_cave = cave_list[connection_idx];
        const visit_count = count_visits(next_cave.hash, visited.*, visited_count.*);
        const can_visit = (next_cave.is_small == false or visit_count == 0 or (visit_count == 1 and next_cave.hash == allow_double_visit));
        if (can_visit) {
            total += count_paths(connection_idx, cave_list, cave_count, visited, visited_count, allow_double_visit);
        }
    }

    visited_count.* -= 1; // pop visited
    return total;
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
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

    var caves: CaveList = undefined;
    var cave_count: usize = 0;
    {
        var lines = std.mem.tokenize(u8, buf[0..buf_size], "\n");
        var i: usize = 0;
        while (lines.next()) |line| : (i += 1) {
            var nodes = std.mem.tokenize(u8, line, "-");
            var a = nodes.next().?;
            var b = nodes.next().?;
            attempt_add_cave(&caves, &cave_count, a);
            attempt_add_cave(&caves, &cave_count, b);

            attach_cave(&caves, cave_count, a, b);
            attach_cave(&caves, cave_count, b, a);
        }
    }

    const allow_double_visit: u8 = 0; // Magic value that means no cave is allowed to be visited twice
    var visited: HashList = undefined;
    var visited_count: usize = 0;

    const start_idx = find_cave_idx(caves, cave_count, "start");

    const part1_count: u32 = count_paths(start_idx, caves, cave_count, &visited, &visited_count, allow_double_visit);
    std.log.info("Part 1 num_paths: {d}", .{part1_count});

    const allowed_twice = [_]*const [2:0]u8{ "yw", "wn", "dc", "ah", "fi", "th" };
    var part2_count: u32 = part1_count;
    for (allowed_twice) |allowed| {
        const allowed_hash = cave_hash(allowed);
        part2_count += count_paths(start_idx, caves, cave_count, &visited, &visited_count, allowed_hash);
    }
    std.log.info("Part 2 num_paths: {d}", .{part2_count});
}

//--------------------------------------------------------------------------------------------------
