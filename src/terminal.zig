const std = @import("std");
const Size = @import("root.zig").Size;
const Point = @import("root.zig").Point;
const builtin = @import("builtin");
const Query = @import("ansi.zig").Query;
const Action = @import("ansi.zig").Action;
const Cursor = @import("ansi.zig").Cursor;

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
    InvalidCusorPos,
};

const Context = switch (builtin.target.os.tag) {
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
        _old_stdin_mode: console.CONSOLE_MODE = console.CONSOLE_MODE{},
        _old_stdout_mode: console.CONSOLE_MODE = console.CONSOLE_MODE{},
        _old_cursor_pos: Point = Point{ 0, 0 },

        pub fn init() @This() {
            return .{};
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
            errdefer _ = console.SetConsoleMode(stdin, self._old_stdin_mode);

            mode = console.CONSOLE_MODE{};
            if (console.GetConsoleMode(stdout, &mode) != 0) {
                self._old_stdout_mode = mode;
            } else {
                return Error.UnkownStdoutMode;
            }
            errdefer _ = console.SetConsoleMode(stdout, self._old_stdout_mode);

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

            self.context_count -= 1;
            _ = console.SetConsoleMode(stdin, self._old_stdin_mode);
            _ = console.SetConsoleMode(stdout, self._old_stdout_mode);
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

arena: std.heap.ArenaAllocator,
allocator: std.mem.Allocator,

stdout: std.fs.File,
out: std.io.BufferedWriter(4096, std.fs.File.Writer),
stderr: std.fs.File,
err: std.io.BufferedWriter(4096, std.fs.File.Writer),
stdin: std.fs.File,
in: std.io.BufferedReader(4096, std.fs.File.Reader),
context: Context,

/// Create a new terminal context
///
/// @param allocator Allocator to use for the terminal query operations like getting cursor position
/// @return New terminal instance
pub fn init() !Terminal {
    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn();
    const stderr = std.io.getStdErr();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    return .{
        .allocator = arena.allocator(),
        .arena = arena,
        .context = Context.init(),
        .out = std.io.bufferedWriter(stdout.writer()),
        .stdout = std.io.getStdOut(),
        .err = std.io.bufferedWriter(stderr.writer()),
        .stderr = std.io.getStdOut(),
        .in = std.io.bufferedReader(stdin.reader()),
        .stdin = std.io.getStdOut(),
    };
}

/// Enter raw terminal mode clearing stdin in the process
pub fn enable_raw_mode(self: *Terminal) !void {
    try self.context.enter();
    self.context._old_cursor_pos = try self.cursorPos();
    try self.execute(.{
        Action.EnterAlternateBuffer,
        Cursor.pos(0, 0),
    });
}

/// Exit raw terminal mode
pub fn disable_raw_mode(self: *Terminal) !void {
    const cursor = self.context._old_cursor_pos;
    try self.execute(.{
        Action.ExitAlternateBuffer,
        Cursor.pos(cursor[0], cursor[1]),
    });
    self.context.exit();
}

/// Write with a format string and tuple args.
///
/// Note: This doesn't update right away and requires flush to be called
///
/// @param fmt Format string
/// @param args Tuple of arguments
/// @return error if out of memory or failed to write to the terminal
pub fn write(self: *Terminal, comptime fmt: []const u8, args: anytype) !void {
    const writer = self.out.writer();
    try writer.print(fmt, args);
}

/// Flushes the output
///
/// Note: This doesn't update right away and requires flush to be called
///
/// @return error if out of memory or failed to flush the terminal
pub fn flush(self: *Terminal) !void {
    try self.out.flush();
}

/// Print with a format string and tuple args.
///
/// Note: This flushes the output right away
///
/// @param fmt Format string
/// @param args Tuple of arguments
/// @return error if out of memory or failed to write to the terminal
pub fn print(self: *Terminal, comptime fmt: []const u8, args: anytype) !void {
    try self.write(fmt, args);
    try self.flush();
}

/// Execute a series of actions and prints and flush at the end.
///
/// Note: By using a tuple as the argument both strings and actiongs can be combined
///
/// @param operations Tuple of actions and strings
/// @return error if out of memory or failed to write to the terminal
pub fn execute(self: *Terminal, ops: anytype) !void {
    inline for (ops) |item| {
        const t = @TypeOf(item);
        switch (t) {
            u8 => try self.write("{c}", .{item}),
            u21 => {
                var buff: [4]u8 = [_]u8{0} ** 4;
                const length = try std.unicode.utf8Encode(item, &buff);
                try self.write("{s}", .{buff[0..length]});
            },
            u16 => {
                var buff: [2]u8 = [_]u8{0} ** 2;
                const length = try std.unicode.utf16LeToUtf8(&buff, [1]u16{item});
                try self.write("{s}", .{buff[0..length]});
            },
            Action => try self.write("{s}", .{item}),
            else => {
                try self.write("{s}", .{item});
            },
        }
    }
    try self.flush();
}

/// Check if the stdin buffer has data to read
///
/// @return true if there is data in the buffer
pub fn kbhit(self: *Terminal) bool {
    _ = self;
    switch (@import("builtin").target.os.tag) {
        .windows => {
            const console = @import("zigwin32").system.console;
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

/// Read a single character from the terminal
///
/// @return error if out of memory or failed to read from the terminal
pub fn read(self: *Terminal) !?u8 {
    return try self.in.reader().readByte();
}

/// Read a line from the terminal
///
/// @return error if out of memory or failed to read from the terminal
pub fn readLine(self: *Terminal, allocator: std.mem.Allocator) !?[]u8 {
    var reader = self.in.reader();
    return try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 10000);
}

/// Read from the terminal until the specified delimiter is found or the end of the stream is reached
///
/// @param delim The delimiter to read until
/// @return error if out of memory or failed to read from the terminal
pub fn readUntil(self: *Terminal, allocator: std.mem.Allocator, delim: u8) !?[]u8 {
    var reader = self.in.reader();
    return try reader.readUntilDelimiterOrEofAlloc(allocator, delim, 10000);
}

/// Free any resources used to query and manage the terminal state
pub fn deinit(self: *Terminal) void {
    self.arena.deinit();
}

// ------------------------------------
// --- Terminal Querying Functions ----
// ------------------------------------

/// Query the terminal for the size in cells
///
/// @return Size of the terminal as a tuple of u16; width and height
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

/// Query the terminal for the cursor position
///
/// @return Tuple of u16; x and y position
pub fn cursorPos(self: *Terminal) !Point {
    // Query for the cursor position then read the response
    try self.print("{s}", .{Query.CursorPos});
    const result = try self.readUntil(self.allocator, 'R');

    // Parse the ansi sequence for x and y position
    if (result) |r| {
        errdefer self.allocator.free(r);
        defer self.allocator.free(r);

        var start: usize = 0;
        while (start < r.len) : (start += 1) {
            if (r[start] == '[') {
                start += 1;
                break;
            }
        }

        if (start >= r.len) {
            return error.InvalidCursorPos;
        }

        var it = std.mem.split(u8, r[start..], ";");
        if (it.next()) |f| {
            if (it.next()) |s| {
                const x = try std.fmt.parseInt(u16, f, 10);
                const y = try std.fmt.parseInt(u16, s, 10);
                return .{ x, y };
            }
        }
    }
    return error.InvalidCusorPos;
}
