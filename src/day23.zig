//--------------------------------------------------------------------------------------------------
// Features used:
//
// - std.io.getStdOut().writer();
// - IntegerBitSet
// - Hashmap
// - File loading and parsing
//--------------------------------------------------------------------------------------------------
//
// Possible positions:
// 2 left side (l)
// 2 right side (r)
// 3 middle (m)
// 16 rooms (4 rooms * 4 positions) (1,2,3,4)
// 23 total
//
// Bit-layout (24 * 4 = 96)
// 0010 0000 1000 0000 0000 0000 - one in room 4 (bottom pos) and in right side (nearest inner).
// Xrrm mmll 4321 4321 4321 4321
//
// Each amphipod type needs it's own bitfield (A, B, C, D).
// Therefore 96 bits would suffice to encode the entire world state.
//--------------------------------------------------------------------------------------------------
const std = @import("std");
const Allocator = std.mem.Allocator;

//--------------------------------------------------------------------------------------------------
const AMPHIPOD_WIDTH: usize = 24;
const State = std.bit_set.IntegerBitSet(96);
const SeenStates = std.AutoHashMap(u96, u32);

const Possible = struct {
    state: State,
    cost: u32,
};
const Possibles = std.ArrayList(Possible);

const OccupiedInfo = struct {
    amphipod: usize,
    depth: usize,
};

const ToVisit = std.ArrayList(u96);

//--------------------------------------------------------------------------------------------------
pub fn print_state_populated(bit_idx: *usize, state: State, o: anytype, comptime empty: anytype) void {
    var a: u8 = 'A';
    while (a <= 'D') : (a += 1) {
        const amphipod_offset = (a - 'A') * AMPHIPOD_WIDTH;
        if (state.isSet(bit_idx.* + amphipod_offset)) {
            o.*.print("{c}", .{a}) catch unreachable;
            bit_idx.* += 1;
            return;
        }
    }

    o.print(empty, .{}) catch unreachable;
    bit_idx.* += 1;
}

//--------------------------------------------------------------------------------------------------
pub fn print_state(state: State) void {
    var out = std.io.getStdOut().writer(); // can write directly to this
    var buffer = std.io.bufferedWriter(out);
    var o = buffer.writer(); // or with this, but remember to call buffer.flush()

    // Top wall
    o.print("#############\n", .{}) catch unreachable;

    // Hallway
    {
        var bit_idx: usize = 16; // Hallway info starts in second byte
        o.print("#", .{}) catch unreachable;
        var i: usize = 0;
        place: while (i < 11) : (i += 1) {
            std.debug.assert(bit_idx < AMPHIPOD_WIDTH);
            if (i != 0 and i != 10 and (i % 2) != 0) {
                // Skip hallway positions that cannot be occupied
                o.print(".", .{}) catch unreachable;
                continue :place;
            }

            print_state_populated(&bit_idx, state, &o, ".");
        }
        o.print("#\n", .{}) catch unreachable;
    }

    // Rooms (top)
    {
        var bit_idx: usize = 0; // Room info start
        o.print("###", .{}) catch unreachable;
        var i: usize = 0;
        place: while (i < 7) : (i += 1) {
            std.debug.assert(bit_idx < AMPHIPOD_WIDTH);
            // Skip Room positions that cannot be occupied
            if ((i % 2) != 0) {
                o.print("#", .{}) catch unreachable;
                continue :place;
            }
            print_state_populated(&bit_idx, state, &o, "#");
        }
        o.print("###\n", .{}) catch unreachable;
    }

    // Rooms (mid-top)
    {
        var bit_idx: usize = 4; // Room info start
        o.print("###", .{}) catch unreachable;
        var i: usize = 0;
        place: while (i < 7) : (i += 1) {
            std.debug.assert(bit_idx < AMPHIPOD_WIDTH);
            // Skip Room positions that cannot be occupied
            if ((i % 2) != 0) {
                o.print("#", .{}) catch unreachable;
                continue :place;
            }
            print_state_populated(&bit_idx, state, &o, "#");
        }
        o.print("###\n", .{}) catch unreachable;
    }

    // Rooms (mid-bottom)
    {
        var bit_idx: usize = 8; // Room info start
        o.print("  #", .{}) catch unreachable;
        var i: usize = 0;
        place: while (i < 7) : (i += 1) {
            std.debug.assert(bit_idx < AMPHIPOD_WIDTH);
            // Skip Room positions that cannot be occupied
            if ((i % 2) != 0) {
                o.print("#", .{}) catch unreachable;
                continue :place;
            }
            print_state_populated(&bit_idx, state, &o, "#");
        }
        o.print("#\n", .{}) catch unreachable;
    }

    // Rooms (bottom)
    {
        var bit_idx: usize = 12; // Room info start
        o.print("  #", .{}) catch unreachable;
        var i: usize = 0;
        place: while (i < 7) : (i += 1) {
            std.debug.assert(bit_idx < AMPHIPOD_WIDTH);
            // Skip Room positions that cannot be occupied
            if ((i % 2) != 0) {
                o.print("#", .{}) catch unreachable;
                continue :place;
            }
            print_state_populated(&bit_idx, state, &o, "#");
        }
        o.print("#\n", .{}) catch unreachable;
    }

    // Bottom wall
    o.print("  #########\n", .{}) catch unreachable;
    buffer.flush() catch unreachable;
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    var timer = try std.time.Timer.start();

    // Read entire file into huge buffer and get a slice to the populated part
    var buffer: [14 * 7]u8 = undefined;
    const buffer_populated = try std.fs.cwd().readFile("data/day23_input_part2.txt", buffer[0..]);
    std.debug.assert(buffer_populated.len < buffer.len); // Otherwise buffer is too small

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var seen = SeenStates.init(allocator);
    defer seen.deinit();

    var bitfield = State.initEmpty();
    //----------------------------------------------------------------------------------------------
    // Parse the input data
    {
        var room_idx: usize = 0;
        var it = std.mem.tokenize(u8, buffer_populated, "# .\n");
        while (it.next()) |item| {
            if (item.len == 0) {
                continue;
            }
            std.debug.assert(item.len == 1);
            const item_val = @as(u32, item[0]);
            std.debug.assert(item_val >= 'A');
            std.debug.assert(item_val <= 'D');

            const amphipod_offset = (item_val - 'A') * AMPHIPOD_WIDTH;
            const bit_index = amphipod_offset + room_idx;
            bitfield.set(bit_index);
            room_idx += 1;
        }
    }

    try seen.put(bitfield.mask, 0); // initial state costs zero

    var to_visit = ToVisit.init(allocator);
    defer to_visit.deinit();
    try to_visit.append(bitfield.mask);

    while (to_visit.items.len != 0) {
        const visit = to_visit.pop();

        const opt_cost = seen.get(visit);
        if (opt_cost) |cost| {
            var possibles = Possibles.init(allocator);
            defer possibles.deinit();

            calc_possible_moves(visit, cost, &possibles);

            for (possibles.items) |move| {
                const entry = try seen.getOrPut(move.state.mask);
                if (entry.found_existing == false or entry.value_ptr.* > move.cost) {
                    entry.value_ptr.* = move.cost;
                    try to_visit.append(move.state.mask);
                }
            }
        }
    } // while (to_visit.items)

    // Print the final state and move cost
    {
        const desired_mask: u96 = 0x008888_004444_002222_001111;
        const entry = seen.get(desired_mask);
        if (entry) |cost| {
            var final_bits = State.initEmpty();
            final_bits.mask = desired_mask;
            print_state(final_bits);
            std.log.info("Cost: {d}", .{cost});
        }
    }

    std.log.info("Completed in {d:.2}ms", .{@intToFloat(f32, timer.lap()) / 1.0e+6});
}

