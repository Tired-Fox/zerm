const std = @import("std");

pub const os = switch (@import("builtin").target.os.tag) {
    .windows => struct {
        const console = @import("zigwin32").system.console;

        pub const STDIN = console.STD_INPUT_HANDLE;
        pub const STDOUT = console.STD_OUTPUT_HANDLE;
        pub const STDERR = console.STD_ERROR_HANDLE;

        pub const CONSOLE_MODE = console.CONSOLE_MODE;
        pub const EventType = enum(u16) {
            KEY_EVENT = 0x0001,
            MOUSE_EVENT = 0x0002,
            WINDOW_BUFFER_SIZE_EVENT = 0x0004,
            MENU_EVENT = 0x0008,
            FOCUS_EVENT = 0x0010,

            pub fn from(value: u16) @This() {
                return @enumFromInt(value);
            }
        };

        pub const KEY_EVENT_RECORD = console.KEY_EVENT_RECORD;
        pub const MOUSE_EVENT_RECORD = console.MOUSE_EVENT_RECORD;
        pub const INPUT_RECORD = console.INPUT_RECORD;

        pub const GetStdHandle = console.GetStdHandle;
        pub const GetConsoleMode = console.GetConsoleMode;
        pub const SetConsoleMode = console.SetConsoleMode;
        pub const PeekConsoleInput = console.PeekConsoleInputW;
        pub const GetNumberOfConsoleInputEvents = console.GetNumberOfConsoleInputEvents;
        pub const ReadConsoleInput = console.ReadConsoleInputW;
    },
    .linux => struct {
        const termios = std.os.linux.termios;
        const tcgetattr = std.os.linux.tcgetattr;
        const tcsetattr = std.os.linux.tcsetattr;
        const tc_lflag = std.os.linux.tc_lflag_t;
        const tc_iflag = std.os.linux.tc_iflag_t;
        const tc_oflag = std.os.linux.tc_oflag_t;
        const tc_cflag = std.os.linux.tc_cflag_t;

        const Error = error{
            GetAttrFailed,
            SetAttrFailed,
        };

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
    },
    else => @compileError("Unsupported OS"),
};
