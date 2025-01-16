const std = @import("std");
const Source = @import("root.zig").Source;

const Utils = switch (@import("builtin").target.os.tag) {
    .windows => struct {
        extern "kernel32" fn GetConsoleMode(
            hConsoleInput: std.os.windows.HANDLE,
            lpMode: *CONSOLE_MODE
        ) callconv(.Win64) std.os.windows.BOOL;

        extern "kernel32" fn SetConsoleMode(
            hConsoleInput: std.os.windows.HANDLE,
            dwMode: CONSOLE_MODE
        ) callconv(.Win64) std.os.windows.BOOL;

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
            _m: u22 = 0
        };

        pub const ENABLE_STDIN_RAW_MODE: CONSOLE_MODE = .{
            .ENABLE_MOUSE_INPUT = 1,
            .ENABLE_VIRTUAL_TERMINAL_INPUT = 1,
            .ENABLE_EXTENDED_FLAGS = 1,
        };

        pub const ENABLE_STDOUT_RAW_MODE: CONSOLE_MODE = .{
            // Same as ENABLE_PROCESSED_OUTPUT
            .ENABLE_PROCESSED_INPUT = 1,
            // Same as ENABLE_VIRTUAL_TERMINAL_PROCESSING bitwise
            .ENABLE_ECHO_INPUT = 1,
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

const Mode = switch(@import("builtin").target.os.tag) {
    .windows => struct {
        mutex: std.Thread.Mutex = std.Thread.Mutex {},
        original_stdin: ?Utils.CONSOLE_MODE = null,
        original_stdout: ?Utils.CONSOLE_MODE = null
    },
    else => struct {
        mutex: std.Thread.Mutex = std.Thread.Mutex {},
        original: ?std.os.linux.termios = null
    },
};

var MODE: Mode = .{};

pub const Canvas = enum {

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s}", .{switch (value) {
            .EnterAlternateBuffer => "\x1b[?1049h",
            .ExitAlternateBuffer => "\x1b[?1049l",
            .SaveCursor => "\x1b[s",
            .RestoreCursor => "\x1b[u",
        }});
    }
};

