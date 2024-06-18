const std = @import("std");

pub const Terminal = @import("terminal.zig");
pub const Action = @import("ansi.zig").Action;
pub const Cursor = @import("ansi.zig").Cursor;
pub const Screen = @import("ansi.zig").Screen;
pub const Line = @import("ansi.zig").Line;
pub const Character = @import("ansi.zig").Character;
pub const Style = @import("ansi.zig").Style;
pub const Color = @import("ansi.zig").Color;
pub const XTerm = @import("ansi.zig").XTerm;

pub const Key = @import("events.zig").Key;

pub const Rune = struct {
    value: u21,

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        var buff: [4]u8 = [_]u8{0} ** 4;
        const length = try std.unicode.utf8Encode(value.value, &buff);
        try writer.print("{s}", .{buff[0..length]});
    }
};

pub fn Pair(comptime _type1: type, comptime _type2: type) type {
    return std.meta.Tuple(&.{ _type1, _type2 });
}

pub const Size = Pair(u16, u16);
pub const Point = Pair(u16, u16);

pub fn rune(c: u21) Rune {
    return .{ .value = c };
}