//--------------------------------------------------------------------------------------------------
pub fn is_hall_occupied(state: u96) bool {
    const hall_mask: u96 = 0xff0000_ff0000_ff0000_ff0000;
    return ((state & hall_mask) != 0);
}

//--------------------------------------------------------------------------------------------------
pub fn is_room_occupied(state: State, room: usize, start_depth: usize, max_depth: usize, ignore_room_types: bool) ?OccupiedInfo {
    var d = start_depth;
    while (d < max_depth) : (d += 1) {
        var i: usize = 0;
        while (i < 4) : (i += 1) // 4 amphipod types
        {
            // Main stride + room depth e.g. 0 and then 4 for the two room A bits
            const room_bit_idx = room + (i * AMPHIPOD_WIDTH) + (d * 4);
            const should_ignore = (ignore_room_types and i == room);
            if (state.isSet(room_bit_idx) and !should_ignore) { // NOTE: ignores amphipods already in correct room
                return OccupiedInfo{ .amphipod = i, .depth = d };
            }
        }
    }
    return null;
}

//--------------------------------------------------------------------------------------------------
pub fn should_move(state: State, bit_idx: usize) bool {
    // Amphipods in the hallway can always move
    // Amphipods in the room only move if they are not in final room and no-one below wants out
    const amphipod = bit_idx / AMPHIPOD_WIDTH;
    const position = bit_idx % AMPHIPOD_WIDTH;

    // in room
    const in_room = (position < 16);
    if (in_room) {
        const room = (position % 4);
        const room_depth = (position / 4);

        const blocked_by_someone = is_room_occupied(state, room, 0, room_depth, false);
        if (blocked_by_someone != null) {
            return false;
        }

        const in_final_room = ((position % 4) == amphipod);
        const blocks_someone = is_room_occupied(state, room, room_depth + 1, 4, true);
        if (in_final_room and (blocks_someone == null)) {
            return false;
        }
    }
    return true;
}

//--------------------------------------------------------------------------------------------------
pub fn is_position_occupied(state: State, bit_idx: usize) bool {
    const position = bit_idx % AMPHIPOD_WIDTH;
    var i: usize = 0;
    while (i < 4) : (i += 1) { // 4 amphipod types (4 bitfield regions to check)
        if (state.isSet((i * AMPHIPOD_WIDTH) + position)) {
            return true;
        }
    }
    return false;
}

