const std = @import("std");
const Size = @import("root.zig").Size;
const builtin = @import("builtin");

const IMPORTS = switch (builtin.target.os.tag) {
    .windows => struct {
        pub const console = @import("zigwin32").system.console;
        pub const STDIN = console.STD_INPUT_HANDLE;
        pub const STDOUT = console.STD_OUTPUT_HANDLE;
        pub const STDERR = console.STD_ERROR_HANDLE;
    },
    else => struct {},
};

const Terminal = @This();
const Error = error{
    UnkownStdinMode,
    UnkownStdoutMode,
    InvalidStdinEntry,
    InvalidStdoutEntry,
};

const Context = switch (@import("builtin").target.os.tag) {
    .windows => struct {
        const console = @import("zigwin32").system.console;
        const foundation = @import("zigwin32").foundation;
        const STDIN = console.STD_HANDLE.INPUT_HANDLE;
        const STDOUT = console.STD_HANDLE.OUTPUT_HANDLE;

        const ENABLE_STDIN_RAW_MODE = console.CONSOLE_MODE{
            .ENABLE_MOUSE_INPUT = 1,
            .ENABLE_VIRTUAL_TERMINAL_INPUT = 1,
            .ENABLE_EXTENDED_FLAGS = 1,
        };
        const ENABLE_STDOUT_RAW_MODE = console.CONSOLE_MODE{
            // Same as ENABLE_PROCESSED_OUTPUT
            .ENABLE_PROCESSED_INPUT = 1,
            // Same as ENABLE_VIRTUAL_TERMINAL_PROCESSING bitwise
            .ENABLE_ECHO_INPUT = 1,
        };

        context_count: usize = 0,
        _old_stdin_mode: ?console.CONSOLE_MODE = null,
        _old_stdout_mode: ?console.CONSOLE_MODE = null,

        pub fn init() @This() {
            return .{
                ._old_stdin_mode = null,
                ._old_stdout_mode = null,
            };
        }

        /// Logic for setting up the terminal mode/state for starting an application
        ///
        /// Note: This should only be called once at the start of an application
        pub fn enter(self: *@This()) !void {
            const stdin = console.GetStdHandle(STDIN);
            const stdout = console.GetStdHandle(STDOUT);

            self.context_count += 1;
            if (self.context_count > 1) {
                return;
            }

            var mode = console.CONSOLE_MODE{};
            if (console.GetConsoleMode(stdin, &mode) != 0) {
                self._old_stdin_mode = mode;
            } else {
                return Error.UnkownStdinMode;
            }
            errdefer if (self._old_stdin_mode) |m| {
                _ = console.SetConsoleMode(stdin, m);
            };

            mode = console.CONSOLE_MODE{};
            if (console.GetConsoleMode(stdout, &mode) != 0) {
                self._old_stdout_mode = mode;
            } else {
                return Error.UnkownStdoutMode;
            }
            errdefer if (self._old_stdout_mode) |m| {
                _ = console.SetConsoleMode(stdout, m);
            };

            if (console.SetConsoleMode(stdin, ENABLE_STDIN_RAW_MODE) == 0) {
                return Error.InvalidStdinEntry;
            }

            if (console.SetConsoleMode(stdout, ENABLE_STDOUT_RAW_MODE) == 0) {
                return Error.InvalidStdoutEntry;
            }
        }

        /// Logic for reseting the terminal mode/state when exiting an application
        ///
        /// Note: This should only be called once at the end of an application
        pub fn exit(self: *@This()) void {
            const stdin = console.GetStdHandle(STDIN);
            const stdout = console.GetStdHandle(STDOUT);

            if (self.context_count > 1) {
                self.context_count -= 1;
                return;
            } else if (self.context_count == 0) {
                return;
            }

            if (self._old_stdin_mode) |mode| {
                _ = console.SetConsoleMode(stdin, mode);
            }

            if (self._old_stdout_mode) |mode| {
                _ = console.SetConsoleMode(stdout, mode);
            }

            var mode = console.CONSOLE_MODE{};
            _ = console.GetConsoleMode(stdin, &mode);
            _ = console.GetConsoleMode(stdout, &mode);
            self._old_stdin_mode = null;
            self._old_stdout_mode = null;
        }
    },
    else => struct {
        pub fn enter(self: *@This()) void {
            _ = self;
        }
        pub fn exit(self: *@This()) void {
            _ = self;
        }
    },
};

