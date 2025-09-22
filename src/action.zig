const std = @import("std");
const root = @import("root.zig");

const Utils = switch (@import("builtin").target.os.tag) {
    .windows => struct {
        extern "kernel32" fn GetConsoleMode(
            hConsoleInput: std.os.windows.HANDLE,
            lpMode: *CONSOLE_MODE
        ) callconv(.winapi) std.os.windows.BOOL;

        extern "kernel32" fn SetConsoleMode(
            hConsoleInput: std.os.windows.HANDLE,
            dwMode: CONSOLE_MODE
        ) callconv(.winapi) std.os.windows.BOOL;

        extern "kernel32" fn GetConsoleScreenBufferInfo(
            hConsoleInput: std.os.windows.HANDLE,
            console_screen_buffer_info: *CONSOLE_SCREEN_BUFFER_INFO
        ) callconv(.winapi) std.os.windows.BOOL;

        pub const COORD = packed struct {
            x: i16 = 0,
            y: i16 = 0,
        };

        pub const SMALL_RECT = packed struct {
            left: i16 = 0,
            top: i16 = 0,
            right: i16 = 0,
            bottom: i16 = 0,
        };

        pub const CONSOLE_SCREEN_BUFFER_INFO = packed struct {
            size: COORD = .{},
            cursor_position: COORD = .{},
            attributes: u16 = 0,
            windows: SMALL_RECT = .{},
            maximum_window_size: COORD = .{}
        };

        pub const CONSOLE_MODE = packed struct(u32) {
            ENABLE_PROCESSED_INPUT: u1 = 0,
            ENABLE_LINE_INPUT: u1 = 0,
            ENABLE_ECHO_INPUT: u1 = 0,
            ENABLE_WINDOW_INPUT: u1 = 0,
            ENABLE_MOUSE_INPUT: u1 = 0,
            ENABLE_INSERT_MODE: u1 = 0,
            ENABLE_QUICK_EDIT_MODE: u1 = 0,
            ENABLE_EXTENDED_FLAGS: u1 = 0,
            ENABLE_AUTO_POSITION: u1 = 0,
            ENABLE_VIRTUAL_TERMINAL_INPUT: u1 = 0,
            _m: u22 = 0,

            pub fn Not(self: @This()) @This() {
                return @bitCast(~@as(u32, @bitCast(self)));
            }

            pub fn And(self: @This(), other: @This()) @This() {
                return @bitCast(@as(u32, @bitCast(self)) & @as(u32, @bitCast(other)));
            }

            pub fn Or(self: @This(), other: @This()) @This() {
                return @bitCast(@as(u32, @bitCast(self)) | @as(u32, @bitCast(other)));
            }
        };


        pub const STDIN_MASK: CONSOLE_MODE = .{
            .ENABLE_ECHO_INPUT = 1,
            .ENABLE_LINE_INPUT = 1,
            .ENABLE_PROCESSED_INPUT = 1,
        };

        pub const STDOUT_MODE: CONSOLE_MODE = .{
            .ENABLE_ECHO_INPUT = 1,
            .ENABLE_PROCESSED_INPUT = 1,
        };

        pub const MOUSE_MASK: CONSOLE_MODE = .{
            .ENABLE_QUICK_EDIT_MODE = 1,
        };

        pub const MOUSE_MODE: CONSOLE_MODE = .{
            .ENABLE_MOUSE_INPUT = 1,
            .ENABLE_WINDOW_INPUT = 1,
            .ENABLE_EXTENDED_FLAGS = 1,
        };
    },
    else => struct {
        const termios = std.os.linux.termios;
        const tcgetattr = std.os.linux.tcgetattr;
        const tcsetattr = std.os.linux.tcsetattr;

        pub fn get_term_state(state: *termios) !void {
            if (tcgetattr(std.os.linux.STDIN_FILENO, state) == -1) {
                return error.GetAttrFailed;
            }
        }

        pub fn set_term_state(state: *const termios) !void {
            if (tcsetattr(std.os.linux.STDIN_FILENO, .NOW, state) == -1) {
                return error.SetAttrFailed;
            }
        }

        pub fn setup_flags(flags: *termios) void {
            setup_lflags(flags);
            setup_iflags(flags);
            setup_oflags(flags);
            setup_cflags(flags);
            setup_cc(flags, 0, 1);
        }

        pub fn setup_lflags(state: *termios) void {
            // Stop term from displaying pressed keys.
            state.lflag.ECHO = false;
            // Disable canonical ('cooked') input mode. Allows for reading input byte-wise instead of line-wise.
            state.lflag.ICANON = false;
            // Disable signals for Ctrl-C (SIGINT) and Ctrl-Z (SIGTSTP). Processed as normal escape sequences.
            state.lflag.ISIG = false;
            // Disable input processing. Allows handling of Ctrl-V instead of it being intercepted by the terminal.
            state.lflag.IEXTEN = false;
        }

        pub fn setup_iflags(state: *termios) void {
            // Disable software control flow. Allows handling of Ctrl-S and Ctrl-Q.
            state.iflag.IXON = false;
            // Disable converting carriage returns to newliness. Allows handling of Ctrl-M and Ctrl-J.
            state.iflag.ICRNL = false;
            // Disable converting SIGINT on break condition. For backwards compatibility.
            state.iflag.BRKINT = false;
            // Disable parity checking. Backwards compatibility.
            state.iflag.INPCK = false;
            // Disable stripping of 8th bit. Backwards compatibility.
            state.iflag.ISTRIP = false;
        }

        pub fn setup_oflags(state: *termios) void {
            state.oflag.OPOST = false;
        }

        pub fn setup_cflags(state: *termios) void {
            state.cflag.CSIZE = .CS8;
        }

        pub fn setup_cc(state: *termios, timeout: u8, min_bytes: u8) void {
            state.cc[@intFromEnum(std.os.linux.V.TIME)] = timeout;
            state.cc[@intFromEnum(std.os.linux.V.MIN)] = min_bytes;
        }
    }
};

