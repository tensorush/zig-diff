const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if ((gpa.deinit() == .leak)) {
        @panic("Memory leak has occurred!");
    };

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const std_out = std.io.getStdOut();
    var buf_writer = std.io.bufferedWriter(std_out.writer());
    const writer = buf_writer.writer();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const a = args[1];
    const b = args[2];

    try writer.print("Minimum edit script size: {d}\n", .{try findMinimumEditScriptSize(allocator, a, b)});

    try writer.print("Minimum reverse edit script size: {d}\n", .{try findMinimumReverseEditScriptSize(allocator, a, b)});

    try writer.writeAll("Longest common subsequence (LCS): ");
    try printLongestCommonSubsequence(allocator, writer, a, b);
    try writer.writeByte('\n');

    try writer.writeAll("Shortest edit script (SES): ");
    try printShortestEditScript(allocator, writer, @intFromPtr(a.ptr), @constCast(&a), @constCast(&b));
    try writer.writeByte('\n');

    try buf_writer.flush();
}

fn findMinimumEditScriptSize(allocator: std.mem.Allocator, a: []const u8, b: []const u8) !i32 {
    const max: i32 = @intCast(b.len + a.len);

    var v = try std.ArrayListUnmanaged(i32).initCapacity(allocator, @intCast(2 * max + 1));
    v.expandToCapacity();
    v.items[@intCast(1 + max)] = 0;

    var x: i32 = undefined;
    var y: i32 = undefined;
    var k: i32 = undefined;
    var d: i32 = 0;
    while (d <= max) : (d += 1) {
        k = -d;
        while (k <= d) : (k += 2) {
            if (k == -d or (k != d and v.items[@intCast(k - 1 + max)] < v.items[@intCast(k + 1 + max)])) {
                x = v.items[@intCast(k + 1 + max)];
            } else {
                x = v.items[@intCast(k - 1 + max)] + 1;
            }
            y = x - k;
            while (x < a.len and y < b.len and a[@intCast(x)] == b[@intCast(y)]) {
                x += 1;
                y += 1;
            }
            v.items[@intCast(k + max)] = x;
            if (x >= a.len and y >= b.len) {
                return d;
            }
        }
    }

    unreachable;
}

fn findMinimumReverseEditScriptSize(allocator: std.mem.Allocator, a: []const u8, b: []const u8) !i32 {
    const delta: i32 = @intCast(a.len - b.len);
    const max: i32 = @intCast(b.len + a.len);

    var v = try std.ArrayListUnmanaged(i32).initCapacity(allocator, @intCast(2 * max + 1));
    v.expandToCapacity();
    v.items[@intCast(delta + 1 + max)] = @intCast(a.len + 1);

    var x: i32 = undefined;
    var y: i32 = undefined;
    var k: i32 = undefined;
    var d: i32 = 0;
    while (d <= max) : (d += 1) {
        k = -d + delta;
        while (k <= d + delta) : (k += 2) {
            if (k == -d + delta or (k != d + delta and v.items[@intCast(k - 1 + max)] >= v.items[@intCast(k + 1 + max)])) {
                x = v.items[@intCast(k + 1 + max)] - 1;
            } else {
                x = v.items[@intCast(k - 1 + max)];
            }
            y = x - k;
            while (x > 0 and y > 0 and a[@intCast(x - 1)] == b[@intCast(y - 1)]) {
                x -= 1;
                y -= 1;
            }
            v.items[@intCast(k + max)] = x;
            if (x <= 0 and y <= 0) {
                return d;
            }
        }
    }

    unreachable;
}

fn printLongestCommonSubsequence(allocator: std.mem.Allocator, writer: anytype, a: []const u8, b: []const u8) !void {
    if (a.len > 0 and b.len > 0) {
        var x: i32 = undefined;
        var y: i32 = undefined;
        var u: i32 = undefined;
        var v: i32 = undefined;
        var d: i32 = undefined;
        try findMiddleSnake(allocator, a, b, &x, &y, &u, &v, &d);
        if (d > 1) {
            try printLongestCommonSubsequence(allocator, writer, a[0..@intCast(x)], b[0..@intCast(y)]);
            try writer.writeAll(a[@intCast(x)..@intCast(u)]);
            try printLongestCommonSubsequence(allocator, writer, a[@intCast(u)..], b[@intCast(v)..]);
        } else if (b.len > a.len) {
            try writer.writeAll(a);
        } else {
            try writer.writeAll(b);
        }
    }
}

