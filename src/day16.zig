const std = @import("std");
const Allocator = std.mem.Allocator;

//--------------------------------------------------------------------------------------------------
const Context = struct {
    header_id_count: u64,
};

//--------------------------------------------------------------------------------------------------
const Info = struct {
    value: u64,
    len: usize,
};

//--------------------------------------------------------------------------------------------------
const Cmd = struct {
    base: u64,
    op: fn (u64, u64) u64,
};

//--------------------------------------------------------------------------------------------------
fn sum(l: u64, r: u64) u64 {
    return l + r;
}
const sum_cmd = Cmd{
    .base = 0,
    .op = sum,
};

//--------------------------------------------------------------------------------------------------
fn mul(l: u64, r: u64) u64 {
    return l * r;
}
const mul_cmd = Cmd{
    .base = 1,
    .op = mul,
};

//--------------------------------------------------------------------------------------------------
fn min(l: u64, r: u64) u64 {
    // Due to the way we enumerate the packets (i.e. one at a time, unary)
    // It is only on the second iteration that we have seen both of them.
    // The first iteration should just do setup for the second iteration.
    if (l == std.math.maxInt(u64)) {
        return r;
    }
    return if (l < r) l else r;
}
const min_cmd = Cmd{
    .base = std.math.maxInt(u64),
    .op = min,
};

//--------------------------------------------------------------------------------------------------
fn max(l: u64, r: u64) u64 {
    if (l == std.math.minInt(u64)) {
        return r;
    }
    return if (l < r) r else l;
}
const max_cmd = Cmd{
    .base = std.math.minInt(u64), // TODO: CAREFUL, zero is not a special value
    .op = max,
};

//--------------------------------------------------------------------------------------------------
fn gt(l: u64, r: u64) u64 {
    if (l == std.math.maxInt(u64)) {
        return r;
    }
    return if (l > r) 1 else 0;
}
const gt_cmd = Cmd{
    .base = std.math.maxInt(u64),
    .op = gt,
};

//--------------------------------------------------------------------------------------------------
fn lt(l: u64, r: u64) u64 {
    if (l == std.math.maxInt(u64)) {
        return r;
    }
    return if (l < r) 1 else 0;
}
const lt_cmd = Cmd{
    .base = std.math.maxInt(u64),
    .op = lt,
};

//--------------------------------------------------------------------------------------------------
fn eq(l: u64, r: u64) u64 {
    if (l == std.math.maxInt(u64)) {
        return r;
    }
    return if (l == r) 1 else 0;
}
const eq_cmd = Cmd{
    .base = std.math.maxInt(u64),
    .op = eq,
};

//--------------------------------------------------------------------------------------------------
pub fn charToBitString(c: u8) *const [4]u8 {
    const value = switch (c) {
        '0' => "0000",
        '1' => "0001",
        '2' => "0010",
        '3' => "0011",
        '4' => "0100",
        '5' => "0101",
        '6' => "0110",
        '7' => "0111",
        '8' => "1000",
        '9' => "1001",
        'A' => "1010",
        'B' => "1011",
        'C' => "1100",
        'D' => "1101",
        'E' => "1110",
        'F' => "1111",
        else => "0000",
    };
    return value;
}

//--------------------------------------------------------------------------------------------------
pub fn parseInt(slice: []const u8) u64 {
    var total: u64 = 0;
    var factor: u64 = 1; // from right to left (1, 2, 4, 8..)

    var i: usize = slice.len;
    while (i > 0) : (i -= 1) {
        if (slice[i - 1] == '1') {
            total += factor;
        }
        factor *= 2;
    }

    return total;
}

//--------------------------------------------------------------------------------------------------
// Parse Packet Header (6 bits)
// - version (3 bits)
// - type ID (3 bits)

// Operator Packet
// Parse 'length type ID' (1 bit)
// 0 => next 15 bits is total length (bits) of sub-packets contained within
// 1 => next 11 bits is number of sub-packets

// Literal Packet (N x 5 bits)
// leading 1 => not the last group
// leading 0 => last group