pub const Cursor = struct {
    up: ?u16 = null,
    down: ?u16 = null,
    left: ?u16 = null,
    right: ?u16 = null,
    col: ?u16 = null,
    row: ?u16 = null,
    visibility: ?enum { visible, hidden } = null,
    blink: ?bool = null,
    shape: ?enum {
        block,
        block_blink,
        underline,
        underline_blink,
        bar,
        bar_blink,
        user,
    } = null,

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        if (value.up) |u| {
            try writer.print("\x1b[{d}A", .{u});
        }

        if (value.down) |d| {
            try writer.print("\x1b[{d}B", .{d});
        }

        if (value.left) |b| {
            try writer.print("\x1b[{d}D", .{b});
        }

        if (value.right) |f| {
            try writer.print("\x1b[{d}C", .{f});
        }

        if (value.col != null and value.row != null) {
            try writer.print("\x1b[{d};{d}H", .{ value.row.?, value.col.? });
        } else if (value.col) |_x| {
            try writer.print("\x1b[{d}G", .{_x});
        } else if (value.row) |_y| {
            try writer.print("\x1b[{d}d", .{_y});
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

        if (value.shape) |shape| {
            switch (shape) {
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

pub const Erase = enum(u2) {
    ToEnd = 0,
    FromBeginning = 1,
    All = 2,
};

pub const Screen = union(enum) {
    pub const SoftReset: @This() = .{ .soft_reset = {} };
    pub const Save: @This() = .{ .save = {} };
    pub const Restore: @This() = .{ .restore = {} };

    pub const EnterAlternateBuffer: @This() = .{ .enter_alternate_buffer = {} };
    pub const LeaveAlternateBuffer: @This() = .{ .leave_alternate_buffer = {} };
    pub const SaveCursor: @This() = .{ .save_cursor = {} };
    pub const RestoreCursor: @This() = .{ .restore_cursor = {} };


    scroll_up: u16,
    scroll_down: u16,
    erase: Erase,
    title: []const u8,
    soft_reset: void,
    save: void,
    restore: void,

    enter_alternate_buffer: void,
    leave_alternate_buffer: void,
    save_cursor: void,
    restore_cursor: void,

    pub fn enable_raw_mode(source: Source) !void {
        MODE.mutex.lock();
        defer MODE.mutex.unlock();

        switch(@import("builtin").target.os.tag) {
            .windows => {
                const stdin = try std.os.windows.GetStdHandle(std.os.windows.STD_INPUT_HANDLE);
                const stdout = try std.os.windows.GetStdHandle(if (source == .Stdout) std.os.windows.STD_OUTPUT_HANDLE else std.os.windows.STD_ERROR_HANDLE);

                if (MODE.original_stdin != null or MODE.original_stdout != null) {
                    return;
                }

                var mode = Utils.CONSOLE_MODE{};

                if (Utils.GetConsoleMode(stdin, &mode) != 0) {
                     MODE.original_stdin = mode;
                } else {
                    return error.UnkownStdinMode;
                }
                errdefer if (MODE.original_stdin) |original| {
                    _ = Utils.SetConsoleMode(stdin, original);
                    MODE.original_stdin = null;
                };

                if (Utils.GetConsoleMode(stdout, &mode) != 0) {
                    MODE.original_stdout = mode;
                } else {
                    return error.UnkownStdoutMode;
                }
                errdefer if (MODE.original_stdout) |original| {
                    _ = Utils.SetConsoleMode(stdout, original);
                    MODE.original_stdout = null;
                };

                if (Utils.SetConsoleMode(stdin, Utils.ENABLE_STDIN_RAW_MODE) == 0) {
                    return error.InvalidStdinEntry;
                }

                if (Utils.SetConsoleMode(stdout, Utils.ENABLE_STDOUT_RAW_MODE) == 0) {
                    return error.InvalidStdoutEntry;
                }
            },
            else => {
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

    pub fn disable_raw_mode(source: Source) !void {
        MODE.mutex.lock();
        defer MODE.mutex.unlock();

        switch(@import("builtin").target.os.tag) {
            .windows => {
                const stdin = try std.os.windows.GetStdHandle(std.os.windows.STD_INPUT_HANDLE);
                const stdout = try std.os.windows.GetStdHandle(if (source == .Stdout) std.os.windows.STD_OUTPUT_HANDLE else std.os.windows.STD_ERROR_HANDLE);

                if (MODE.original_stdin) |original| {
                    _ = Utils.SetConsoleMode(stdin, original);
                    MODE.original_stdin = null;
                }

                if (MODE.original_stdout) |original| {
                    _ = Utils.SetConsoleMode(stdout, original);
                    MODE.original_stdout = null;
                }
            },
            else => {
                if (MODE.original) |original| {
                    try Utils.set_term_state(&original);
                    MODE.original = null;
                }
            }
        }
    }


    pub fn scroll_up(u: u16) @This() {
        return .{ .scroll_up = u };
    }

    pub fn scroll_down(d: u16) @This() {
        return .{ .scroll_down = d };
    }

    pub fn erase(e: Erase) @This() {
        return .{ .erase = e };
    }

    pub fn title(t: []const u8) @This() {
        return .{ .title = t };
    }

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (value) {
            .scroll_up => |u| try writer.print("\x1b[{d}S", .{u}),
            .scroll_down => |u| try writer.print("\x1b[{d}T", .{u}),
            .erase => |e| try writer.print("\x1b[{d}J", .{@intFromEnum(e)}),

            .soft_reset => try writer.print("\x1b[!p", .{}),
            .title => |t| try writer.print("\x1b]0;{s}\x07", .{t}),

            .save => try writer.print("\x1b[47h", .{}),
            .restore => try writer.print("\x1b[47l", .{}),

            .enter_alternate_buffer => try writer.print("\x1b[?1049h", .{}),
            .leave_alternate_buffer => try writer.print("\x1b[?1049l", .{}),

            .save_cursor => try writer.print("\x1b[s", .{}),
            .restore_cursor => try writer.print("\x1b[u", .{}),
        }
    }
};

pub const Line = union(enum) {
    insert: u16,
    delete: u16,
    erase: Erase,

    pub fn insert(i: u16) @This() {
        return .{ .insert = i };
    }

    pub fn delete(d: u16) @This() {
        return .{ .delete = d };
    }

    pub fn erase(e: Erase) @This() {
        return .{ .erase = e };
    }

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (value) {
            .insert => |u| try writer.print("\x1b[{d}L", .{u}),
            .delete => |u| try writer.print("\x1b[{d}M", .{u}),
            .erase => |e| try writer.print("\x1b[{d}K", .{@intFromEnum(e)}),
        }
    }
};

pub const Character = union(enum) {
    insert: u16,
    delete: u16,
    erase: u16,

    pub fn insert(i: u16) @This() {
        return .{ .insert = i };
    }

    pub fn delete(d: u16) @This() {
        return .{ .delete = d };
    }

    pub fn erase(e: u16) @This() {
        return .{ .erase = e };
    }

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (value) {
            .insert => |u| try writer.print("\x1b[{d}@", .{u}),
            .delete => |u| try writer.print("\x1b[{d}P", .{u}),
            .erase => |u| try writer.print("\x1b[{d}X", .{u}),
        }
    }
};

test "action::Canvas::format" {
}

test "action::Cursor::format" {
    var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Cursor {
        .up = 1,
        .down = 2,
        .left = 3,
        .right = 4,
        .col = 5,
        .row = 6,
        .blink = true,
        .visibility = .visible,
        .shape = .bar,
    }});
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1A\x1b[2B\x1b[3D\x1b[4C\x1b[6;5H\x1b[?12h\x1b[?25h\x1b[6 q"));
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

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.SaveCursor });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[s"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.RestoreCursor });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[u"));
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

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.scroll_up(1) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1S"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.scroll_down(2) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[2T"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.erase(.ToEnd) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[0J"));
    std.testing.allocator.free(format);
    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.erase(.FromBeginning) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1J"));
    std.testing.allocator.free(format);
    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.erase(.All) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[2J"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.title("test title") });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b]0;test title\x07"));
    std.testing.allocator.free(format);
}

test "action::Line::format" {
    var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Line.insert(1) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1L"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Line.delete(2) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[2M"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Line.erase(.ToEnd) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[0K"));
    std.testing.allocator.free(format);
    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Line.erase(.FromBeginning) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1K"));
    std.testing.allocator.free(format);
    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Line.erase(.All) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[2K"));
    std.testing.allocator.free(format);
}

test "action::Character::format" {
    var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Character.insert(1) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1@"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Character.delete(2) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[2P"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Character.erase(3) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[3X"));
    std.testing.allocator.free(format);
}
