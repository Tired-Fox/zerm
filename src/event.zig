const std = @import("std");
const builtin = @import("builtin");

/// Representation of keyboard input
pub const KeyCode = union(enum) {
    pub const Backspace: @This() = .{ .backspace = {} };
    pub const Enter: @This() = .{ .enter = {}};
    pub const Left: @This() = .{ .left = {}};
    pub const Right: @This() = .{ .right = {}};
    pub const Up: @This() = .{ .up = {}};
    pub const Down: @This() = .{ .down = {}};
    pub const Home: @This() = .{ .home = {}};
    pub const End: @This() = .{ .end = {}};
    pub const PageUp: @This() = .{ .page_up = {}};
    pub const PageDown: @This() = .{ .page_down = {}};
    pub const Tab: @This() = .{ .tab = {}};
    pub const BackTab: @This() = .{ .back_tab = {}};
    pub const Delete: @This() = .{ .delete = {}};
    pub const Insert: @This() = .{ .insert = {}};
    pub const Null: @This() = .{ .null = {}};
    pub const Esc: @This() = .{ .esc = {}};
    pub const CapsLock: @This() = .{ .caps_lock = {}};
    pub const ScrollLock: @This() = .{ .scroll_lock = {}};
    pub const NumLock: @This() = .{ .num_lock = {}};
    pub const PrintScreen: @This() = .{ .print_screen = {}};
    pub const Pause: @This() = .{ .pause = {}};
    pub const Menu: @This() = .{ .menu = {}};
    pub const KeypadBegin: @This() = .{ .keypad_begin = {}};

    backspace: void,
    enter: void,
    left: void,
    right: void,
    up: void,
    down: void,
    home: void,
    end: void,
    page_up: void,
    page_down: void,
    tab: void,
    back_tab: void,
    delete: void,
    insert: void,
    null: void,
    esc: void,
    caps_lock: void,
    scroll_lock: void,
    num_lock: void,
    print_screen: void,
    pause: void,
    menu: void,
    keypad_begin: void,

    f: u8,
    char: u21,
    media: Media,
    modifier: Modifier,

    pub fn f(value: u8) @This() {
        return .{ .f = value };
    }

    pub fn media(value: Media) @This() {
        return .{ .media = value };
    }

    pub fn modifier(value: Modifier) @This() {
        return .{ .modifier = value };
    }

    pub fn char(value: u21) @This() {
        return .{ .char = value };
    }

    pub const Media = enum {
        Play,
        Pause,
        PlayPause,
        Reverse,
        Stop,
        FastForward,
        Rewind,
        TrackNext,
        TrackPrevious,
        Record,
        LowerVolume,
        RaiseVolume,
        MuteVolume,
    };

    pub const Modifier = enum {
        LeftShift,
        LeftControl,
        LeftAlt,
        LeftSuper,
        LeftHyper,
        LeftMeta,
        RightShift,
        RightControl,
        RightAlt,
        RightSuper,
        RightHyper,
        RightMeta,
        IsoLevel3Shift,
        IsoLevel5Shift,
    };
};

/// Keyboard modifiers
pub const Modifiers = packed struct(u6) {
    alt: bool = false,
    ctrl: bool = false,
    shift: bool = false,
    super: bool = false,
    meta: bool = false,
    hyper: bool = false,

    pub fn merge(a: @This(), b: @This()) @This() {
        return .{
            .alt = a.alt or b.alt,
            .ctrl = a.ctrl or b.ctrl,
            .shift = a.shift or b.shift,
            .super = a.super or b.super,
            .meta = a.meta or b.meta,
            .hyper = a.hyper or b.hyper,
        };
    }
};

const Utils = switch (builtin.target.os.tag) {
    .windows => struct {
        extern "kernel32" fn GetNumberOfConsoleInputEvents(
            hConsoleInput: std.os.windows.HANDLE,
            lpcNumberOfEvents: *std.os.windows.DWORD
        ) callconv(.Win64) std.os.windows.BOOL;
    },
    else => struct {}
};

/// Read a line from the terminal
///
/// @return error if out of memory or failed to read from the terminal
pub fn readUntil(allocator: std.mem.Allocator, delim: u21, max_size: usize) !?[]u8 {
    return try std.io.getStdin().reader().readUntilDelimiterOrEofAlloc(allocator, delim, max_size);
}

/// Read a line from the terminal
///
/// @return error if out of memory or failed to read from the terminal
pub fn readLine(allocator: std.mem.Allocator, max_size: usize) !?[]u8 {
    return readUntil(allocator, '\n', max_size);
}

