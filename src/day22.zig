//--------------------------------------------------------------------------------------------------
// Features used:
// - File loading and parsing
// - std.mem.tokenize
// - ArrayList with allocator
//--------------------------------------------------------------------------------------------------
const std = @import("std");
const Allocator = std.mem.Allocator;

//--------------------------------------------------------------------------------------------------
const Vec3 = extern union {
    c: [3]i32,
    v: struct {
        x: i32,
        y: i32,
        z: i32,
    },
};

const Box = struct {
    min: Vec3,
    max: Vec3,
    is_on: bool,

    pub fn is_overlapping(self: Box, rhs: Box) bool {
        if (self.max.v.x <= rhs.min.v.x) return false;
        if (self.min.v.x >= rhs.max.v.x) return false;
        if (self.max.v.y <= rhs.min.v.y) return false;
        if (self.min.v.y >= rhs.max.v.y) return false;
        if (self.max.v.z <= rhs.min.v.z) return false;
        if (self.min.v.z >= rhs.max.v.z) return false;
        return true;
    }

    pub fn volume(self: Box) i64 {
        const x: i64 = self.max.v.x - self.min.v.x;
        const y: i64 = self.max.v.y - self.min.v.y;
        const z: i64 = self.max.v.z - self.min.v.z;
        return x * y * z;
    }
};
const Boxes = std.ArrayList(Box);

//--------------------------------------------------------------------------------------------------
// Subtract rhs volume from box
// This is done by splitting up box into pieces that don't overlap with rhs
// NOTE: boxes MUST overlap, otherwise this will fill in gabs between them,
// creating larger boxes than existed before
//--------------------------------------------------------------------------------------------------
pub fn subtract_box(box: Box, rhs: Box, boxes: *Boxes) anyerror!void {

    // Make a copy so we can reduce it's size once we add pieces of it to the list
    var split = box;

    // For each axis
    var i: usize = 0;
    while (i < 3) {
        // Any parts outside of the overlap can be kept
        if (split.min.c[i] < rhs.min.c[i]) {
            var new_box = split;
            new_box.max.c[i] = rhs.min.c[i]; // Everything BEFORE the overlap on this axis
            try boxes.*.append(new_box);

            split.min.c[i] = rhs.min.c[i]; // Shrink to remove the part we just added, so we don't try to add again
        }
        if (split.max.c[i] > rhs.max.c[i]) {
            var new_box = split;
            new_box.min.c[i] = rhs.max.c[i]; // Everything AFTER the overlap on this axis
            try boxes.*.append(new_box);

            split.max.c[i] = rhs.max.c[i];
        }
        i += 1;
    }
}

//--------------------------------------------------------------------------------------------------
pub fn run_steps(input: Boxes, allocator: Allocator, init_range_only: bool) anyerror!void {
    var timer = try std.time.Timer.start();

    // Current set of boxes - start from empty and only add in boxes without overlaps
    // Any overlaps need to be resolved first by splitting the boxes into smaller boxes
    // and adding only the parts that don't duplicate/overlap with other boxes
    var boxes = Boxes.init(allocator);
    defer boxes.deinit();

    for (input.items) |new_box| {
        // Filter out boxes which are not for Part1
        if (init_range_only) {
            if ((try std.math.absInt(new_box.min.v.x)) > 50 or (try std.math.absInt(new_box.min.v.y)) > 50) {
                continue;
            }
        }

        var pieces_being_added = Boxes.init(allocator);
        defer pieces_being_added.deinit();

        // Start with the new box we are trying to add. It will likely get split up
        // into multiple smaller pieces though
        var is_adding = new_box.is_on;
        if (is_adding) {
            try pieces_being_added.append(new_box);
        }

        // Look over all existing boxes for overlaps
        var existing_idx: usize = boxes.items.len;
        while (existing_idx > 0) { // Reverse order because we will remove from the list
            existing_idx -= 1;

            // Adding
            // Split up the NEW box(s) and keep only the non-overlapping pieces
            if (is_adding) {
                // May be adding multiple pieces, if splitting occurred. So need to loop through them
                var new_idx: usize = pieces_being_added.items.len;
                while (new_idx > 0) { // Reverse order because we will remove from the list
                    new_idx -= 1;
                    if (pieces_being_added.items[new_idx].is_overlapping(boxes.items[existing_idx])) {
                        // Remove new box piece, as it will be further broken down
                        var new_piece = pieces_being_added.swapRemove(new_idx);
                        try subtract_box(new_piece, boxes.items[existing_idx], &pieces_being_added);
                    }
                }
            }

            // Subtracting
            // Split up the EXISTING boxes and keep only the non-overlapping pieces
            else {
                if (new_box.is_overlapping(boxes.items[existing_idx])) {
                    var box_to_cut = boxes.swapRemove(existing_idx);
                    try subtract_box(box_to_cut, new_box, &pieces_being_added);
                }
            }
        }

        // Add all the remaining parts
        for (pieces_being_added.items) |p| {
            try boxes.append(p);
        }
    }

    // Results
    var total: i64 = 0;
    for (boxes.items) |b| {
        total += b.volume();
    }
    std.log.info("Boxes.count: {d}:  volume: {d}", .{ boxes.items.len, total });

    std.log.info("Steps Completed in {d:.2}ms", .{@intToFloat(f32, timer.lap()) / 1.0e+6});
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var boxes = Boxes.init(allocator);
    defer boxes.deinit();

    // Parse the input data
    {
        // Read entire file into huge buffer and get a slice to the populated part
        var buffer: [512 * 105]u8 = undefined;
        const buffer_populated = try std.fs.cwd().readFile("data/day22_input.txt", buffer[0..]);
        std.debug.assert(buffer_populated.len < buffer.len); // Otherwise buffer is too small

        //on x=-24..25,y=-36..8,z=-15..31
        //off x=-45..-29,y=-6..12,z=-31..-19
        //
        // Now parse into data structure
        var line_idx: usize = 0;
        var it = std.mem.split(u8, buffer_populated, "\n");
        while (it.next()) |line| {
            line_idx += 1;
            if (line.len == 0) {
                continue;
            }
            std.debug.assert(line[0] == 'o');
            std.debug.assert(line.len > 4);

            const is_on: bool = (line[1] == 'n');
            const box_info_slice = if (is_on) line[3..] else line[4..];
            var box_info = std.mem.tokenize(u8, box_info_slice, ",");

            var box: Box = undefined;
            var i: usize = 0;
            while (box_info.next()) |range| {
                std.debug.assert(i < 3);
                var coords = std.mem.tokenize(u8, range[2..], "..");
                var first = coords.next().?;
                var last = coords.next().?;
                var a = try std.fmt.parseInt(i32, first, 10);
                var b = try std.fmt.parseInt(i32, last, 10);
                box.min.c[i] = std.math.min(a, b);
                box.max.c[i] = std.math.max(a, b);

                // Shift to an exclusive range (rather than inclusive)
                // Makes the math much easier
                box.max.c[i] += 1;
                box.is_on = is_on;
                i += 1;
            }
            try boxes.append(box);
        }
    }
    try run_steps(boxes, allocator, true);
    try run_steps(boxes, allocator, false);
}

//--------------------------------------------------------------------------------------------------