/// State that is managed when setting and restoring terminal modes
const Mode = switch(@import("builtin").target.os.tag) {
    .windows => struct {
        mutex: std.Thread.Mutex = std.Thread.Mutex {},
        original: ?Utils.CONSOLE_MODE = null,
    },
    else => struct {
        mutex: std.Thread.Mutex = std.Thread.Mutex {},
        original: ?std.os.linux.termios = null
    },
};

var MODE: Mode = .{};

/// Terminal cursor commands
///
/// When `col` is mixed with `left` and/or `right` the formatter will attempt to optimize the commands into one
/// When `row` is mixed with `up` and/or `down` the formatter will attempt to optimize the commands into one
pub const Cursor = struct {
    /// Save the cursor position
    save: bool = false,
    /// Restore the previously saved cursor position
    restore: bool = false,

    /// Move the cursor up by N rows
    up: ?u16 = null,
    /// Move the cursor down by N rows
    down: ?u16 = null,
    /// Move the cursor left by N columns
    left: ?u16 = null,
    /// Move the cursor right by N columns
    right: ?u16 = null,
    /// Move to column X
    col: ?u16 = null,
    /// Move to row Y
    row: ?u16 = null,
    /// Change the cursor's visibility
    visibility: ?enum { visible, hidden } = null,
    /// Start or stop the cursor blinking
    blink: ?bool = null,
    /// Change the shape of the cursor
    shape: ?CursorShape = null,

    pub const CursorShape = enum {
        block,
        block_blink,
        underline,
        underline_blink,
        bar,
        bar_blink,
        user,
    };

    pub fn format(value: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
        if (value.save) try writer.print("\x1b[s", .{});
        if (value.restore) try writer.print("\x1b[u", .{});

        if (value.col != null and value.row != null) {
            const left = value.left orelse 0;
            const right = value.right orelse 0;
            const down = value.down orelse 0;
            const up = value.up orelse 0;

            var col = value.col.? + right;
            if (left >= col) col = 0 else col = col - left;

            var row = value.row.? + down;
            if (up >= row) row = 0 else row -= up;
            try writer.print("\x1b[{d};{d}H", .{ row, col });
        } else if (value.col) |_x| {
            const left = value.left orelse 0;
            const right = value.right orelse 0;
            var col = _x + right;
            if (left >= col) col = 0 else col = col - left;
            try writer.print("\x1b[{d}G", .{ col });

            if (value.up) |u| try writer.print("\x1b[{d}A", .{u});
            if (value.down) |d| try writer.print("\x1b[{d}B", .{d});
        } else if (value.row) |_y| {
            const down = value.down orelse 0;
            const up = value.up orelse 0;
            var row = _y + down;
            if (up >= row) row = 0 else row -= up;
            try writer.print("\x1b[{d}d", .{row});

            if (value.left) |b| try writer.print("\x1b[{d}D", .{b});
            if (value.right) |f| try writer.print("\x1b[{d}C", .{f});
        } else {
            if (value.up) |u| try writer.print("\x1b[{d}A", .{u});
            if (value.down) |d| try writer.print("\x1b[{d}B", .{d});
            if (value.left) |b| try writer.print("\x1b[{d}D", .{b});
            if (value.right) |f| try writer.print("\x1b[{d}C", .{f});
        }

        if (value.blink) |b| {
            if (b) try writer.print("\x1b[?12h", .{}) else try writer.print("\x1b[?12l", .{});
        }

        if (value.visibility) |visibility| {
            switch (visibility) {
                .visible => try writer.print("\x1b[?25h", .{}),
                .hidden => try writer.print("\x1b[?25l", .{}),
            }
        }

        if (value.shape) |s| {
            switch (s) {
                .user => try writer.print("\x1b[0 q", .{}),
                .block_blink => try writer.print("\x1b[1 q", .{}),
                .block => try writer.print("\x1b[2 q", .{}),
                .underline_blink => try writer.print("\x1b[3 q", .{}),
                .underline => try writer.print("\x1b[4 q", .{}),
                .bar_blink => try writer.print("\x1b[5 q", .{}),
                .bar => try writer.print("\x1b[6 q", .{}),
            }
        }
    }
};

