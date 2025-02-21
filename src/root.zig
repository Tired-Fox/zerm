const std = @import("std");
const builtin = @import("builtin");

pub const style = @import("style.zig");
pub const action = @import("action.zig");
pub const event = @import("event.zig");

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
///
/// Supports u8, u16, u21, u32, comptime_int and anything that implements the `format`
/// function for printing with a writer.
///
/// # Example
///
/// ```zig
/// pub const CustomType = struct {
///    pub fn format(
///       _: @This(),
///       comptime _: []const u8,
///       _: std.fmt.FormatOptions,
///       writer: anytype
///    ) !void {
///         try writer.print("CustomType");
///    }
/// }
///
/// try execute(.Stdout, .{
///     Style { .fg = Color.Green },
///     '✓',
///     Reset.fg(),
///     ' ',
///     CustomType{},
/// });
/// ```
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
            u8 => try writer.writeByte(op),
            u16 => {
                var it = std.unicode.Utf16LeIterator.init([1]u16{ op });
                while (try it.nextCodepoint()) |cp| {
                    var buff: [4]u8 = undefined;
                    const length = try std.unicode.utf8Encode(cp, &buff);
                    try writer.writeAll(buff[0..length]);
                }
            },
            u21, u32, comptime_int => {
                var buff: [4]u8 = [_]u8{0}**4;
                const length = try std.unicode.utf8Encode(@intCast(op), &buff);
                try writer.writeAll(buff[0..length]);
            },
            else => {
                try writer.print("{s}", .{ op });
            }
        }
    }

    try buffer.flush();
}

/// This is a work around on `windows` since windows likes `UTF16` encoding.
///
/// If a user attempts to print a unicode character that is not in the ascii space
/// the user is required to encode it as utf16.
///
/// It just sets the console output to `UTF8` and requires the user to call `deinit`
/// to reset it to what it was before the app ran. This is to avoid causing problems
/// for other terminal applications in the future.
pub const Utf8ConsoleOutput = struct {
    original: if (builtin.os.tag == .windows) c_uint else void,

    pub fn init() @This() {
        if (builtin.os.tag == .windows) {
            const original = std.os.windows.kernel32.GetConsoleOutputCP();
            _ = std.os.windows.kernel32.SetConsoleOutputCP(65001);
            return .{ .original = original };
        }
        return .{ .original = {} };
    }

    pub fn deinit(self: @This()) void {
        if (builtin.os.tag == .windows) {
            _ = std.os.windows.kernel32.SetConsoleOutputCP(self.original);
        }
    }
};

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
