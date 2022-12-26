//--------------------------------------------------------------------------------------------------
// Features used:
//
// - Tagged union
// - File loading and parsing
//--------------------------------------------------------------------------------------------------
//
//--------------------------------------------------------------------------------------------------
const std = @import("std");
const Allocator = std.mem.Allocator;

//--------------------------------------------------------------------------------------------------
const Opcode = enum {
    inp,
    add,
    mul,
    div,
    mod,
    eql,
};
const Register = enum {
    x,
    y,
    z,
    w,
};

const OperandTag = enum {
    register,
    int,
};
const Operand = union(OperandTag) {
    register: Register,
    int: i64,
};
const Instruction = struct {
    opcode: Opcode,
    lhs: Operand,
    rhs: Operand,
};

const Program = std.ArrayList(Instruction);
const Input = std.ArrayList(u4);

const State = struct {
    x: i64 = 0,
    y: i64 = 0,
    z: i64 = 0,
    w: i64 = 0,
    input: Input = undefined,
};

//--------------------------------------------------------------------------------------------------
pub fn get_register_value(register: Register, state: State) i64 {
    const ret = switch (register) {
        Register.x => state.x,
        Register.y => state.y,
        Register.z => state.z,
        Register.w => state.w,
    };
    return ret;
}

//--------------------------------------------------------------------------------------------------
pub fn set_register_value(register: Register, state: *State, new_value: i64) void {
    _ = switch (register) {
        Register.x => state.*.x = new_value,
        Register.y => state.*.y = new_value,
        Register.z => state.*.z = new_value,
        Register.w => state.*.w = new_value,
    };
}

//--------------------------------------------------------------------------------------------------
pub fn get_operand_value(operand: Operand, state: State) i64 {
    const ret = switch (operand) {
        OperandTag.register => |reg| get_register_value(reg, state),
        OperandTag.int => |value| value,
    };
    return ret;
}

//--------------------------------------------------------------------------------------------------
pub fn parseOpcode(str: []const u8) Opcode {
    // HACK: using the 2nd character of the string as it is unique for this instruction set
    const c = str[1];

    const ret = switch (c) {
        'n' => Opcode.inp,
        'd' => Opcode.add,
        'u' => Opcode.mul,
        'i' => Opcode.div,
        'o' => Opcode.mod,
        'q' => Opcode.eql,
        else => unreachable,
    };
    return ret;
}

//--------------------------------------------------------------------------------------------------
pub fn parseOperand(str: []const u8) Operand {
    if (std.mem.eql(u8, str, "x")) return Operand{ .register = Register.x };
    if (std.mem.eql(u8, str, "y")) return Operand{ .register = Register.y };
    if (std.mem.eql(u8, str, "z")) return Operand{ .register = Register.z };
    if (std.mem.eql(u8, str, "w")) return Operand{ .register = Register.w };
    if (std.mem.eql(u8, str, "")) return Operand{ .int = 0 };

    return Operand{ .int = std.fmt.parseInt(i64, str, 10) catch 0 };
}

//--------------------------------------------------------------------------------------------------
pub fn set_state_input(input: u64, state: *State) bool {
    // Because we will be using pop() and the most-significant digits should pop first
    // we have to append the least significant digits first.
    var in = input;
    while (true) : (in = @divTrunc(in, 10)) {
        const digit: u4 = @intCast(u4, @mod(in, 10));
        if (digit == 0) { // zero digits are not allowed in the input
            return false;
        }
        state.input.append(digit) catch unreachable;
        if (in < 10) {
            break;
        }
    }
    return true;
}

//--------------------------------------------------------------------------------------------------
pub fn ins_input(dst: Register, state: *State) void {
    const new_value = state.input.pop();
    set_register_value(dst, state, new_value);
}

//--------------------------------------------------------------------------------------------------
pub fn ins_add(dst: Register, rhs: Operand, state: *State) void {
    const l = get_register_value(dst, state.*);
    const r = get_operand_value(rhs, state.*);
    set_register_value(dst, state, l + r);
}

