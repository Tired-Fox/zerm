const std = @import("std");
const builtin = @import("builtin");

const os = @import("os.zig").os;
const Size = @import("root.zig").Size;
const Point = @import("root.zig").Point;

const Event = @import("events.zig").Event;
const Query = @import("ansi.zig").Query;
const Action = @import("ansi.zig").Action;
const Cursor = @import("ansi.zig").Cursor;
const Screen = @import("ansi.zig").Screen;

const parseEscapeSequence = @import("events.zig").parseEscapeSequence;

const Terminal = @This();
const Error = error{
    UnkownStdinMode,
    UnkownStdoutMode,
    InvalidStdinEntry,
    InvalidStdoutEntry,
    InvalidCusorPos,
    ReadConsoleInputFailure,
};

const Context = switch (builtin.target.os.tag) {
    .windows => struct {
        const STDIN = os.STDIN;
        const STDOUT = os.STDOUT;
        const CONSOLE_MODE = os.CONSOLE_MODE;
        const GetStdHandle = os.GetStdHandle;
        const GetConsoleMode = os.GetConsoleMode;
        const SetConsoleMode = os.SetConsoleMode;

        var ENABLE_STDIN_RAW_MODE = CONSOLE_MODE{
            .ENABLE_MOUSE_INPUT = 1,
            .ENABLE_VIRTUAL_TERMINAL_INPUT = 1,
            .ENABLE_EXTENDED_FLAGS = 1,
        };
        var ENABLE_STDOUT_RAW_MODE = CONSOLE_MODE{
            // Same as ENABLE_PROCESSED_OUTPUT
            .ENABLE_PROCESSED_INPUT = 1,
            // Same as ENABLE_VIRTUAL_TERMINAL_PROCESSING bitwise
            .ENABLE_ECHO_INPUT = 1,
        };

        context_count: usize = 0,
        _old_stdin_mode: CONSOLE_MODE = CONSOLE_MODE{},
        _old_stdout_mode: CONSOLE_MODE = CONSOLE_MODE{},
        _old_cursor_pos: Point = Point{ 0, 0 },

        pub fn init() @This() {
            return .{};
        }

        /// Logic for setting up the terminal mode/state for starting an application
        ///
        /// Note: This should only be called once at the start of an application
        pub fn enter(self: *@This()) !void {
            const stdin = GetStdHandle(STDIN);
            const stdout = GetStdHandle(STDOUT);

            self.context_count += 1;
            if (self.context_count > 1) {
                return;
            }

            var mode = CONSOLE_MODE{};

            if (GetConsoleMode(stdin, &mode) != 0) {
                self._old_stdin_mode = mode;
            } else {
                return Error.UnkownStdinMode;
            }
            errdefer _ = SetConsoleMode(stdin, self._old_stdin_mode);

            if (GetConsoleMode(stdout, &mode) != 0) {
                self._old_stdout_mode = mode;
            } else {
                return Error.UnkownStdoutMode;
            }
            errdefer _ = SetConsoleMode(stdout, self._old_stdout_mode);

            if (SetConsoleMode(stdin, ENABLE_STDIN_RAW_MODE) == 0) {
                return Error.InvalidStdinEntry;
            }

            if (SetConsoleMode(stdout, ENABLE_STDOUT_RAW_MODE) == 0) {
                return Error.InvalidStdoutEntry;
            }
        }

        /// Logic for reseting the terminal mode/state when exiting an application
        ///
        /// Note: This should only be called once at the end of an application
        pub fn exit(self: *@This()) !void {
            const stdin = GetStdHandle(STDIN);
            const stdout = GetStdHandle(STDOUT);

            if (self.context_count > 1) {
                self.context_count -= 1;
                return;
            } else if (self.context_count == 0) {
                return;
            }

            self.context_count -= 1;
            _ = SetConsoleMode(stdin, self._old_stdin_mode);
            _ = SetConsoleMode(stdout, self._old_stdout_mode);
        }
    },
    .linux => struct {
        _old_mode: os.termios = undefined,
        _old_cursor_pos: Point = Point{ 0, 0 },

        pub fn init() @This() {
            return .{};
        }

        pub fn enter(self: *@This()) !void {
            try os.get_term_state(&self._old_mode);

            var raw = self._old_mode;
            os.setup_flags(&raw);

            try os.set_term_state(&raw);
        }

        pub fn exit(self: *@This()) !void {
            try os.set_term_state(&self._old_mode);
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
        Screen.save(),
        Action.EnterAlternateBuffer,
        Cursor.pos(0, 0),
    });
}

