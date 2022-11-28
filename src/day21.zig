const std = @import("std");

const State = struct {
    pos_1: u8,
    pos_2: u8,
    score_1: u8,
    score_2: u8,
};
const Results = struct {
    p1_wins: u64,
    p2_wins: u64,
};

//--------------------------------------------------------------------------------------------------
pub fn dice_roll(n: usize) u32 {
    const base = ((n * 3) % 100) + 1;
    const term2 = (base % 100) + 1;
    const term3 = (term2 % 100) + 1;
    return @intCast(u32, base + term2 + term3);
}

//--------------------------------------------------------------------------------------------------
pub fn part1() anyerror!void {
    std.log.info("Part1 Running...", .{});
    var timer = try std.time.Timer.start();

    // Don't bother reading file, it just contains this:
    // Player 1 starting position: 1
    // Player 2 starting position: 6
    var pos_1: u32 = 1;
    var pos_2: u32 = 6;

    var score_1: u32 = 0;
    var score_2: u32 = 0;

    var turn: usize = 0;
    const max_score = 1000;
    while (score_1 < max_score and score_2 < max_score) {
        const player1_turn = (turn % 2) == 0;
        const die = dice_roll(turn);

        if (player1_turn) { // Player 1 turn
            pos_1 = (((pos_1 - 1) + die) % 10) + 1;
            score_1 += pos_1;
        } else {
            pos_2 = (((pos_2 - 1) + die) % 10) + 1;
            score_2 += pos_2;
        }
        turn += 1;
    }
    const dice_rolls = turn * 3;
    const losing_score = std.math.min(score_1, score_2);
    std.log.info("Total dice rolls: {d}", .{dice_rolls});
    std.log.info("Player1 pos:{d}, total:{d}", .{ pos_1, score_1 });
    std.log.info("Player2 pos:{d}, total:{d}", .{ pos_2, score_2 });
    std.log.info("\nResult:{d}", .{losing_score * dice_rolls});

    std.log.info("Part1: Completed in {d:.2}ms", .{@intToFloat(f32, timer.lap()) / 1.0e+6});
}

//--------------------------------------------------------------------------------------------------
pub fn recurse(rolled: u8, probability: u64, turn: u32, state: State, results: *Results) void {
    const player1_turn = (turn % 2) == 0;

    // Perform a turn
    var next_state = State{
        .pos_1 = state.pos_1,
        .pos_2 = state.pos_2,
        .score_1 = state.score_1,
        .score_2 = state.score_2,
    };
    if (player1_turn) {
        next_state.pos_1 = (((state.pos_1 - 1) + rolled) % 10) + 1;
        next_state.score_1 += next_state.pos_1;
    } else {
        next_state.pos_2 = (((state.pos_2 - 1) + rolled) % 10) + 1;
        next_state.score_2 += next_state.pos_2;
    }

    // Check for the winning condition
    const MAX_SCORE = 21;
    if (next_state.score_1 >= MAX_SCORE) {
        results.*.p1_wins += probability;
        return;
    } else if (next_state.score_2 >= MAX_SCORE) {
        results.*.p2_wins += probability;
        return;
    }

    // Branch out based on all the probable outcomes after 3 rolls of the dice
    recurse(3, 1 * probability, turn + 1, next_state, results); // Rolled 3 = 1+1+1
    recurse(4, 3 * probability, turn + 1, next_state, results); // Rolled 4 = 1+1+2 or 1+2+1 or 2+1+1
    recurse(5, 6 * probability, turn + 1, next_state, results); // Rolled 5 = 1+1+3 or 1+3+1 or 1+2+2 or 2+1+2 or 2+2+1 or 3+1+1
    recurse(6, 7 * probability, turn + 1, next_state, results); // Rolled 6 = 1+2+3 or 1+3+2 or 2+1+3 or 2+3+1 or 2+2+2 or 3+1+2 or 3+2+1
    recurse(7, 6 * probability, turn + 1, next_state, results); // Rolled 7 = 3+3+1 or 3+1+3 or 1+3+3 or 2+2+3 or 2+3+2 or 3+2+2
    recurse(8, 3 * probability, turn + 1, next_state, results); // Rolled 8 = 2+3+3 or 3+2+3 or 3+3+2
    recurse(9, 1 * probability, turn + 1, next_state, results); // Rolled 9 = 3+3+3
}

//--------------------------------------------------------------------------------------------------
pub fn part2() anyerror!void {
    std.log.info("Part2 Running...", .{});
    var timer = try std.time.Timer.start();

    // Don't bother reading file, it just contains this:
    // Player 1 starting position: 1
    // Player 2 starting position: 6
    const initial_state = State{
        .pos_1 = 1,
        .pos_2 = 6,
        .score_1 = 0,
        .score_2 = 0,
    };

    var results = Results{
        .p1_wins = 0,
        .p2_wins = 0,
    };

    // Branch out based on all the probable outcomes after 3 rolls of the dice
    recurse(3, 1, 0, initial_state, &results); // Rolled 3 = 1+1+1
    recurse(4, 3, 0, initial_state, &results); // Rolled 4 = 1+1+2 or 1+2+1 or 2+1+1
    recurse(5, 6, 0, initial_state, &results); // Rolled 5 = 1+1+3 or 1+3+1 or 1+2+2 or 2+1+2 or 2+2+1 or 3+1+1
    recurse(6, 7, 0, initial_state, &results); // Rolled 6 = 1+2+3 or 1+3+2 or 2+1+3 or 2+3+1 or 2+2+2 or 3+1+2 or 3+2+1
    recurse(7, 6, 0, initial_state, &results); // Rolled 7 = 3+3+1 or 3+1+3 or 1+3+3 or 2+2+3 or 2+3+2 or 3+2+2
    recurse(8, 3, 0, initial_state, &results); // Rolled 8 = 2+3+3 or 3+2+3 or 3+3+2
    recurse(9, 1, 0, initial_state, &results); // Rolled 9 = 3+3+3

    std.log.info("Player1 wins:{d}", .{results.p1_wins});
    std.log.info("Player2 wins:{d}", .{results.p2_wins});

    std.log.info("Part2: Completed in {d:.2}ms", .{@intToFloat(f32, timer.lap()) / 1.0e+6});
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    try part1();
    std.log.info("------------------------------", .{});
    try part2();
}

//--------------------------------------------------------------------------------------------------

