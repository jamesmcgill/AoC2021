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

            //std.log.info("Instruction: {s} {s} {s}", .{ instruction_str, lhs_str, rhs_str });

            const ins = Instruction{
                .opcode = parseOpcode(instruction_str),
                .lhs = parseOperand(lhs_str),
                .rhs = parseOperand(rhs_str),
            };
            try program.append(ins);
        }
    }

    var input: u64 = 99999_99999_9999;
    while (true) : (input -= 1) {
        var state = State{};
        state.input = Input.init(allocator);
        defer state.input.deinit();
        if (!set_state_input(input, &state)) {
            continue;
        }

        for (program.items) |ins| {
            //std.log.info("{s} {d} {d}", .{ ins.opcode, ins.lhs, ins.rhs });
            perform(ins, &state);
        }
        // std.log.info("input {d}. State: w:{d}, x:{d}, y:{d}, z:{d}, input:{d}", .{ input, state.w, state.x, state.y, state.z, state.input.items });
        if (state.z == 0) {
            std.log.info("Found valid input! {d}. State: w:{d}, x:{d}, y:{d}, z:{d}, input:{d}", .{ input, state.w, state.x, state.y, state.z, state.input.items });
            break;
        }
        if (input == 0) {
            break;
        }
    }

    //std.log.info("Instruction count: {d}", .{program.items.len});

    std.log.info("Completed in {d:.2}ms", .{@intToFloat(f32, timer.lap()) / 1.0e+6});
}

//--------------------------------------------------------------------------------------------------
