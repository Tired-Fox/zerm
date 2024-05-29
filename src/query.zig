const std = @import("std");

pub const Query = enum {
    ScreenSize,
    CursorPos,

    pub fn sequence(self: @This()) []const u8 {
        return switch (self) {
            .ScreenSize => "\x1b[s\x1b[9999;9999H\x1b[6n\x1b[u",
            .CursorPos => "\x1b[6n",
        };
    }

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return writer.print("{s}", .{value.sequence()});
    }
};