/// Defines how much of something to erase
pub const Erase = enum(u2) {
    to_end = 0,
    from_beginning = 1,
    all = 2,
};

/// Screen/Canvas commands
pub const Screen = union(enum) {
    /// Apply a soft reset to the setup of the screen
    pub const soft_reset: @This() = .{ .soft_reset_screen = {} };
    /// Save the current screen
    pub const save: @This() = .{ .save_screen = {} };
    /// Restore the previously saved screen
    pub const restore: @This() = .{ .restore_screen = {} };

    /// Enter an alternate buffer
    pub const enter_alternate_buffer: @This() = .{ .enter_alternate_screen_buffer = {} };
    /// Leave the current alternate buffer, restoring the previous
    /// buffers text.
    pub const leave_alternate_buffer: @This() = .{ .leave_alternate_screen_buffer = {} };

    /// Scroll the screen up
    scroll_up: u16,
    /// Scroll the screen down
    scroll_down: u16,
    /// Erase a part of the screen
    erase: Erase,
    /// Change the terminal title
    title: []const u8,
    /// Resize the screen
    resize: struct { w: u16, h: u16 },

    /// Apply a soft reset to the setup of the screen
    soft_reset_screen: void,
    /// Save the current screen
    save_screen: void,
    /// Restore the previously saved screen
    restore_screen: void,

    /// Enter an alternate buffer
    enter_alternate_screen_buffer: void,
    /// Leave the current alternate buffer, restoring the previous
    /// buffers text.
    leave_alternate_screen_buffer: void,

    /// Enable terminal raw mode
    ///
    /// This means that all inputs including `ctrl+c` will be passed to the application
    pub fn enableRawMode() !void {
        switch(@import("builtin").target.os.tag) {
            .windows => {
                const stdin = try std.os.windows.GetStdHandle(std.os.windows.STD_INPUT_HANDLE);

                var mode = Utils.CONSOLE_MODE{};
                if (Utils.GetConsoleMode(stdin, &mode) == 0) {
                    return error.UnkownStdinMode;
                }

                mode = mode.And(Utils.STDIN_MASK.Not());

                if (Utils.SetConsoleMode(stdin, mode) == 0) {
                    return error.InvalidStdinEntry;
                }
            },
            else => {
                MODE.mutex.lock();
                defer MODE.mutex.unlock();

                if (MODE.original != null) {
                    return;
                }

                var state: std.os.linux.termios = undefined;
                try Utils.get_term_state(&state);

                MODE.original = state;

                Utils.setup_flags(&state);
                try Utils.set_term_state(&state);
            }
        }
    }

    /// Enable terminal raw mode restoring it's default behavior
    pub fn disableRawMode() !void {
        switch(@import("builtin").target.os.tag) {
            .windows => {
                const stdin = try std.os.windows.GetStdHandle(std.os.windows.STD_INPUT_HANDLE);

                var mode = Utils.CONSOLE_MODE{};
                if (Utils.GetConsoleMode(stdin, &mode) == 0) {
                    return error.UnkownStdinMode;
                }

                mode  = mode.Or(Utils.STDIN_MASK);
                if (Utils.SetConsoleMode(stdin, mode) == 0) {
                    return error.InvalidStdinEntry;
                }
            },
            else => {
                MODE.mutex.lock();
                defer MODE.mutex.unlock();

                if (MODE.original) |original| {
                    try Utils.set_term_state(&original);
                    MODE.original = null;
                }
            }
        }
    }

    /// Check if the terminal is in `raw mode`
    pub fn isRawModeEnabled() bool {
        switch(@import("builtin").target.os.tag) {
            .windows => {
                const stdin = std.os.windows.GetStdHandle(std.os.windows.STD_INPUT_HANDLE) catch return false;

                var mode = Utils.CONSOLE_MODE{};
                if (Utils.GetConsoleMode(stdin, &mode) == 0) {
                    return false;
                }

                return @as(u32, @bitCast(mode.And(Utils.STDIN_MASK))) == 0;
            },
            else => {
                MODE.mutex.lock();
                defer MODE.mutex.unlock();

                return MODE.original != null;
            }
        }
    }

    pub fn format(value: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
        switch (value) {
            .scroll_up => |u| try writer.print("\x1b[{d}S", .{u}),
            .scroll_down => |u| try writer.print("\x1b[{d}T", .{u}),
            .erase => |e| try writer.print("\x1b[{d}J", .{@intFromEnum(e)}),

            .soft_reset_screen => try writer.print("\x1b[!p", .{}),
            .title => |t| try writer.print("\x1b]0;{s}\x07", .{t}),
            .resize => |r| try writer.print("\x1b[8;{d};{d}t", .{ r.h, r.w }),

            .save_screen => try writer.print("\x1b[47h", .{}),
            .restore_screen => try writer.print("\x1b[47l", .{}),

            .enter_alternate_screen_buffer => try writer.print("\x1b[?1049h", .{}),
            .leave_alternate_screen_buffer => try writer.print("\x1b[?1049l", .{}),
        }
    }
};

