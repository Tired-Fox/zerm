const std = @import("std");
const builtin = @import("builtin");

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

    function: u8,
    character: u21,
    multimedia: Media,
    modifier: Modifier,

    /// F key
    pub fn f(value: u8) @This() {
        return .{ .function = value };
    }

    /// Media key
    pub fn media(value: Media) @This() {
        return .{ .multimedia = value };
    }

    /// Modifier key
    pub fn mod(value: Modifier) @This() {
        return .{ .modifier = value };
    }

    /// Character (text) key
    pub fn char(value: u21) @This() {
        return .{ .character = value };
    }

    /// Media keys
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

    /// Modifier key
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

    pub const empty: @This() = .{};
    pub const Alt: u6 = 1;
    pub const Ctrl: u6 = 2;
    pub const Shift: u6 = 4;
    pub const Super: u6 = 8;
    pub const Meta: u6 = 16;
    pub const Hyper: u6 = 32;

    pub inline fn from(value: u6) @This() {
        return @bitCast(value);
    }

    pub inline fn bits(self: *const @This()) u6 {
        return @bitCast(self.*);
    }
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

pub const KeyEvent = struct {
    code: KeyCode,
    modifiers: Modifiers = .empty,
    kind: Kind = .press,
    state: State = .empty,

    pub fn match(self: *const @This(), pattern: Match) bool {
        if (!std.meta.eql(pattern.kind, self.kind)) return false;

        if (pattern.code) |code| {
            if (!std.meta.eql(code, self.code)) return false;
        }

        if (pattern.alt and !self.modifiers.alt) return false;
        if (pattern.ctrl and !self.modifiers.ctrl) return false;
        if (pattern.shift and !self.modifiers.shift) return false;
        if (pattern.super and !self.modifiers.super) return false;
        if (pattern.meta and !self.modifiers.meta) return false;
        if (pattern.hyper and !self.modifiers.hyper) return false;

        if (pattern.caps_lock and !self.state.caps_lock) return false;
        if (pattern.keypad and !self.state.keypad) return false;
        if (pattern.num_lock and !self.state.num_lock) return false;

        return true;
    }

    pub fn matches(self: *const @This(), patterns: []const Match) bool {
        for (patterns) |pattern| {
            if (self.match(pattern)) return true;
        }
        return false;
    }

    pub const Match = struct {
        code: ?KeyCode = null,
        kind: Kind = .press,

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
        keypad: bool = false,
        caps_lock: bool = false,
        num_lock: bool = false,

        pub const empty: @This() = .{};

        pub const Keypad: u3 = 1;
        pub const CapsLock: u3 = 2;
        pub const NumLock: u3 = 4;

        pub inline fn from(value: u3) @This() {
            return @bitCast(value);
        }

        pub inline fn bits(self: *const @This()) u3 {
            return @bitCast(self.*);
        }
    };
};

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

// TODO: Implement settings and getting these flags on unix systems
// pub const EnhancementFlags = packed struct(u8) {
//     disambiguate_escape_codes: bool = false,
//     report_event_types: bool = false,
//     report_alternate_keys: bool = false,
//     report_all_keys_as_escape_codes: bool = false,
//     // Not yet supported
//     // report_associated_text: bool = false,
//     _m: u4 = 0,
// };

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

/// Instance that can be used to stream and poll
/// for terminal and input events
pub const EventStream = 
    if (builtin.os.tag == .windows) @import("./event/windows.zig").EventStream
    else @import("./event/tty.zig").EventStream;
