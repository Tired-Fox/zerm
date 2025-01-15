const std = @import("std");

pub const style = @import("style.zig");
pub const action = @import("action.zig");
pub const event = @import("event.zig");

pub const Source = enum {
    Stdout,
    Stderr,
};

pub fn execute(source: Source, ops: anytype) !void {
    const output = switch (source) {
        .Stdout => std.io.getStdOut().writer(),
        .Stderr => std.io.getStdErr().writer(),
    };

    inline for (ops) |op| {
        const t = @TypeOf(op);
        switch (t) {
            u8 => try output.print("{c}", .{op}),
            u16 => {
                var buff: [2]u8 = undefined;
                const length = try std.unicode.utf16LeToUtf8(&buff, [1]u16{op});
                try output.print("{s}", .{buff[0..length]});
            },
            u21 => {
                var buff: [4]u8 = undefined;
                const length = try std.unicode.utf8Encode(op, &buff);
                try output.print("{s}", .{buff[0..length]});
            },
            else => {
                try output.print("{s}", .{ op });
            }
        }
    }
}

test {
    std.testing.refAllDecls(@This());
}