//--------------------------------------------------------------------------------------------------
pub fn ins_mul(dst: Register, rhs: Operand, state: *State) void {
    const l = get_register_value(dst, state.*);
    const r = get_operand_value(rhs, state.*);
    set_register_value(dst, state, l * r);
}

//--------------------------------------------------------------------------------------------------
pub fn ins_div(dst: Register, rhs: Operand, state: *State) void {
    const l = get_register_value(dst, state.*);
    const r = get_operand_value(rhs, state.*);
    set_register_value(dst, state, @divTrunc(l, r));
}

//--------------------------------------------------------------------------------------------------
pub fn ins_mod(dst: Register, rhs: Operand, state: *State) void {
    const l = get_register_value(dst, state.*);
    const r = get_operand_value(rhs, state.*);
    set_register_value(dst, state, @mod(l, r));
}

//--------------------------------------------------------------------------------------------------
pub fn ins_eql(dst: Register, rhs: Operand, state: *State) void {
    const l = get_register_value(dst, state.*);
    const r = get_operand_value(rhs, state.*);
    set_register_value(dst, state, if (l == r) 1 else 0);
}

//--------------------------------------------------------------------------------------------------
pub fn perform(instr: Instruction, state: *State) void {
    _ = switch (instr.opcode) {
        Opcode.inp => ins_input(instr.lhs.register, state),
        Opcode.add => ins_add(instr.lhs.register, instr.rhs, state),
        Opcode.mul => ins_mul(instr.lhs.register, instr.rhs, state),
        Opcode.div => ins_div(instr.lhs.register, instr.rhs, state),
        Opcode.mod => ins_mod(instr.lhs.register, instr.rhs, state),
        Opcode.eql => ins_eql(instr.lhs.register, instr.rhs, state),
    };
}

//--------------------------------------------------------------------------------------------------
pub fn is_input_valid(input: u64, program: Program, allocator: Allocator) bool {
    var state = State{};
    state.input = Input.init(allocator);
    defer state.input.deinit();
    if (!set_state_input(input, &state)) {
        return false;
    }

    for (program.items) |ins| {
        perform(ins, &state);
    }
    std.log.info("Input: {d} produced: State: w:{d}, x:{d}, y:{d}, z:{d}, input:{d}", .{ input, state.w, state.x, state.y, state.z, state.input.items });

    return (state.z == 0);
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    var timer = try std.time.Timer.start();

    // Read entire file into huge buffer and get a slice to the populated part
    var buffer: [256 * 10]u8 = undefined;
    const buffer_populated = try std.fs.cwd().readFile("data/day24_input.txt", buffer[0..]);
    std.debug.assert(buffer_populated.len < buffer.len); // Otherwise buffer is too small

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var program = Program.init(allocator);
    defer program.deinit();

    //----------------------------------------------------------------------------------------------
    // Parse the input data
    {
        var line_idx: usize = 0;
        var it = std.mem.tokenize(u8, buffer_populated, "\r\n");
        while (it.next()) |line| : (line_idx += 1) {
            std.debug.assert(line.len != 0);

            // Parse instruction
            var line_it = std.mem.split(u8, line, " ");
            const instruction_str = line_it.next() orelse "";
            const lhs_str = line_it.next() orelse "";
            const rhs_str = line_it.next() orelse "";

            const ins = Instruction{
                .opcode = parseOpcode(instruction_str),
                .lhs = parseOperand(lhs_str),
                .rhs = parseOperand(rhs_str),
            };
            try program.append(ins);
        }
    }

    // Part 1 - Find max code
    {
        var code = Input.init(allocator);
        defer code.deinit();
        _ = forward_digit(0, 0, &code, true);
        const input_max = build_code(&code);

        const is_valid = is_input_valid(input_max, program, allocator);
        std.log.info("Part 1: Max Input: {d}, valid = {b}", .{ input_max, is_valid });
    }

    // Part 2 - Find min code
    {
        var code = Input.init(allocator);
        defer code.deinit();
        _ = forward_digit(0, 0, &code, false);
        const input_min = build_code(&code);

        const is_valid = is_input_valid(input_min, program, allocator);
        std.log.info("Part 2: Min Input: {d}, valid = {b}", .{ input_min, is_valid });
    }

    std.log.info("Completed in {d:.2}ms", .{@intToFloat(f32, timer.lap()) / 1.0e+6});
}

