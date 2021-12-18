const std = @import("std");
const Rules = [100][3]u8;
const RulesSlice = [][3]u8;
const Counts = ['Z' - 'A' + 1]u64;
const Allocator = std.mem.Allocator;

//--------------------------------------------------------------------------------------------------
pub fn grow_pair(pair: [2]u8, rules: RulesSlice, l: *[2]u8, r: *[2]u8) void {
    for (rules) |rule| {
        if (rule[0] == pair[0] and rule[1] == pair[1]) {
            l[0] = pair[0];
            l[1] = rule[2];

            r[0] = rule[2];
            r[1] = pair[1];
            return;
        }
    }
}
//--------------------------------------------------------------------------------------------------
pub fn grow_recursive(pair: [2]u8, depth: u8, rules: RulesSlice, counts: *Counts) void {
    // Count only the first character of every pair.
    // This is because the second character will also appear (as duplicate) in the next pair
    // The only issue with doing this, is that the second character at the very end will not be counted.
    // However it will be same as the last character at the beginning
    if (depth == 0) {
        counts[pair[0] - 'A'] += 1;
        //std.log.info("({d}): LEAF: {s}", .{ depth, pair });
        return;
    }

    var l: [2]u8 = undefined;
    var r: [2]u8 = undefined;
    grow_pair(pair, rules, &l, &r);
    //std.log.info("({d}): grow: {s} -> {s}:{s}", .{ depth, pair, l, r });

    grow_recursive(l, depth - 1, rules, counts);
    grow_recursive(r, depth - 1, rules, counts);
}

//--------------------------------------------------------------------------------------------------
pub fn count_difference_after_steps(steps: u8, template: []u8, rules: RulesSlice, counts: *Counts) u64 {
    std.log.info("Calculating...", .{});
    var pair: [2]u8 = undefined;
    var i: usize = 1;
    while (i < template.len) : (i += 1) {
        //std.log.info("i: {d}", .{i});
        pair[0] = template[i - 1];
        pair[1] = template[i];
        grow_recursive(pair, steps, rules, counts);
    }
    counts[template[template.len - 1] - 'A'] += 1; // Manually count the last character (as we missed it during recursion)
    std.log.info("Counting...", .{});

    var min: u64 = std.math.maxInt(u64);
    var max: u64 = 0;
    var total: u64 = 0;
    for (counts) |count| {
        if (count == 0) {
            continue;
        }
        min = std.math.min(count, min);
        max = std.math.max(count, max);
        total += count;
    }

    // After 10 steps, 1 pair would expand to 1025. (2^n + 1)
    const expected_total: usize = ((template.len - 1) * (std.math.pow(usize, 2, steps))) + 1;
    std.log.info("Total difference: {d}  ({d} - {d}) : Total: {d}/{d}", .{ max - min, max, min, total, expected_total });

    return max - min;
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    const file = std.fs.cwd().openFile("data/day14_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    var counts: Counts = undefined;
    for (counts) |*c| {
        c.* = 0;
    }

    var rules: Rules = undefined;
    var rule_count: usize = 0;

    var template: [20]u8 = undefined;
    var template_count: usize = 0;
    {
        var reader = std.io.bufferedReader(file.reader());
        var istream = reader.reader();
        var buf: [20]u8 = undefined;

        // Read template
        const template_slice = try istream.readUntilDelimiterOrEof(&template, '\n');
        template_count = template_slice.?.len;
        // Read insertion rules
        while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            if (line.len == 0) {
                continue;
            }
            var it = std.mem.split(u8, line, " -> ");
            const rule = it.next().?;
            //std.log.info("rule: {c}", .{rule});
            const insertion = it.next().?;
            //std.log.info("insertion: {c}", .{insertion});
            rules[rule_count][0] = rule[0];
            rules[rule_count][1] = rule[1];
            rules[rule_count][2] = insertion[0];
            rule_count += 1;
        }
    }
    //std.log.info("template: {c}", .{template});
    //std.log.info("rules: {c}", .{rules});

    const part1_diff = count_difference_after_steps(10, template[0..template_count], rules[0..rule_count], &counts);
    std.log.info("Part 1: {d}", .{part1_diff});
    //std.log.info("counts: {d}", .{counts});

    // Part 2
    for (counts) |*c| {
        c.* = 0;
    }
    //const part2_diff = count_difference_after_steps(40, template[0..template_count], rules[0..rule_count], &counts);
    //std.log.info("Part 2: {d}", .{part2_diff});
}

//--------------------------------------------------------------------------------------------------
