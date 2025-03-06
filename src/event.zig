const std = @import("std");
const builtin = @import("builtin");

/// Representation of keyboard input
pub const KeyCode = union(enum) {
    pub const backspace: @This() = .{ ._backspace = {} };
    pub const enter: @This() = .{ ._enter = {}};
    pub const left: @This() = .{ ._left = {}};
    pub const right: @This() = .{ ._right = {}};
    pub const up: @This() = .{ ._up = {}};
    pub const down: @This() = .{ ._down = {}};
    pub const home: @This() = .{ ._home = {}};
    pub const end: @This() = .{ ._end = {}};
    pub const page_up: @This() = .{ ._page_up = {}};
    pub const page_down: @This() = .{ ._page_down = {}};
    pub const tab: @This() = .{ ._tab = {}};
    pub const back_tab: @This() = .{ ._back_tab = {}};
    pub const delete: @This() = .{ ._delete = {}};
    pub const insert: @This() = .{ ._insert = {}};
    pub const @"null": @This() = .{ ._null = {}};
    pub const esc: @This() = .{ ._esc = {}};
    pub const caps_lock: @This() = .{ ._caps_lock = {}};
    pub const scroll_lock: @This() = .{ ._scroll_lock = {}};
    pub const num_lock: @This() = .{ ._num_lock = {}};
    pub const print_screen: @This() = .{ ._print_screen = {}};
    pub const pause: @This() = .{ ._pause = {}};
    pub const menu: @This() = .{ ._menu = {}};
    pub const keypad_begin: @This() = .{ ._keypad_begin = {}};

    _backspace,
    _enter,
    _left,
    _right,
    _up,
    _down,
    _home,
    _end,
    _page_up,
    _page_down,
    _tab,
    _back_tab,
    _delete,
    _insert,
    _null,
    _esc,
    _caps_lock,
    _scroll_lock,
    _num_lock,
    _print_screen,
    _pause,
    _menu,
    _keypad_begin,

    _f: u8,
    _char: u21,
    _media: Media,
    _modifier: Modifier,

    pub fn f(value: u8) @This() {
        return .{ ._f = value };
    }

    pub fn media(value: Media) @This() {
        return .{ ._media = value };
    }

    pub fn modifier(value: Modifier) @This() {
        return .{ ._modifier = value };
    }

    pub fn char(value: u21) @This() {
        return .{ ._char = value };
    }

    pub const Media = enum {
        play,
        pause,
        play_pause,
        reverse,
        stop,
        fast_forward,
        rewind,
        track_next,
        track_previous,
        record,
        lower_volume,
        raise_volume,
        mute_volume,
    };

    pub const Modifier = enum {
        left_shift,
        left_control,
        left_alt,
        left_super,
        left_hyper,
        left_meta,
        right_shift,
        right_control,
        right_alt,
        right_super,
        right_hyper,
        right_meta,
        iso_level_3_shift,
        iso_level_5_shift,
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
    left,
    middle,
    right,
    xbutton_1,
    xbutton_2,
    scroll_right,
    scroll_left,
    other
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
    pub const scroll_down: @This() = .{ .scroll = .down };
    pub const scroll_up: @This() = .{ .scroll = .up };
    pub const scroll_left: @This() = .{ .scroll = .left };
    pub const scroll_right: @This() = .{ .scroll = .right };

    move: void,

    down: MouseButton,
    up: MouseButton,
    drag: MouseButton,

    scroll: ScrollDirection,
};

pub const MouseEvent = struct {
    col: u16,
    row: u16,
    kind: MouseEventKind,
    modifiers: Modifiers = .{},

    pub fn matches(self: *const @This(), match: MouseMatch) bool {
        if (match.alt and !self.modifiers.alt) return false;
        if (match.ctrl and !self.modifiers.ctrl ) return false;
        if (match.shift and !self.modifiers.shift) return false;
        if (match.super and !self.modifiers.super) return false;
        if (match.meta and !self.modifiers.meta ) return false;
        if (match.hyper and !self.modifiers.hyper) return false;

        if (match.button) |a| {
            switch (self.kind) {
                .down => |b| if (!std.meta.eql(a, b)) return false,
                .up => |b| if (!std.meta.eql(a, b)) return false,
                .drag => |b| if (!std.meta.eql(a, b)) return false,
                else => return false,
            }
        }

        if (match.move) {
            switch (self.kind) {
                .drag, .move => {},
                else => return false,
            }
        }

        if (match.scroll) |a| {
            switch (self.kind) {
                .scroll => |b| if (!std.meta.eql(a, b)) return false,
                else => return false,
            }
        }

        return true;
    }

    pub const MouseMatch = struct {
        move: bool = false,
        button: ?MouseButton = null,
        scroll: ?ScrollDirection = null,

        alt: bool = false,
        ctrl: bool = false,
        shift: bool = false,
        super: bool = false,
        meta: bool = false,
        hyper: bool = false,
    };
};

pub const Event = union(enum) {
    key: KeyEvent,
    mouse: MouseEvent,
    resize: std.meta.Tuple(&.{ u16, u16 }),
    /// Requires `Capture.EnableFocus` to be executed
    focus: bool,
    /// Requires `Capture.EnableBracketedPaste` to be executed
    paste: []const u8,
    cursor: std.meta.Tuple(&.{ u16, u16 })
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