/// Line commands
pub const Line = union(enum) {
    /// Insert new lines shifting lines on and after
    /// the cursor's position down
    insert: u16,
    /// Delete lines from the buffer starting with the
    /// line the cursor is one
    delete: u16,
    /// Erase all the specific lines with `space` characters
    erase: Erase,

    pub fn format(value: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
        switch (value) {
            .insert => |u| try writer.print("\x1b[{d}L", .{u}),
            .delete => |u| try writer.print("\x1b[{d}M", .{u}),
            .erase => |e| try writer.print("\x1b[{d}K", .{@intFromEnum(e)}),
        }
    }
};

/// Character commands
pub const Character = union(enum) {
    /// Insert spaces at the current cursor position,
    /// shifting all existing text to the right.
    ///
    /// All text that exit the screen to the right are removed
    insert: u16,
    /// Delete characters at the current cursor position,
    /// shifting in space characters fromt he right edge
    /// of the screen
    delete: u16,
    /// Erase characters from the current cursor position
    /// by overwriting them with a `space` character
    erase: u16,

    pub fn format(value: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
        switch (value) {
            .insert => |u| try writer.print("\x1b[{d}@", .{u}),
            .delete => |u| try writer.print("\x1b[{d}P", .{u}),
            .erase => |u| try writer.print("\x1b[{d}X", .{u}),
        }
    }
};