/// Keyboard event
pub const KeyEvent = struct {
    code: KeyCode,
    modifiers: Modifiers = .{},
    kind: Kind = .press,
    state: State = .{},

    pub fn matches(self: *const @This(), match: KeyMatch) bool {
        if (match.code) |code| {
            if (!std.meta.eql(code, self.code)) return false;
        }

        if (match.alt and !self.modifiers.alt) return false;
        if (match.ctrl and !self.modifiers.ctrl) return false;
        if (match.shift and !self.modifiers.shift) return false;
        if (match.super and !self.modifiers.super) return false;
        if (match.meta and !self.modifiers.meta) return false;
        if (match.hyper and !self.modifiers.hyper) return false;

        if (match.caps_lock and !self.state.caps_lock) return false;
        if (match.keypad and !self.state.keypad) return false;
        if (match.num_lock and !self.state.num_lock) return false;

        if (match.kind) |kind| {
            if (!std.meta.eql(kind, self.kind)) return false;
        }

        return true;
    }

    pub const KeyMatch = struct {
        code: ?KeyCode = null,
        kind: ?Kind = null,

        keypad: bool = false,
        caps_lock: bool = false,
        num_lock: bool = false,

        alt: bool = false,
        ctrl: bool = false,
        shift: bool = false,
        super: bool = false,
        meta: bool = false,
        hyper: bool = false,
    };

    pub const Kind = enum {
        press,
        release,
        repeat
    };

    pub const State = packed struct(u3) {
        pub const KEYPAD: @This() = .{ .keypad = true };
        pub const CAPS_LOCK: @This() = .{ .caps_lock = true };
        pub const NUM_LOCK: @This() = .{ .num_lock = true };

        keypad: bool = false,
        caps_lock: bool = false,
        num_lock: bool = false,

        pub fn none(self: *const @This()) bool {
            return @as(u3, @bitCast(self)) == 0;
        }

        pub fn Or(self: @This(), other: @This()) @This() {
            return .{
                .keypad = self.keypad or other.keypad,
                .caps_lock = self.caps_lock or other.caps_lock,
                .num_lock = self.num_lock or other.num_lock,
            };
        }
    };
};

/// Supported mouse button events
pub const MouseButton = enum(u4) {
    Left,
    Middle,
    Right,
    XButton1,
    XButton2,
    ScrollRight,
    ScrollLeft,
    Other
};

pub const ButtonState = enum(u2) { pressed, released };
pub const ScrollDirection = enum(u2) { up, down, left, right };

pub const EnhancementFlags = packed struct(u8) {
    disambiguate_escape_codes: bool = false,
    report_event_types: bool = false,
    report_alternate_keys: bool = false,
    report_all_keys_as_escape_codes: bool = false,
    // Not yet supported
    // report_associated_text: bool = false,
    _m: u4 = 0,
};

pub const MouseEventKind = union(enum) {
    pub const Move: @This() = .{ .move = {} };
    pub const ScrollDown: @This() = .{ .scroll = .down };
    pub const ScrollUp: @This() = .{ .scroll = .up };
    pub const ScrollLeft: @This() = .{ .scroll = .left };
    pub const ScrollRight: @This() = .{ .scroll = .right };

    move: void,

    down: MouseButton,
    up: MouseButton,
    drag: MouseButton,

    scroll: ScrollDirection,

    pub fn down(button: MouseButton) @This() {
        return .{ .down = button };
    }

    pub fn up(button: MouseButton) @This() {
        return .{ .up = button };
    }

    pub fn drag(button: MouseButton) @This() {
        return .{ .drag = button };
    }
};

pub const MouseEvent = struct {
    col: u16,
    row: u16,
    kind: MouseEventKind,
    modifiers: Modifiers = .{},
};

pub const Event = union(enum) {
    key: KeyEvent,
    mouse: MouseEvent,
    resize: std.meta.Tuple(&[_]type{ u16, u16 }),
    /// Requires `Capture.EnableFocus` to be executed
    focus: bool,
    /// Requires `Capture.EnableBracketedPaste` to be executed
    paste: []const u8,
    cursor: std.meta.Tuple(&[_]type { u16, u16 })
};

pub const EventStream = 
    if (builtin.os.tag == .windows) @import("./event/windows.zig").EventStream
    else @import("./event/tty.zig").EventStream;

test "event::Key::eql" {
    try std.testing.expect(KeyCode.Esc.eql(KeyCode.Esc));
    try std.testing.expect(KeyCode.char('d').eql(KeyCode.char('d')));
    try std.testing.expect(!KeyCode.char('d').eql(KeyCode.Esc));
}

test "event::Key::char" {
    try std.testing.expectEqual(KeyCode.char('d'), KeyCode { .char = 'd' });
}
