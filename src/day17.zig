const std = @import("std");
const Allocator = std.mem.Allocator;

// Group together hits on the target by the number of steps it took
const InitialVelocities = std.ArrayList(i32);
const StepsToVelocityCount = std.AutoHashMap(u32, InitialVelocities);

//--------------------------------------------------------------------------------------------------
pub fn stepsToPeak(velocity: i32) u32 {
    var vel = velocity;
    var count: u32 = 0;
    while (vel > 0) : (vel -= 1) {
        count += 1;
    }
    return count;
}

//--------------------------------------------------------------------------------------------------
pub fn combinations(target_1: i32, target_2: i32, velocity_delta: i32, hits_per_step: *StepsToVelocityCount, allocator: *Allocator) void {
    // HACK 1
    const is_y_axis: bool = (velocity_delta == 1);

    // Similar to Part 1, start with largest velocity and try smaller ones
    // Largest velocity would take one step from S to furthest edge of target

    // NOTE: this works for Y velocity because we can effectively  ignore
    // the period when the projectile is in the air (above S). Due to symmetry
    // of the arc, gravity will pull it eventually back on the plane of S.
    // At this point the velocity is the inverse of the intial velocity (+1).
    // BUT we need to remember that we removed those initial steps.

    // This whole function assumes everything is in positive space
    // Therefore everything should be moved into space and gravity should fall UP.
    // This is except for the is_y_axis branch, which will factor in cases where it should
    // be inverted into negative space
    var x = target_2;
    while (x >= 0) : (x -= 1) { // rest of possible positions/velocities between S and target edge
        const initial_velocity = x;

        var velocity = initial_velocity;
        var next_x = x;
        var num_steps: u32 = 1;

        while (next_x <= target_2 and velocity >= 0) {
            const hack: i32 = if (velocity == 0) 10000 else 0; // HACK 2

            if (next_x >= target_1) {
                // Direct version
                {
                    const counts = hits_per_step.getOrPut(num_steps) catch unreachable;
                    if (!counts.found_existing) {
                        counts.value_ptr.* = InitialVelocities.init(allocator.*);
                    }

                    if (is_y_axis) { // HACK 1: we will have inverted the input in this case, so need to invert the output
                        counts.value_ptr.*.append(-initial_velocity + hack) catch unreachable;
                    } else {
                        counts.value_ptr.*.append(initial_velocity + hack) catch unreachable;
                    }
                }

                // Duplicate version where it went up in an arc before coming back down
                // This version will have more steps and inverted initial_velocity
                if (is_y_axis) {
                    // When doing the Y steps we ignored the initial arc steps, need to add them
                    const alt_num_steps = num_steps + (stepsToPeak(initial_velocity) * 2);
                    const counts = hits_per_step.getOrPut(alt_num_steps) catch unreachable;
                    if (!counts.found_existing) {
                        counts.value_ptr.* = InitialVelocities.init(allocator.*);
                    }
                    // NOTE: in the inverted case, because initial_velocity represents the
                    // first downward segment, however the real initial velocity will be
                    // the same as the segment just before it, and therefore will be ONE
                    // smaller due having less gravitational acceleration.
                    counts.value_ptr.*.append(initial_velocity - 1 + hack) catch unreachable; // Doubly INVERTED so it's cancelled out
                }
            }
            velocity += velocity_delta;
            next_x += velocity;
            num_steps += 1;
        }
    }
}

//--------------------------------------------------------------------------------------------------
const Pair = struct {
    x: i32,
    y: i32,
};

//--------------------------------------------------------------------------------------------------
pub fn num_overlaps(x_hits: StepsToVelocityCount, y_hits: StepsToVelocityCount, allocator: *Allocator) u32 {
    // Used to deduplicate matched pairs
    var pairs = std.ArrayList(Pair).init(allocator.*);
    defer pairs.deinit();

    // Find all matching steps (matching keys)
    // E.g. when it took 5 steps in the X direction to make a hit, this can only be matched
    // to other occassions it took 5 steps in the Y direction too.

    // EXCEPT: that we terminate counting for X when it's velocity reaches zero
    // However all steps after that should be considered as potential hits. I.e. it could
    // stop directly above, but requires more Y steps down until it hits
    // ONLY do that when velocity reaches zero, and never otherwise as:
    // if x jumps 30 in first step
    // we cannot say all steps afterward may be hits, because the next step will put it at 59!!!
    // we can only consider the x_steps greater than, when the velocity was 0 when it hit

    var y_it = y_hits.iterator();
    while (y_it.next()) |y_kv| {
        const y_steps = y_kv.key_ptr.*;

        var x_it = x_hits.iterator();
        while (x_it.next()) |x_kv| {
            const x_steps = x_kv.key_ptr.*;

            if (y_steps >= x_steps) { // consider all x_steps after they hit. BUT: filter out non-HACKed ones

                for (x_kv.value_ptr.*.items) |hacked_x| {
                    // HACK, HACK
                    const is_hacked = (hacked_x > 5000);
                    const x = if (is_hacked) hacked_x - 10000 else hacked_x;
                    if (!is_hacked and y_steps != x_steps) {
                        continue;
                    } // HACK, HACK

                    for (y_kv.value_ptr.*.items) |y| {
                        const pair = Pair{ .x = x, .y = y };
                        const exists: bool = for (pairs.items) |p| {
                            if (p.x == pair.x and p.y == pair.y) {
                                break true;
                            }
                        } else false;

                        if (!exists) {
                            pairs.append(pair) catch unreachable;
                            //std.log.info("{d} => Pair: ({d}, {d})", .{ y_steps, pair.x, pair.y });
                        }
                    }
                }
            }
        }
    }
    return @intCast(u32, pairs.items.len);
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    var timer = try std.time.Timer.start();

    // Input: target area: x=241..275, y=-75..-49
    const target_x1: i32 = 241;
    const target_x2: i32 = 275;
    const target_y1: i32 = -49;
    const target_y2: i32 = -75;

    // Part 1
    {
        // Consider only linear Y values
        // Largest height means largest velocity when reaching target area
        // Absolute largest velocity would be one that ends with a single step
        // from S to the bottom of the target area.
        // (from S, because it always returns to Sy on the way down. symmetrical up and down)
        const biggest_last_step = 0 - target_y2; // S(0) -> y2
        var velocity_y = biggest_last_step;

        var y = target_y2;
        while (velocity_y > 0) : (velocity_y -= 1) {
            y += velocity_y;
        }
        std.log.info("Part 1: Highest y: {d}", .{y});
    }

    // Part 2
    {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        var allocator = arena.allocator();

        var x_initial_velocities = StepsToVelocityCount.init(allocator);
        defer x_initial_velocities.deinit();

        var y_initial_velocities = StepsToVelocityCount.init(allocator);
        defer y_initial_velocities.deinit();

        combinations(target_x1, target_x2, -1, &x_initial_velocities, &allocator);
        combinations(-target_y1, -target_y2, 1, &y_initial_velocities, &allocator);
        var total = num_overlaps(x_initial_velocities, y_initial_velocities, &allocator);

        std.log.info("Part 2: Final value: {d}", .{total});
    }

    std.log.info("Completed in {d:.2}ms", .{@intToFloat(f32, timer.lap()) / 1.0e+6});
}

//--------------------------------------------------------------------------------------------------