/// Commands to change what the terminal captures
/// and sends and input ansi sequences.
pub const Capture = enum {
    /// Enable mouse events
    enable_mouse,
    /// Disable mouse events
    disable_mouse,
    /// Enable focus events
    enable_focus,
    /// Disable focus events
    disable_focus,
    /// Enable custom handling for content that is pasted
    /// into the terminal
    enable_bracketed_paste,
    /// Disable custom handling for content that is pasted
    /// into the terminal
    disable_bracketed_paste,

    pub fn format(value: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
        switch(value) {
            .enable_mouse => {
                switch(@import("builtin").target.os.tag) {
                    .windows => {
                        MODE.mutex.lock();
                        defer MODE.mutex.unlock();
                        const stdin = std.os.windows.GetStdHandle(std.os.windows.STD_INPUT_HANDLE) catch return error.WriteFailed;

                        var mode = Utils.CONSOLE_MODE{};
                        if (Utils.GetConsoleMode(stdin, &mode) == 0) {
                            return error.WriteFailed;
                        }
                        MODE.original = mode;

                        // Disable flags that are in mask and enable
                        // the others that are in the mode
                        mode = mode.And(Utils.MOUSE_MASK.Not())
                            .Or(Utils.MOUSE_MODE);

                        if (Utils.SetConsoleMode(stdin, mode) == 0) {
                            return error.WriteFailed;
                        }
                    },
                    // ?1000h: Normal tracking: Send mouse X & Y on button press and release
                    // ?1002h: Button-event tracking: Report button motion events (dragging)
                    // ?1003h: Any-event tracking: Report all motion events
                    // ?1015h: RXVT mouse mode: Allows mouse coordinates of >223
                    // ?1006h: SGR mouse mode: Allows mouse coordinates of >223, preferred over RXVT mode
                    else => try writer.print("\x1b[?1000h\x1b[?1002h\x1b[?1003h\x1b[?1015h\x1b[?1006h", .{}),
                }
            },
            .disable_mouse => {
                switch(@import("builtin").target.os.tag) {
                    .windows => {
                        MODE.mutex.lock();
                        defer MODE.mutex.unlock();
                        if (MODE.original) |original| {
                            const stdin = std.os.windows.GetStdHandle(std.os.windows.STD_INPUT_HANDLE) catch return error.WriteFailed;
                            if (Utils.SetConsoleMode(stdin, original) == 0) {
                                return error.WriteFailed;
                            }
                        }
                    },
                    else => try writer.print("\x1b[?1006l\x1b[?1015l\x1b[?1003h\x1b[?1002l\x1b[?1000l", .{}),
                }
            },
            .enable_focus => try writer.print("\x1b[?1004h", .{}),
            .disable_focus => try writer.print("\x1b[?1004l", .{}),
            .enable_bracketed_paste => try writer.print("\x1b[?2004h", .{}),
            .disable_bracketed_paste => try writer.print("\x1b[?2004h", .{}),
        }
    }
};