fn printShortestEditScript(allocator: std.mem.Allocator, writer: anytype, start_a: usize, a: *[]const u8, b: *[]const u8) !void {
    while (a.len > 0 and b.len > 0 and a.*[0] == b.*[0]) {
        a.* = a.*[1..];
        b.* = b.*[1..];
    }

    while (a.len > 0 and b.len > 0 and a.*[a.len - 1] == b.*[b.len - 1]) {
        a.* = a.*[0 .. a.len - 1];
        b.* = b.*[0 .. b.len - 1];
    }

    if (a.len > 0 and b.len > 0) {
        var x: i32 = undefined;
        var y: i32 = undefined;
        var u: i32 = undefined;
        var v: i32 = undefined;
        var d: i32 = undefined;
        try findMiddleSnake(allocator, a.*, b.*, &x, &y, &u, &v, &d);
        try printShortestEditScript(allocator, writer, start_a, @constCast(&a.*[0..@intCast(x)]), @constCast(&b.*[0..@intCast(y)]));
        try printShortestEditScript(allocator, writer, start_a, @constCast(&a.*[@intCast(u)..]), @constCast(&b.*[@intCast(v)..]));
    } else if (a.len > 0) {
        try writer.writeByte('-');
        for (a.*, 0..) |_, i| {
            try writer.print("{d}", .{@intFromPtr(a.ptr) + i - start_a});
        }
    } else if (b.len > 0) {
        try writer.print("+{d}{s}", .{ @intFromPtr(a.ptr) - start_a, b.* });
    }
}

fn findMiddleSnake(allocator: std.mem.Allocator, a: []const u8, b: []const u8, x: *i32, y: *i32, u: *i32, v: *i32, d: *i32) !void {
    var delta: i32 = @intCast(a.len);
    delta -= @intCast(b.len);
    const max: i32 = @intCast(b.len + a.len);

    var fv = try std.ArrayListUnmanaged(i32).initCapacity(allocator, @intCast(2 * max + 1));
    fv.expandToCapacity();
    fv.items[@intCast(1 + max)] = 0;

    var rv = try std.ArrayListUnmanaged(i32).initCapacity(allocator, @intCast(2 * max + 1));
    rv.expandToCapacity();
    rv.items[@intCast(delta + 1 + max)] = @intCast(a.len + 1);

    var k: i32 = undefined;
    d.* = 0;
    while (@as(f32, @floatFromInt(d.*)) <= @ceil(@as(f32, @floatFromInt(b.len + a.len)) / 2.0)) : (d.* += 1) {
        k = -d.*;
        while (k <= d.*) : (k += 2) {
            if (k == -d.* or (k != d.* and fv.items[@intCast(k - 1 + max)] < fv.items[@intCast(k + 1 + max)])) {
                x.* = fv.items[@intCast(k + 1 + max)];
            } else {
                x.* = fv.items[@intCast(k - 1 + max)] + 1;
            }
            y.* = x.* - k;
            while (x.* < a.len and y.* < b.len and a[@intCast(x.*)] == b[@intCast(y.*)]) {
                x.* += 1;
                y.* += 1;
            }
            fv.items[@intCast(k + max)] = x.*;
            if (@rem(delta, 2) != 0 and k >= delta - (d.* - 1) and k <= delta + d.* - 1 and fv.items[@intCast(k + max)] >= rv.items[@intCast(k + max)]) {
                u.* = x.*;
                v.* = y.*;
                x.* = rv.items[@intCast(k + max)];
                y.* = rv.items[@intCast(k + max)] - k;
                d.* = 2 * d.* - 1;
                return {};
            }
        }

        k = -d.* + delta;
        while (k <= d.* + delta) : (k += 2) {
            if (k == -d.* + delta or (k != d.* + delta and rv.items[@intCast(k - 1 + max)] >= rv.items[@intCast(k + 1 + max)])) {
                x.* = rv.items[@intCast(k + 1 + max)] - 1;
            } else {
                x.* = rv.items[@intCast(k - 1 + max)];
            }
            y.* = x.* - k;
            while (x.* > 0 and y.* > 0 and a[@intCast(x.* - 1)] == b[@intCast(y.* - 1)]) {
                x.* -= 1;
                y.* -= 1;
            }
            rv.items[@intCast(k + max)] = x.*;
            if (@rem(delta, 2) == 0 and k >= -d.* and k <= d.* and fv.items[@intCast(k + max)] >= rv.items[@intCast(k + max)]) {
                u.* = fv.items[@intCast(k + max)];
                v.* = fv.items[@intCast(k + max)] - k;
                d.* *= 2;
                return {};
            }
        }
    }

    unreachable;
}