//--------------------------------------------------------------------------------------------------
pub fn num_moves_if_possible(state: State, amphipod_type: usize, from_bit_idx: usize, to_bit_idx: usize) u32 {
    const from_position = from_bit_idx % AMPHIPOD_WIDTH;
    const to_position = to_bit_idx % AMPHIPOD_WIDTH;

    // Can only move from hall->room or room->hall, therefore if from_idx
    // is in the first group of bits then to_idx needs to be in the other group of bits
    const from_room = (from_position < 16);
    const to_room = (to_position < 16);
    if (to_room == from_room) {
        return 0;
    }

    var res: u32 = 0;

    // Hall To Room
    if (to_room) {
        // Only move into rooms if
        // 1) that's the final destination i.e. amphipod_type matches room
        // 2) no other amphipod types need to get out the room first
        // 3) lowest available depth of the room + nothing blocking above
        const to_room_type = (to_position % 4);
        const to_room_depth = (to_position / 4);
        const to_final_room = (to_room_type == amphipod_type);

        // Only attempt to move into the final room
        if (!to_final_room) {
            return 0;
        }

        // Another Amphipod type in the room needs to escape first?
        const blocks_someone = is_room_occupied(state, to_room_type, 0, 4, true);
        if (blocks_someone != null) {
            return 0;
        }

        // First available space?
        const first_occuppied_slot = is_room_occupied(state, to_room_type, 0, 4, false);
        if (first_occuppied_slot) |occupied| {
            // We only move into a room if the room is unoccupied
            // Or in the space directly above someone else
            if (occupied.depth != to_room_depth + 1) {
                return 0;
            }
        }

        // If code made it here then amphipod can move here if not blocked in hallway
        res += @intCast(u32, to_room_depth + 1);
    }
    // from_room
    else {
        const from_room_depth = (from_position / 4);
        res += @intCast(u32, from_room_depth + 1);
    }

    // Check if anything in the hallway blocks route and count the steps

    // hall_start is always at room entrance
    // (because we force movement to always be exiting a room and moving into hallway).
    // Hall bits are after the 8 room bits
    // Room0 entrance isn't at hall positon0 (it's between hall indices [1] and [2]). So add 2.
    const room_type = if (from_room) from_position % 4 else to_position % 4;
    const hall_start = 16 + room_type + 2;
    const hall_finish = if (from_room) to_position else from_position;

    // Walk along hall
    if (hall_finish < hall_start) {
        var i: usize = hall_start - 1; // Start on left side of entrance
        while (i >= hall_finish) : (i -= 1) {
            if (i != hall_finish and is_position_occupied(state, i)) { // blockage in between
                return 0;
            }
            res += 1;
            // We compressed the hall data by removing the spaces at room entrances
            // as they cannot be occupied. However when traversing those missing slots
            // we need to count them
            if ((i >= 16 + 2 and i <= 16 + 4) and (i != hall_finish)) {
                res += 1;
            }
        }
    } else {
        var i: usize = hall_start; // Already starts on right side of entrance
        while (i <= hall_finish) : (i += 1) {
            if (i != hall_finish and is_position_occupied(state, i)) { // blockage in between
                return 0;
            }
            res += 1;
            // We compressed the hall data by removing the spaces at room entrances
            // as they cannot be occupied. However when traversing those missing slots
            // we need to count them
            if ((i >= 16 + 2 and i <= 16 + 4) and (i != hall_finish)) {
                res += 1;
            }
        }
    }

    return res;
}

//--------------------------------------------------------------------------------------------------
pub fn calc_possible_moves(state: u96, cost: u32, res: *Possibles) void {
    if (!is_hall_occupied(state) and cost != 0) {
        return; // This state is already in the final position
    }

    var bitfield = State.initEmpty();
    bitfield.mask = state;
    var it = bitfield.iterator(.{});
    while (it.next()) |from_idx| { // only iterates set bits - i.e. amphipods

        if (!should_move(bitfield, from_idx)) {
            continue;
        }

        const amphipod_type = from_idx / AMPHIPOD_WIDTH;
        const energy_cost_per_move = std.math.pow(u32, 10, @intCast(u32, amphipod_type));

        // available places to move
        var to_idx = amphipod_type * AMPHIPOD_WIDTH;
        const end = to_idx + AMPHIPOD_WIDTH - 1; // NOTE: last bit needs excluded, as it's just padding and we are not allowed to move there

        // Empty bits are candidates to move to
        while (to_idx < end) : (to_idx += 1) {
            if (is_position_occupied(bitfield, to_idx)) {
                continue;
            }

            const moves = num_moves_if_possible(bitfield, amphipod_type, from_idx, to_idx);
            if (moves != 0) {
                var new_state = bitfield;
                new_state.unset(from_idx);
                new_state.set(to_idx);

                res.append(Possible{
                    .state = new_state,
                    .cost = cost + (moves * energy_cost_per_move),
                }) catch unreachable;
            }
        }
    }
}

//--------------------------------------------------------------------------------------------------