//--------------------------------------------------------------------------------------------------
pub fn parseLiteralPart(cxt: *Context, slice: []const u8) Info {
    // Literal Packet (N groups of 5 bits)
    // first bit is only used to indicate continuation, 4 bits used for value
    _ = cxt;

    // Look ahead in steps of 5 bits, until we find the last group of bits
    var last_group: usize = 0;
    while (slice[last_group] != '0') : (last_group += 5) {}

    var total: u64 = 0;
    var factor: u64 = 1; // from right to left in 4 bit steps (1, 16, 32, 64..)

    // Walk backwards to the start in steps of 5 bits, adding up as we go
    var group_start = last_group;
    while (true) : (group_start -= 5) {
        const i = group_start + 1;
        total += (parseInt(slice[i .. i + 4]) * factor);
        factor <<= 4;
        if (group_start == 0) { // reached the beginning
            break;
        }
    }
    return Info{ .value = total, .len = last_group + 5 };
}

//--------------------------------------------------------------------------------------------------
pub fn parseOperatorPart(cxt: *Context, slice: []const u8, cmd: Cmd) Info {
    _ = cxt;

    // Read the bits containing the size
    // first bit is 'length type ID'
    // length type ID: 1 => next 11 bits is number of sub-packets
    // length type ID: 0 => next 15 bits is total length (bits) of sub-packets contained within
    const size_len: usize = if (slice[0] == '1') 11 else 15;
    var i: usize = 1; // skip first bit
    var e = i + size_len;
    const length = parseInt(slice[i..e]);

    // Read sub packets
    i = e; // next read should happen from after the size bits

    var value = cmd.base;

    // length type ID: 1 => length represents number of sub-packets to read
    if (slice[0] == '1') {
        var packet: u64 = 0;
        while (packet < length) : (packet += 1) {
            const info = parsePacket(cxt, slice[i..]);
            value = cmd.op(value, info.value);
            i += info.len;
        }
    } else {
        // length type ID: 0 => length represents number of bits to read
        const end_idx = i + length;
        while (i < end_idx) {
            const info = parsePacket(cxt, slice[i..end_idx]);
            value = cmd.op(value, info.value);
            i += info.len;
        }
    }

    return Info{ .value = value, .len = i };
}

//--------------------------------------------------------------------------------------------------
pub fn parsePacket(cxt: *Context, slice: []const u8) Info {
    var header = parseInt(slice[0..3]);
    var typeID = parseInt(slice[3..6]);

    cxt.header_id_count += header;

    var info = switch (typeID) {
        4 => parseLiteralPart(cxt, slice[6..]),
        0 => parseOperatorPart(cxt, slice[6..], sum_cmd),
        1 => parseOperatorPart(cxt, slice[6..], mul_cmd),
        2 => parseOperatorPart(cxt, slice[6..], min_cmd),
        3 => parseOperatorPart(cxt, slice[6..], max_cmd),
        5 => parseOperatorPart(cxt, slice[6..], gt_cmd),
        6 => parseOperatorPart(cxt, slice[6..], lt_cmd),
        7 => parseOperatorPart(cxt, slice[6..], eq_cmd),
        else => unreachable,
    };

    return Info{ .value = info.value, .len = info.len + 6 };
}

//--------------------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    var timer = try std.time.Timer.start();

    const file = std.fs.cwd().openFile("data/day16_input.txt", .{}) catch |err| label: {
        std.debug.print("unable to open file: {e}\n", .{err});
        const stderr = std.io.getStdErr();
        break :label stderr;
    };
    defer file.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    var bits = try std.ArrayList(u8).initCapacity(allocator, 1024 * 8);
    defer bits.deinit();

    {
        var reader = std.io.bufferedReader(file.reader());
        var istream = reader.reader();
        var buf: [1024 * 8]u8 = undefined;

        // Read lines
        while (try istream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            if (line.len == 0) {
                continue;
            }

            // Convert line into array of ints
            for (line) |char| {
                var digits = charToBitString(char);
                for (digits) |b| {
                    bits.append(b) catch unreachable;
                }
            }
        }
    }

    var context = Context{ .header_id_count = 0 };
    const info = parsePacket(&context, bits.items);

    std.log.info("Part 1: Header count: {d}", .{context.header_id_count});
    std.log.info("Part 2: Final value: {d}", .{info.value});

    std.log.info("Completed in {d:.2}ms", .{@intToFloat(f32, timer.lap()) / 1.0e+6});
}

//--------------------------------------------------------------------------------------------------

