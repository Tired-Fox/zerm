const std = @import("std");
const builtin = @import("builtin");

pub const style = @import("style.zig");
pub const action = @import("action.zig");
pub const event = @import("event.zig");

/// Available output streams
pub const Stream = enum(u2) {
    stdout,
    stderr,

    pub fn isTty(self: *const @This()) bool {
        return switch (self.*) {
            .stdout => std.io.getStdOut().isTty(),
            .stderr => std.io.getStdErr().isTty(),
        };
    }
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
/// try execute(.stdout, .{
///     Style { .fg = Color.Green },
///     '✓',
///     Reset.fg(),
///     ' ',
///     CustomType{},
/// });
/// ```
pub fn execute(source: Stream, ops: anytype) !void {
    const output = switch (source) {
        .stdout => std.io.getStdOut().writer(),
        .stderr => std.io.getStdErr().writer(),
    };

    var buffer = std.io.bufferedWriter(output);
    const writer = buffer.writer();

    inline for (ops) |op| {
        try writeOp(op, writer);
    }

    try buffer.flush();
}

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
/// This will run WinApi calls immediatly but hold onto the ansi sequences until `flush`
/// is called on the returned queue.
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
/// const q = Queue.init(.stdout);
/// try q.writeAll(.{
///     Style { .fg = Color.Green },
///     '✓',
///     Reset.fg(),
///     ' ',
///     CustomType{},
/// });
///
/// try q.write("Some other item");
///
/// // ... Additional logic
///
/// try q.flush();
/// ```
pub const Queue = struct {
    buffer: std.io.BufferedWriter(4096, std.fs.File.Writer),

    pub fn init(stream: Stream) @This() {
        const output = switch (stream) {
            .stdout => std.io.getStdOut().writer(),
            .stderr => std.io.getStdErr().writer(),
        };
        return .{ .buffer = std.io.bufferedWriter(output) };
    }

    pub fn write(self: *@This(), op: anytype) !void {
        try writeOp(op, self.buffer.writer());
    }

    pub fn writeAll(self: *@This(), ops: anytype) !void {
        inline for (ops) |op| {
            try writeOp(op, self.buffer.writer());
        }
    }

    pub fn flush(self: *@This()) !void {
        try self.buffer.flush();
    }
};

/// Write the value, if it's type is supported, to the provider writer
///
/// Supported types:
///     - `[]const u8`
///     - `u8`, `u21`, `u32`, `comptime_int`
///     - Any type that implements `format` to be use with the string formatter
pub fn writeOp(op: anytype, writer: anytype) !void {
    const T = @TypeOf(op);
    switch (T) {
        u8 => try writer.writeByte(op),
        u21, u32, comptime_int => {
            var buff: [4]u8 = [_]u8{0}**4;
            const length = try std.unicode.utf8Encode(@intCast(op), &buff);
            try writer.writeAll(buff[0..length]);
        },
        else => {
            switch (@typeInfo(T)) {
                .@"struct" => {
                    if (@hasDecl(T, "format")) {
                        try writer.print("{s}", .{ op });
                    } else {
                        try writer.print(op[0], op[1]);
                    }
                },
                else => {
                    try writer.print("{s}", .{ op });
                }
            }
        }
    }
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

test {
    std.testing.refAllDecls(@This());
}