/// Exit raw terminal mode
pub fn disable_raw_mode(self: *Terminal) !void {
    try self.context.exit();
    const cursor = self.context._old_cursor_pos;
    try self.execute(.{
        Action.ExitAlternateBuffer,
        Screen.restore(),
        Cursor.pos(cursor[0], cursor[1]),
    });
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
pub fn hasEvent(self: *Terminal) bool {
    _ = self;
    switch (@import("builtin").target.os.tag) {
        .windows => {
            var count: u32 = 0;
            const result = os.GetNumberOfConsoleInputEvents(os.GetStdHandle(os.STDIN), &count);
            return result != 0 and count > 0;
        },
        .linux => {
            var buffer: [1]std.os.linux.pollfd = [_]std.os.linux.pollfd{std.os.linux.pollfd{
                .fd = std.os.linux.STDIN_FILENO,
                .events = std.os.linux.POLL.IN,
                .revents = 0,
            }};
            return std.os.linux.poll(&buffer, 1, 1) > 0;
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

pub fn readEvent(self: *Terminal) !?Event {
    _ = self;
    switch (builtin.target.os.tag) {
        .windows => {
            var num_read: u32 = 0;
            if (os.GetNumberOfConsoleInputEvents(os.GetStdHandle(os.STDIN), &num_read) == 0) {
                return error.ReadConsoleInputFailure;
            }

            if (num_read > 2) {
                var checkBuff: [2]os.INPUT_RECORD = [_]os.INPUT_RECORD{undefined} ** 2;

                // TODO: Peek and check for escape sequence
                if (os.PeekConsoleInput(os.GetStdHandle(os.STDIN), &checkBuff, 2, &num_read) == 0) {
                    return error.ReadConsoleInputFailure;
                }

                const isLeadingEscape = checkBuff[0].EventType == 0x0001 and checkBuff[0].Event.KeyEvent.uChar.AsciiChar == 27;
                const isEscapeSequence = checkBuff[1].EventType == 0x0001 and (checkBuff[1].Event.KeyEvent.uChar.AsciiChar == 79 or checkBuff[1].Event.KeyEvent.uChar.AsciiChar == 91);

                if (isLeadingEscape and isEscapeSequence) {
                    // Remove leading escape sequence start
                    if (os.ReadConsoleInput(os.GetStdHandle(os.STDIN), &checkBuff, 2, &num_read) == 0) {
                        return error.ReadConsoleInputFailure;
                    }

                    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                    defer arena.deinit();
                    const allocator = arena.allocator();

                    var collected = std.ArrayList(u8).init(allocator);
                    try collected.append(checkBuff[1].Event.KeyEvent.uChar.AsciiChar);

                    if (os.GetNumberOfConsoleInputEvents(os.GetStdHandle(os.STDIN), &num_read) == 0) {
                        return error.ReadConsoleInputFailure;
                    }

                    var buffer: [1]os.INPUT_RECORD = [_]os.INPUT_RECORD{undefined};
                    while (true) {
                        if (os.ReadConsoleInput(os.GetStdHandle(os.STDIN), &buffer, 1, &num_read) == 0) {
                            return error.ReadConsoleInputFailure;
                        }

                        if (num_read != 0) {
                            if (buffer[0].EventType == 0x0001) {
                                // TODO: Better handling of u8 vs u16
                                const char = buffer[0].Event.KeyEvent.uChar.AsciiChar;
                                try collected.append(buffer[0].Event.KeyEvent.uChar.AsciiChar);
                                // Characters 0x40..0x7E indicate that the escape sequence is complete
                                if (char >= 0x40 and char <= 0x7E) {
                                    break;
                                }
                            } else {
                                // Not a full escape sequence so throw away collected and report other event instead
                                return Event.from(buffer[0]);
                            }
                        }
                    }

                    // TODO: Translate collected into parsed escape sequence
                    return try parseEscapeSequence(try collected.toOwnedSlice());
                }
            }

            var buff: [1]os.INPUT_RECORD = [_]os.INPUT_RECORD{
                os.INPUT_RECORD{
                    .EventType = 0x0010,
                    .Event = .{
                        .FocusEvent = .{
                            .bSetFocus = 0,
                        },
                    },
                },
            };
            if (os.ReadConsoleInput(os.GetStdHandle(os.STDIN), &buff, 1, &num_read) == 0) {
                return error.ReadConsoleInputFailure;
            }
            if (num_read > 0) {
                return Event.from(buff[0]);
            }
            return null;
        },
        .linux => {
            return Event.other;
        },
        else => @compileError("Unsupported OS"),
    }
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