//--------------------------------------------------------------------------------------------------
pub fn build_code(digits: *Input) u64 {
    var code: u64 = 0;
    for (digits.items) |v| {
        code *= 10;
        code += v;
    }
    return code;
}

//--------------------------------------------------------------------------------------------------
pub fn forward_digit(digit_idx: usize, z_in: i64, digits: *Input, find_max: bool) bool {
    const P = [_]i16{ 7, 8, 10, 4, 4, 6, 11, 13, 1, 8, 4, 13, 4, 14 };
    const D = [_]i16{ 1, 1, 1, 26, 26, 1, 26, 26, 1, 1, 26, 1, 26, 26 };
    const A = [_]i16{ 12, 13, 13, -2, -10, 13, -14, -5, 15, 15, -14, 10, -14, -5 };

    // Psuedocode of the input program unit
    // ------------------------------------
    // 1) Equality test. TRUE if we couldn't match the input digit (w) to A[]
    // const x: bool = (w != (z % 26) + A[digit_idx]);

    // 2) Optional truncate. DECREASE Z by a factor of 26
    // if (truncate)
    //     z /= 26;

    // 3) Optional Branch. INCREASE Z by a factor of 26  (AND increment by variable amount)
    // if (x)
    // {
    //     var z = z_in;
    //     z *= 26; // Untruncate
    //     z += w + P[digit_idx];
    // }

    // Truncates only happen when D[] is 26.
    // Also notice that those occassions match when A[] is a negative number.
    // Or put another way: when D[] is 1, we can't truncate and on those
    // occassions A[] is a number larger than 10, forcing the (x) branch to be taken.
    // NOTE also there are 7 occassions to truncate and 7 occassions we don't.
    //
    // The goal of the program is that register z (an accumulator that begins at zero)
    // also finishes with a zero value (indicating a valid code).
    // To do this we need to balance the amount of times we increase the value (the x branch),
    // with how many times we decrease the value (truncate).
    // I.e. 7 increases and 7 decreases.
    // On the 7 occassions that we do not truncate, it's guaranteed by A[] that the
    // x branch (increase) will be happen every time.
    //
    // GOAL: for the 7 occassions that we truncate we MUST NOT take the x branch.
    // i.e. input digit (w) MUST be  (z % 26) + A[digit_idx])

    if (digit_idx >= 14) {
        return true; // Completed!
    }

    const truncate: bool = D[digit_idx] == 26;
    if (truncate) {
        // truncate branch - w is determined
        const desired_w = @mod(z_in, 26) + A[digit_idx];
        if (desired_w < 1 or desired_w > 9) {
            return false; // can't match w
        }
        const w: u4 = @intCast(u4, desired_w);

        digits.append(w) catch unreachable;
        if (forward_digit(digit_idx + 1, @divTrunc(z_in, 26), digits, find_max)) { // Truncate Z
            return true; // completed: escape recursion, preserving digits
        }
        _ = digits.pop();
    } else {

        // non-truncate branch - need to try all possible digits (w)
        var w: u4 = if (find_max) 9 else 1; // Start with highest values first?
        while (w >= 1 and w < 10) {
            // Increase Z
            var z = z_in;
            z *= 26;
            z += w + P[digit_idx];

            digits.append(w) catch unreachable;
            if (forward_digit(digit_idx + 1, z, digits, find_max)) {
                return true; // completed: escape recursion, preserving digits
            }
            _ = digits.pop();

            if (find_max) w -= 1 else w += 1;
        } // while w
    }

    return false;
}

//--------------------------------------------------------------------------------------------------
