const std = @import("std");

pub const style = @import("style.zig");
pub const action = @import("action.zig");
pub const events = @import("events.zig");

/// Target where printed commands are written
pub const Source = enum {
    Stdout,
    Stderr,
};

/// Run each command in the arguments
///
/// All commands that print to the `source` will
/// be buffered and batched all at once.
///
/// All commands that run native code will be executed
/// immediatly.
pub fn execute(source: Source, ops: anytype) !void {
    const output = switch (source) {
        .Stdout => std.io.getStdOut().writer(),
        .Stderr => std.io.getStdErr().writer(),
    };

    var buffer = std.io.bufferedWriter(output);
    var writer = buffer.writer();

    inline for (ops) |op| {
        const t = @TypeOf(op);
        switch (t) {
            u8 => try writer.print("{c}", .{op}),
            u16 => {
                var buff: [2]u8 = undefined;
                const length = try std.unicode.utf16LeToUtf8(&buff, [1]u16{op});
                try writer.print("{s}", .{buff[0..length]});
            },
            u21 => {
                var buff: [4]u8 = undefined;
                const length = try std.unicode.utf8Encode(op, &buff);
                try writer.print("{s}", .{buff[0..length]});
            },
            else => {
                try writer.print("{s}", .{ op });
            }
        }
    }

    try buffer.flush();
}

const utils = switch (@import("builtin").target.os.tag) {
    .windows => struct {
        extern "kernel32" fn GetNumberOfConsoleInputEvents(
            hConsoleInput: std.os.windows.HANDLE,
            lpcNumberOfEvents: *std.os.windows.DWORD
        ) callconv(.winapi) std.os.windows.BOOL;
    },
    else => struct {}
};

test {
    std.testing.refAllDecls(@This());
}