stdout: std.fs.File,
out: std.io.BufferedWriter(4096, std.fs.File.Writer),
stderr: std.fs.File,
err: std.io.BufferedWriter(4096, std.fs.File.Writer),
stdin: std.fs.File,
in: std.io.BufferedReader(4096, std.fs.File.Reader),
context: Context,

pub fn init() !Terminal {
    // TODO: enter the terminal setting it up for tui like operations
    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn();
    const stderr = std.io.getStdErr();

    return .{
        .context = Context.init(),
        .out = std.io.bufferedWriter(stdout.writer()),
        .stdout = std.io.getStdOut(),
        .err = std.io.bufferedWriter(stderr.writer()),
        .stderr = std.io.getStdOut(),
        .in = std.io.bufferedReader(stdin.reader()),
        .stdin = std.io.getStdOut(),
    };
}

/// Write with a format string and tuple args.
///
/// Note: This doesn't update right away and requires flush to be called
pub fn write(self: *Terminal, comptime fmt: []const u8, args: anytype) !void {
    const writer = self.out.writer();
    try writer.print(fmt, args);
}

/// Flushes the output
///
/// Note: This doesn't update right away and requires flush to be called
pub fn flush(self: *Terminal) !void {
    try self.out.flush();
}

/// Print with a format string and tuple args.
///
/// Note: This flushes the output right away
pub fn print(self: *Terminal, comptime fmt: []const u8, args: anytype) !void {
    try self.write(fmt, args);
    try self.flush();
}

pub fn kbhit(self: *Terminal) bool {
    _ = self;
    switch (@import("builtin").target.os.tag) {
        .windows => {
            const console = IMPORTS.console;
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            const alloc = arena.allocator();

            const buff = alloc.alloc(console.INPUT_RECORD, 1) catch unreachable;

            var count: u32 = 0;
            const result = console.PeekConsoleInputW(console.GetStdHandle(IMPORTS.STDIN), buff.ptr, 1, &count);
            return result != 0 and count > 0;
        },
        else => {
            return false;
        },
    }
}

pub fn read(self: *Terminal) !?u8 {
    return try self.in.reader().readByte();
}

pub fn readLine(self: *Terminal, allocator: std.mem.Allocator) !?[]u8 {
    var reader = self.in.reader();
    return try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 10000);
}

pub fn readUntil(self: *Terminal, allocator: std.mem.Allocator, delim: u8) !?[]u8 {
    var reader = self.in.reader();
    return try reader.readUntilDelimiterOrEofAlloc(allocator, delim, 10000);
}

pub fn deinit(self: *Terminal) void {
    _ = self;
}

pub fn getSize(self: *const Terminal) Size {
    _ = self;
    switch (@import("builtin").target.os.tag) {
        .windows => {
            const console = @import("zigwin32").system.console;
            var info = console.CONSOLE_SCREEN_BUFFER_INFO{
                .dwSize = .{ .X = 0, .Y = 0 },
                .dwCursorPosition = .{ .X = 0, .Y = 0 },
                .wAttributes = .{},
                .srWindow = .{ .Left = 0, .Top = 0, .Right = 0, .Bottom = 0 },
                .dwMaximumWindowSize = .{ .X = 0, .Y = 0 },
            };
            _ = console.GetConsoleScreenBufferInfo(console.GetStdHandle(console.STD_OUTPUT_HANDLE), &info);

            return .{ @intCast(info.srWindow.Right - info.srWindow.Left + 1), @intCast(info.srWindow.Bottom - info.srWindow.Top + 1) };
        },
        else => {
            return .{ 0, 0 };
        },
    }
}
