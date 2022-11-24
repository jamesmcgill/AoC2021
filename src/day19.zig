//--------------------------------------------------------------------------------------------------
// Features used:
// - Bit packing (Vec3 -> hashmap_key)
// - Combinations and permutations (24 coordinate axis orientations)
// - Hashmap
// - ArrayList with allocator
// - File loading and parsing
//--------------------------------------------------------------------------------------------------
const std = @import("std");
const Allocator = std.mem.Allocator;

//--------------------------------------------------------------------------------------------------
const Vec3 = struct {
    x: i16,
    y: i16,
    z: i16,
};
const Variant = std.ArrayList(Vec3); // A permutation of a scanner (list of probe positions)
const Scanner = std.ArrayList(Variant); // All the permutations for a scanner

const MatchCounts = std.AutoHashMap(u64, u8);

const RelativeOffsets = struct {
    variant_idx: usize,
    offset: Vec3,
};
const ScannerToOffsets = std.AutoHashMap(usize, RelativeOffsets);

const Results = std.AutoHashMap(u64, u8);

//--------------------------------------------------------------------------------------------------
pub fn generate_variants(source: Vec3, dest: *Scanner) anyerror!void {
    std.debug.assert(dest.*.items.len == 24);

    var v = Vec3{
        .x = source.x,
        .y = source.y,
        .z = source.z,
    };

    for (dest.*.items) |*dest_variant, i| {
        if (i == 0) {
            continue; // This is the source, not the destination
        }
        // Perform permutations. Shift left each time.
        var tmp = v.x;
        v.x = v.y;
        v.y = v.z;
        v.z = tmp;

        // Half way point -> Negative X range. Y begins negated (positive value)
        if (i % 12 == 0) {
            v.x = -v.x;
            v.y = -v.y;
        }
        // Every third one -> Negate Y and THEN swap with Z
        else if (i % 3 == 0) {
            tmp = v.z;
            v.z = -v.y;
            v.y = tmp;
        }
        try dest_variant.*.append(v);
    }
}