/// Queries the terminal for the cursor position
///
/// This will send a `\x1B[6n` sequence to stdout and read stdin
/// until `\x1b[x;yR` is read.
pub fn getCursorPos() !std.meta.Tuple(&[_]type{ u16, u16 }) {
    // Query for cursor position
    {
        var buffer: [8]u8 = undefined;
        var writer = std.fs.File.stdout().writer(&buffer);
        try writer.interface.print("\x1b[6n", .{});
        try writer.interface.flush();
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var stream = @import("./event/tty.zig").EventStream.init(arena.allocator());
    defer stream.deinit();

    if (Screen.isRawModeEnabled()) {
        // TODO: Timeout
        while (true) {
            if (try stream.parseEvent()) |evt| {
                switch (evt) {
                    .cursor => |pos| return pos,
                    else => {}
                }
            }
        }
    } else {
        try Screen.enableRawMode();
        defer Screen.disableRawMode() catch {};

        // TODO: Timeout
        while (true) {
            if (try stream.parseEvent()) |evt| {
                switch (evt) {
                    .cursor => |pos| return pos,
                    else => {}
                }
            }
        }
    }
}

/// Get the current terminals size { COLS, ROWS }
pub fn getTermSize() !std.meta.Tuple(&[_]type{ u16, u16 }) {
    switch (@import("builtin").target.os.tag) {
        .windows => {
            const stdout = try std.os.windows.GetStdHandle(std.os.windows.STD_OUTPUT_HANDLE);

            var info = Utils.CONSOLE_SCREEN_BUFFER_INFO {};
            if (Utils.GetConsoleScreenBufferInfo(stdout, &info) == 0) {
                return error.GetConsoleScreenBufferInfo;
            }

            const size = info.size;
            return .{ @intCast(size.x), @intCast(size.y) };
        },
        else => {
            const stdout = std.os.linux.STDOUT_FILENO;
            const tiocgwinsz = std.os.linux.T.IOCGWINSZ;
            const winsize = std.os.linux.winsize;

            var size = winsize {};
            std.os.linux.ioctl(stdout, tiocgwinsz, &size);

            return .{ size.ws_col, size.ws_row };
        },
    }
}

/// Get the current terminals size in pixels { X, Y }
///
/// **NOTE**: Windows is not supported and will always return { 0, 0 }
pub fn getTermSizePixels() !std.meta.Tuple(&[_]type{ u16, u16 }) {
    switch (@import("builtin").target.os.tag) {
        .windows => {
            return .{ 0, 0 };
        },
        else => {
            const stdout = std.os.linux.STDOUT_FILENO;
            const tiocgwinsz = std.os.linux.T.IOCGWINSZ;
            const winsize = std.os.linux.winsize;

            var size = winsize {};
            std.os.linux.ioctl(stdout, tiocgwinsz, &size);

            return .{ size.ws_xpixel, size.ws_ypixel };
        },
    }
}

test "action::Capture::format" {
    if (@import("builtin").target.os.tag != .windows) {
        var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Capture.enable_mouse });
        try std.testing.expect(std.mem.eql(u8, format, "\x1b[?1000h\x1b[?1002h\x1b[?1003h\x1b[?1015h\x1b[?1006h"));
        std.testing.allocator.free(format);

        format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Capture.disable_mouse });
        try std.testing.expect(std.mem.eql(u8, format, "\x1b[?1006l\x1b[?1015l\x1b[?1003h\x1b[?1002l\x1b[?1000l"));
        std.testing.allocator.free(format);
    }

    var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Capture.enable_focus });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[?1004h"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Capture.disable_focus });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[?1004l"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Capture.enable_bracketed_paste });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[?2004h"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Capture.disable_bracketed_paste });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[?2004l"));
    std.testing.allocator.free(format);
}

test "action::Cursor::format" {
    var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Cursor {
        .up = 1,
        .down = 2,
        .left = 3,
        .right = 4,
        .blink = true,
        .visibility = .visible,
        .shape = .bar,
    }});
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1A\x1b[2B\x1b[3D\x1b[4C\x1b[?12h\x1b[?25h\x1b[6 q"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Cursor {
        .col = 5,
        .row = 6,
    }});
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[6;5H"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Cursor {
        .save = true,
        .restore = true,
    }});
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[s\x1b[u"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Cursor {
        .col = 5,
        .blink = false,
        .visibility = .hidden,
        .shape = .block,
    }});
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[5G\x1b[?12l\x1b[?25l\x1b[2 q"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Cursor {
        .row = 6,
        .shape = .underline,
    }});
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[6d\x1b[4 q"));
    std.testing.allocator.free(format);
}

test "action::Screen::format" {
    var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.EnterAlternateBuffer });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[?1049h"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.LeaveAlternateBuffer });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[?1049l"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.SoftReset });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[!p"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.Save });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[47h"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.Restore });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[47l"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen{ .scroll_up = 1 } });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1S"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen{ .scroll_down = 2 } });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[2T"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen{ .erase = .to_end} });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[0J"));
    std.testing.allocator.free(format);
    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen{ .erase = .from_beginning } });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1J"));
    std.testing.allocator.free(format);
    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen{ .erase = .all } });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[2J"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen{ .title = "test title" } });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b]0;test title\x07"));
    std.testing.allocator.free(format);
}

test "action::Line::format" {
    var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Line{ .insert = 1 } });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1L"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Line{ .delete = 2 } });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[2M"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Line{ .erase = .to_end } });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[0K"));
    std.testing.allocator.free(format);
    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Line{ .erase = .from_beginning } });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1K"));
    std.testing.allocator.free(format);
    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Line{ .erase = .all } });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[2K"));
    std.testing.allocator.free(format);
}

test "action::Character::format" {
    var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Character{ .insert = 1 } });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1@"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Character{ .delete = 2 } });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[2P"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Character{ .erase = 3 } });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[3X"));
    std.testing.allocator.free(format);
}