//--------------------------------------------------------------------------------------------------
// Looks for overlaps between 2 scanners (between 2 specific variants)
// If they appear to be overlapping then return the offset between them.
//--------------------------------------------------------------------------------------------------
pub fn find_offset_between_variants(lhs: Variant, rhs: Variant, allocator: Allocator) ?Vec3 {
    var matches = MatchCounts.init(allocator);
    defer matches.deinit();

    // Compare all positions between the 2 variants
    for (lhs.items) |v1_pos| {
        for (rhs.items) |v2_pos| {
            var offset = Vec3{
                .x = v1_pos.x - v2_pos.x,
                .y = v1_pos.y - v2_pos.y,
                .z = v1_pos.z - v2_pos.z,
            };
            // Put the offsets into a hashmap
            // Use the hashmap to keep count of probes with same offset
            const x_shift: u64 = @intCast(u64, @bitCast(u16, offset.x)) << 32;
            const y_shift: u64 = @intCast(u64, @bitCast(u16, offset.y)) << 16;
            const offset_hash: u64 = x_shift | y_shift | @bitCast(u16, offset.z);

            const match = matches.getOrPut(offset_hash) catch unreachable;
            if (!match.found_existing) {
                match.value_ptr.* = 1; // Init the first match
            } else {
                match.value_ptr.* += 1;

                // Reached a sufficient number of matches to say that the variants overlap
                if (match.value_ptr.* >= 12) {
                    return offset;
                }
            }
        } // for rhs.items
    } // for lhs.items

    return null; // Not enough matches were found
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    var timer = try std.time.Timer.start();

    // Read entire file into huge buffer and get a slice to the populated part
    var buffer: [18 * 700]u8 = undefined;
    const buffer_populated = try std.fs.cwd().readFile("data/day19_input.txt", buffer[0..]);
    std.debug.assert(buffer_populated.len < buffer.len); // Otherwise buffer is too small

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var scanners = std.ArrayList(Scanner).init(allocator);
    defer {
        for (scanners.items) |scanner| {
            for (scanner.items) |variant| {
                variant.deinit();
            }
            scanner.deinit();
        }
        scanners.deinit();
    }

    // Split into lines
    var lines = std.ArrayList([]const u8).init(allocator);
    defer lines.deinit();
    {
        var it = std.mem.split(u8, buffer_populated, "\n");
        while (it.next()) |line| {
            if (line.len > 0) {
                if (line[0] == '-' and line[1] == '-') {
                    // New scanner
                    var scanner = Scanner.init(allocator);
                    const variant = Variant.init(allocator);
                    try scanner.append(variant);
                    try scanners.append(scanner);
                    continue;
                }

                // New position
                var line_it = std.mem.split(u8, line, ",");
                const x = line_it.next() orelse "0";
                const y = line_it.next() orelse "0";
                const z = line_it.next() orelse "0";
                const v = Vec3{
                    .x = std.fmt.parseInt(i16, x, 10) catch 0,
                    .y = std.fmt.parseInt(i16, y, 10) catch 0,
                    .z = std.fmt.parseInt(i16, z, 10) catch 0,
                };

                var lastScanner = &scanners.items[scanners.items.len - 1];
                var lastVariant = &(lastScanner.*.items[lastScanner.*.items.len - 1]);
                try lastVariant.*.append(v);
            }
        }
    }

    // Generate 24 variants for every 1 scanner
    // Explodes the memory, but makes the comparison code later much simpler
    // Essentially the 24 variants represent all possible orientations.
    // Each variant contains the positions of all the probes after they were transformed.
    // One of the variants will be in the same orientation as scanner 0.
    // That variant will have overlaps with other scanners in the same coordinate frame.
    // Essentially this problem boils down to finding the variants which are in scanner 0's
    // coordiante space.
    outer: for (scanners.items) |*source_scanner, idx| {
        // Scanner 0 is the baseline and thus already in absolute coordinates
        if (idx == 0) {
            // skip to next scanner
            continue :outer;
        }

        // Generate 23 new scanners from this one
        // All memory needed upfront because we generating 23 simultaneously
        // I.e one position generates 23 positions each time
        {
            var i: usize = 0;
            while (i < 23) {
                var dest_variant = Variant.init(allocator);
                try source_scanner.*.append(dest_variant);
                i += 1;
            }
        }

        for (source_scanner.items[0].items) |source_pos| {
            try generate_variants(source_pos, source_scanner);
        }
    } // outer

    //----------------------------------------------------------------------------------------------
    // Look for overlaps
    //
    // Idea is to add scanners which are resolved into the coordinate system of scanner 0 first.
    // And then do multiple passes to see if any of these resolved scanners have overlaps with
    // other scanners. Resolve those into the same coordinate space and then add them.
    //----------------------------------------------------------------------------------------------
    var offsets = Variant.init(allocator);
    defer offsets.deinit();

    var result = Results.init(allocator);
    defer result.deinit();

    var resolved_scanners = ScannerToOffsets.init(allocator);
    defer resolved_scanners.deinit();

    // Add scanner 0 explicitly. It is already resolved
    try resolved_scanners.put(0, .{
        .offset = Vec3{
            .x = 0,
            .y = 0,
            .z = 0,
        },
        .variant_idx = 0,
    });

    var more_to_resolve = true;
    while (more_to_resolve) {
        more_to_resolve = false;

        // Look through the currently resolved scanners
        var it = resolved_scanners.iterator();
        while (it.next()) |m_kv| {
            const resolved_idx = m_kv.key_ptr.*;
            const resolved_variant_idx = m_kv.value_ptr.*.variant_idx;
            const resolved_offset = m_kv.value_ptr.*.offset;

            // Look for an unresolved scanner that is linked to this one
            scanners_check: for (scanners.items) |scanner, scanner_idx| {
                if (resolved_idx == scanner_idx) {
                    continue;
                }
                if (resolved_scanners.contains(scanner_idx)) {
                    continue;
                }

                // Check single (resolved) variant of one scanner against all variants of other scanner
                const resolved_variant = scanners.items[resolved_idx].items[resolved_variant_idx];

                for (scanner.items) |variant, variant_idx| {
                    // Check for overlaps
                    if (find_offset_between_variants(resolved_variant, variant, allocator)) |offset| {
                        // If overlap found then put in coordinate frame of first scanner and add
                        try resolved_scanners.put(scanner_idx, .{
                            .offset = Vec3{
                                .x = offset.x + resolved_offset.x,
                                .y = offset.y + resolved_offset.y,
                                .z = offset.z + resolved_offset.z,
                            },
                            .variant_idx = variant_idx,
                        });
                        more_to_resolve = true;
                        continue :scanners_check;
                    }
                } // for variants

            } // for scanners
        } // for resolved scanners
    } // while (more_to_resolve)

    //----------------------------------------------------------------------------------------------
    // Build results
    //----------------------------------------------------------------------------------------------
    var max_dist: i32 = std.math.minInt(i32);
    var min_dist: i32 = std.math.maxInt(i32);
    for (scanners.items) |scanner, scanner_idx| { // To get the scanner_idx for logging
        // Look up in hashmap
        if (resolved_scanners.getPtr(scanner_idx)) |resolved_scanner| {
            const offset = resolved_scanner.offset;
            const variant_idx = resolved_scanner.*.variant_idx;
            std.log.info("Scanner:{d}  - offset {d},{d},{d} - variant {d}", .{ scanner_idx, offset.x, offset.y, offset.z, variant_idx });
            const dist = offset.x + offset.y + offset.z;
            if (dist > max_dist) {
                max_dist = dist;
            }
            if (dist < min_dist) {
                min_dist = dist;
            }

            // Add ALL probe positions from the scanner
            for (scanner.items[variant_idx].items) |v| {
                const x_shift: u64 = @intCast(u64, @bitCast(u16, v.x + offset.x)) << 32;
                const y_shift: u64 = @intCast(u64, @bitCast(u16, v.y + offset.y)) << 16;
                const hashed_v: u64 = x_shift | y_shift | @bitCast(u16, v.z + offset.z);
                try result.put(hashed_v, 0);
            }
        }
    }

    std.log.info("Probe count {d}", .{result.count()});
    std.log.info("Largest distance {d}", .{max_dist - min_dist});

    std.log.info("Completed in {d:.2}ms", .{@intToFloat(f32, timer.lap()) / 1.0e+6});
}

//--------------------------------------------------------------------------------------------------

