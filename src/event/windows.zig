const std = @import("std");
const event = @import("../event.zig");

const Event = event.Event;
const KeyEvent = event.KeyEvent;
const MouseEventKind = event.MouseEventKind;
const Modifiers = event.Modifiers;
const Key = event.Key;

const BOOL = std.os.windows.BOOL;

pub const INPUT_RECORD = extern struct {
    EventType: u16,
    Event: extern union {
        KeyEvent: KEY_EVENT_RECORD,
        MouseEvent: MOUSE_EVENT_RECORD,
        WindowBufferSizeEvent: WINDOW_BUFFER_SIZE_RECORD,
        MenuEvent: MENU_EVENT_RECORD,
        FocusEvent: FOCUS_EVENT_RECORD,
    },
};

const COORD = extern struct {
    x: i16 = 0,
    y: i16 = 0,
};

const EventType = enum(u16) {
    key = 0x0001,
    mouse = 0x0002,
    window_buffer_size = 0x0004,
    menu = 0x0008,
    focus = 0x0010,
};

const KEY_EVENT_RECORD = extern struct {
    bKeyDown: BOOL,
    wRepeatCount: u16,
    wVirtualKeyCode: u16,
    wVirtualScanCode: u16,
    uChar: extern union {
        UnicodeChar: u16,
        AsciiChar: u8,
        pub fn eql(self: *const @This(), val: u16) bool {
            return self.UnicodeChar == val;
        }
        pub fn inRange(self: *const @This(), start: u16, end: u16) bool {
            return self.UnicodeChar >= start and self.UnicodeChar <= end;
        }
        pub fn value(self: *const @This()) !u21 {
            var iter = std.unicode.Utf16LeIterator.init(&[_]u16{ self.UnicodeChar });
            return (try iter.nextCodepoint()).?;
        }
    },
    dwControlKeyState: u32,

    pub fn pressed(self: *const @This()) bool {
        return self.bKeyDown == 1;
    }
};

const ControlKeyState = packed struct (u32) {
    right_alt: bool = false,
    left_alt: bool = false,
    right_ctrl: bool = false,
    left_ctrl: bool = false,
    shift: bool = false,
    num_lock: bool = true,
    scroll_lock: bool = true,
    caps_lock: bool = true,
    _m: u24 = 0,

    pub fn from(value: u32) @This() {
        return @bitCast(value);
    }

    pub fn modifiers(self: *const @This()) Modifiers {
        return .{
            .alt = self.left_alt or self.right_alt,
            .ctrl = self.left_ctrl or self.right_ctrl,
            .shift = self.shift
        };
    }
};

pub const MOUSE_EVENT_RECORD = extern struct {
    dwMousePosition: COORD,
    dwButtonState: ButtonState,
    dwControlKeyState: u32,
    dwEventFlags: u32,
};

const MouseFlags = enum(u32) {
    click = 0x0000,
    move = 0x0001,
    double = 0x0002,
    wheel = 0x0004,
    hwheel = 0x0008,
    unknown = 0x0033,

    pub fn from(value: u32) @This() {
        if (value == 0x0000) {
            return .click;
        } else if (value == 0x0001) {
            return .move;
        } else if (value == 0x0002) {
            return .double;
        } else if (value == 0x0004) {
            return .wheel;
        } else if (value == 0x0008) {
            return .hwheel;
        } else {
            return .unknown;
        }
    }
};

const ButtonState = packed struct(i32) {
    state: i32,

    const Left = 0x0001;
    const Right = 0x0002;
    const Middle = 0x0004;
    const X1 = 0x0008;
    const X2 = 0x0010;

    pub fn left(self: *const @This()) bool {
        return self.state & Left != 0;
    }

    pub fn right(self: *const @This()) bool {
        return self.state & Right != 0;
    }

    pub fn middle(self: *const @This()) bool {
        return self.state & Middle != 0;
    }

    pub fn x1(self: *const @This()) bool {
        return self.state & X1 != 0;
    }

    pub fn x2(self: *const @This()) bool {
        return self.state & X2 != 0;
    }

    pub fn released(self: *const @This()) bool {
        return self.state == 0;
    }

    pub fn scroll_up(self: *const @This()) bool {
        return self.state > 0;
    }

    pub fn scroll_down(self: *const @This()) bool {
        return self.state < 0;
    }
};

pub const WINDOW_BUFFER_SIZE_RECORD = extern struct {
    dwSize: COORD,
};

pub const MENU_EVENT_RECORD = extern struct {
    dwCommandId: u32,
};

pub const FOCUS_EVENT_RECORD = extern struct {
    bSetFocus: BOOL,
};

pub extern "user32" fn ToUnicodeEx(
    wVirtKey: u32,
    wScanCode: u32,
    lpKeyState: *[256]u8,
    pwszBuff: [*:0]u16,
    cchBuff: i32,
    wFlags: u32,
    dwhkl: ?HKL,
) callconv(@import("std").os.windows.WINAPI) i32;

extern "user32" fn GetForegroundWindow(
) callconv(.Win64) ?std.os.windows.HANDLE;

extern "user32" fn GetWindowThreadProcessId(
    hwnd: ?std.os.windows.HANDLE,
    processId: ?*u32,
) callconv(.Win64) ?std.os.windows.HANDLE;

const HKL = *opaque{};
extern "user32" fn GetKeyboardLayout(
    idThread: u32,
) callconv(.Win64) ?HKL;

extern "kernel32" fn GetNumberOfConsoleInputEvents(
    hConsoleInput: std.os.windows.HANDLE,
    lpcNumberOfEvents: *u16,
) callconv(.Win64) std.os.windows.BOOL;

pub extern "kernel32" fn ReadConsoleInputW(
    hConsoleInput: ?std.os.windows.HANDLE,
    lpBuffer: [*]INPUT_RECORD,
    nLength: u32,
    lpNumberOfEventsRead: ?*u32,
) callconv(@import("std").os.windows.WINAPI) std.os.windows.BOOL;

pub fn getNumberOfConsoleInputEvents() !u16 {
    var count: u16 = 0;
    if (GetNumberOfConsoleInputEvents(
        try std.os.windows.GetStdHandle(std.os.windows.STD_INPUT_HANDLE),
        &count
    ) == 0) {
        return error.Win32Error;
    }

    return count;
}

pub fn getSingleInputEvent() !?INPUT_RECORD {
    var buffer: [1]INPUT_RECORD = undefined;
    var read: u32 = 0;
    if (ReadConsoleInputW(
        try std.os.windows.GetStdHandle(std.os.windows.STD_INPUT_HANDLE),
        &buffer,
        1,
        &read,
    ) == 0) {
        return error.Win32Error;
    }

    if (read == 0) return null;
    return buffer[0];
}

pub const EventStream = struct {
    alloc: std.mem.Allocator,

    surrogate: Surrogate = .{},
    mouse_buttons: MouseButtonStates = .{},

    pub const Surrogate = struct {
        value: ?u21 = null
    };

    pub const MouseButtonStates = struct {
        left: bool = false,
        middle: bool = false,
        right: bool = false,
        x1: bool = false,
        x2: bool = false,
    };

    pub fn init(alloc: std.mem.Allocator) @This() {
        return .{ .alloc = alloc };
    }

    pub fn deinit(self: *@This()) void {
        _ = self;
    }

    /// Check if the stdin buffer has data to read
    ///
    /// @return true if there is data in the buffer
    pub fn pollEvent(self: *const @This()) bool {
        _ = self;
        return (getNumberOfConsoleInputEvents() catch 0) > 0;
    }

    /// Parse the next console input event
    pub fn parseEvent(self: *@This()) !?Event {
        const inputCount = try getNumberOfConsoleInputEvents();
        if (inputCount != 0) {
            if (try getSingleInputEvent()) |record| {
                switch (@as(EventType, @enumFromInt(record.EventType))) {
                    .key => {
                        return try handleKeyEvent(record.Event.KeyEvent, &self.surrogate);
                    },
                    .mouse => {
                        defer self.mouse_buttons = .{
                            .left = record.Event.MouseEvent.dwButtonState.left(),
                            .right = record.Event.MouseEvent.dwButtonState.right(),
                            .middle = record.Event.MouseEvent.dwButtonState.middle(),
                        };

                        if (handleMouseEvent(record.Event.MouseEvent, &self.mouse_buttons)) |kind| {
                            return Event {
                                .mouse = .{
                                    .col = @intCast(record.Event.MouseEvent.dwMousePosition.x),
                                    .row = @intCast(record.Event.MouseEvent.dwMousePosition.y),
                                    .kind = kind,
                                }
                            };
                        }
                    },
                    .window_buffer_size => {
                        const size = record.Event.WindowBufferSizeEvent.dwSize;
                        return Event {
                            .resize = .{ @intCast(size.x), @intCast(size.y) }
                        };
                    },
                    .focus => {
                        return Event {
                            .focus = record.Event.FocusEvent.bSetFocus == 1
                        };
                    },
                    else => {
                        // Ignore Menu Record events
                    }
                }
            }
        }

        return null;
    }
};

const ParsedKeyEvent = union(enum) {
    surrogate: u21,
    event: KeyEvent,
};

fn handleMouseEvent(record: MOUSE_EVENT_RECORD, pressed_buttons: *EventStream.MouseButtonStates) ?MouseEventKind {
    // TODO: Resolve relative y instead of using absolute y
    const button = record.dwButtonState;
    switch (MouseFlags.from(record.dwEventFlags)) {
        .click, .double => {
            // TODO: Determine if a button has been released
            var kind: ?MouseEventKind = null;
            if (button.left() and !pressed_buttons.left) {
                kind = MouseEventKind.down(.Left);
            } else if (!button.left() and pressed_buttons.left) {
                kind = MouseEventKind.up(.Left);
            } else if (button.right() and !pressed_buttons.right) {
                kind = MouseEventKind.down(.Right);
            } else if (!button.right() and pressed_buttons.right) {
                kind = MouseEventKind.up(.Right);
            } else if (button.middle() and !pressed_buttons.middle) {
                kind = MouseEventKind.down(.Middle);
            } else if (!button.middle() and pressed_buttons.middle) {
                kind = MouseEventKind.up(.Middle);
            }

            return kind;
        },
        .move => {
            const b: event.MouseButton =
                if (button.right()) .Right
                else if (button.middle()) .Middle
                else .Left;

            if (button.released()) {
                return MouseEventKind.Move;
            } else {
                return MouseEventKind.drag(b);
            }
        },
        .wheel => {
            if (button.scroll_down()) {
                return MouseEventKind.ScrollDown;
            } else if (button.scroll_up()) {
                return MouseEventKind.ScrollUp;
            }
        },
        .hwheel => {
            if (button.scroll_down()) {
                return MouseEventKind.ScrollLeft;
            } else if (button.scroll_up()) {
                return MouseEventKind.ScrollRight;
            }
        },
        else => {}
    }

    return null;
}

fn handleKeyEvent(record: KEY_EVENT_RECORD, buffered_surrogate: *EventStream.Surrogate) !?Event {
    if (try parseKeyRecord(record)) |parsed_evt| {
        switch (parsed_evt) {
            .surrogate => |new_surrogate| {
                if (buffered_surrogate.value) |bsurrogate| {
                    var iter = std.unicode.Utf16LeIterator.init(&[2]u16 { @intCast(bsurrogate), @intCast(new_surrogate) });
                    const key = iter.nextCodepoint() catch null;
                    if (key) |k| {
                        return Event {
                            .key = .{
                                .kind = if (record.pressed()) .press else .release,
                                .key = Key.char(k),
                                .modifiers = ControlKeyState.from(record.dwControlKeyState).modifiers()
                            }
                        };
                    }
                } else {
                    buffered_surrogate.value = new_surrogate;
                }
            },
            .event => |evt| return Event { .key = evt }
        }
    }

    return null;
}

fn parseKeyRecord(record: KEY_EVENT_RECORD) !?ParsedKeyEvent {
    const vkc = record.wVirtualKeyCode;
    const modifiers: Modifiers = ControlKeyState.from(record.dwControlKeyState).modifiers();
    const is_alt_code = vkc == @intFromEnum(VK.MENU) and !record.pressed() and record.uChar.eql(0);

    if (is_alt_code) {
        if (record.uChar.inRange(0xD800, 0xDFFF)) {
            return .{ .surrogate = try record.uChar.value() };
        } else {
            return .{
                .event = .{
                    .key = Key.char(try record.uChar.value()),
                    .modifiers = ControlKeyState.from(record.dwControlKeyState).modifiers(),
                    .kind = if (record.pressed()) .press else .release,
                }
            };
        }
    }

    // Don't generate events for numpad key presses when they're producing Alt codes.
    const is_numpad_numeric_key = VK.range(VK.NUMPAD0, VK.NUMPAD9, vkc);
    const is_only_alt_modifier = modifiers.alt and !modifiers.shift and !modifiers.ctrl;
    if (is_only_alt_modifier and is_numpad_numeric_key) {
        return null;
    }

    var result: ?Key = null;
    switch(vkc) {
        @intFromEnum(VK.SHIFT), @intFromEnum(VK.CONTROL), @intFromEnum(VK.MENU) => {},
        @intFromEnum(VK.BACK) => result = Key.Backspace,
        @intFromEnum(VK.ESCAPE) => result = Key.Esc,
        @intFromEnum(VK.RETURN) => result = Key.Enter,
        @intFromEnum(VK.F1) => result = Key.f(1),
        @intFromEnum(VK.F2) => result = Key.f(2),
        @intFromEnum(VK.F3) => result = Key.f(3),
        @intFromEnum(VK.F4) => result = Key.f(4),
        @intFromEnum(VK.F5) => result = Key.f(5),
        @intFromEnum(VK.F6) => result = Key.f(6),
        @intFromEnum(VK.F7) => result = Key.f(7),
        @intFromEnum(VK.F8) => result = Key.f(8),
        @intFromEnum(VK.F9) => result = Key.f(9),
        @intFromEnum(VK.F10) => result = Key.f(10),
        @intFromEnum(VK.F11) => result = Key.f(11),
        @intFromEnum(VK.F12) => result = Key.f(12),
        @intFromEnum(VK.F13) => result = Key.f(13),
        @intFromEnum(VK.F14) => result = Key.f(14),
        @intFromEnum(VK.F15) => result = Key.f(15),
        @intFromEnum(VK.F16) => result = Key.f(16),
        @intFromEnum(VK.F17) => result = Key.f(17),
        @intFromEnum(VK.F18) => result = Key.f(18),
        @intFromEnum(VK.F19) => result = Key.f(19),
        @intFromEnum(VK.F20) => result = Key.f(20),
        @intFromEnum(VK.F21) => result = Key.f(21),
        @intFromEnum(VK.F22) => result = Key.f(22),
        @intFromEnum(VK.F23) => result = Key.f(23),
        @intFromEnum(VK.F24) => result = Key.f(24),
        @intFromEnum(VK.LEFT) => result = Key.Left,
        @intFromEnum(VK.UP) => result = Key.Up,
        @intFromEnum(VK.RIGHT) => result = Key.Right,
        @intFromEnum(VK.DOWN) => result = Key.Down,
        @intFromEnum(VK.PRIOR) => result = Key.PageUp,
        @intFromEnum(VK.NEXT) => result = Key.PageDown,
        @intFromEnum(VK.HOME) => result = Key.Home,
        @intFromEnum(VK.END) => result = Key.End,
        @intFromEnum(VK.DELETE) => result = Key.Delete,
        @intFromEnum(VK.INSERT) => result = Key.Insert,
        @intFromEnum(VK.TAB) => result = Key.Tab,
        else => {
            if (record.uChar.inRange(0x00, 0x1f)) {
                // Some key combinations generate either no u_char value or generate control
                // codes. To deliver back a KeyCode::Char(...) event we want to know which
                // character the key normally maps to on the user's keyboard layout.
                // The keys that intentionally generate control codes (ESC, ENTER, TAB, etc.)
                // are handled by their virtual key codes above.
                // REF: https://github.com/crossterm-rs/crossterm/blob/master/src/event/sys/windows/parse.rs#L143
                if (getCharForKey(record)) |ch| {
                    result = Key.char(ch);
                }
            } else if (record.uChar.inRange(0xD800, 0xDFFF)) {
                return .{ .surrogate = try record.uChar.value() };
            } else {
                result = Key.char(try record.uChar.value());
            }
        }
    }

    if (result) |key| {
        return .{ .event = .{
            .key = key,
            .modifiers = modifiers,
            .kind = if (record.pressed()) .press else .release,
        }};
    }

    return null;
}

fn getCharForKey(record: KEY_EVENT_RECORD) ?u21 {
    const vkc = record.wVirtualKeyCode;
    const vsc = record.wVirtualScanCode;
    const modifiers = ControlKeyState.from(record.dwControlKeyState);

    var key_state: [256]u8 = [_]u8{ 0 } ** 256;
    var utf16_buf: [256:0]u16 = [_:0]u16{ 0 } ** 256;

    const no_change_kernel_keyboard_state = 0x4;

    var active_keyboard_layout: ?HKL = null;
    {
        const foreground_window = GetForegroundWindow();
        const foreground_thread = GetWindowThreadProcessId(foreground_window, null);
        if (foreground_thread) |ft| {
            active_keyboard_layout = GetKeyboardLayout(@intCast(@intFromPtr(ft)));
        }
    }

    const count = ToUnicodeEx(
        @intCast(vkc),
        @intCast(vsc),
        &key_state,
        &utf16_buf,
        @intCast(utf16_buf.len),
        no_change_kernel_keyboard_state,
        active_keyboard_layout,
    );

    // 0 == No Key
    // -1 == Dead Key
    if (count < 1) return null;

    var iter = std.unicode.Utf16LeIterator.init(utf16_buf[0..@intCast(count)]);
    var char = iter.nextCodepoint() catch return null;

    // Key doesn't map to a single character
    if ((iter.nextCodepoint() catch null) != null) return null;

    if (char) |c| {
        if (c >= 64 and c <= 90 or c >= 92 and c <= 122) {
            if (modifiers.shift or modifiers.caps_lock) {
                char = @intCast(std.ascii.toUpper(@intCast(c)));
            } else {
                char = @intCast(std.ascii.toLower(@intCast(c)));
            }
        }
    }

    return char;
}

const VK = enum(u16) {
    @"0" = 48,
    @"1" = 49,
    @"2" = 50,
    @"3" = 51,
    @"4" = 52,
    @"5" = 53,
    @"6" = 54,
    @"7" = 55,
    @"8" = 56,
    @"9" = 57,
    A = 65,
    B = 66,
    C = 67,
    D = 68,
    E = 69,
    F = 70,
    G = 71,
    H = 72,
    I = 73,
    J = 74,
    K = 75,
    L = 76,
    M = 77,
    N = 78,
    O = 79,
    P = 80,
    Q = 81,
    R = 82,
    S = 83,
    T = 84,
    U = 85,
    V = 86,
    W = 87,
    X = 88,
    Y = 89,
    Z = 90,
    LBUTTON = 1,
    RBUTTON = 2,
    CANCEL = 3,
    MBUTTON = 4,
    XBUTTON1 = 5,
    XBUTTON2 = 6,
    BACK = 8,
    TAB = 9,
    CLEAR = 12,
    RETURN = 13,
    SHIFT = 16,
    CONTROL = 17,
    MENU = 18,
    PAUSE = 19,
    CAPITAL = 20,
    KANA = 21,
    // HANGEUL = 21, this enum value conflicts with KANA
    // HANGUL = 21, this enum value conflicts with KANA
    IME_ON = 22,
    JUNJA = 23,
    FINAL = 24,
    HANJA = 25,
    // KANJI = 25, this enum value conflicts with HANJA
    IME_OFF = 26,
    ESCAPE = 27,
    CONVERT = 28,
    NONCONVERT = 29,
    ACCEPT = 30,
    MODECHANGE = 31,
    SPACE = 32,
    PRIOR = 33,
    NEXT = 34,
    END = 35,
    HOME = 36,
    LEFT = 37,
    UP = 38,
    RIGHT = 39,
    DOWN = 40,
    SELECT = 41,
    PRINT = 42,
    EXECUTE = 43,
    SNAPSHOT = 44,
    INSERT = 45,
    DELETE = 46,
    HELP = 47,
    LWIN = 91,
    RWIN = 92,
    APPS = 93,
    SLEEP = 95,
    NUMPAD0 = 96,
    NUMPAD1 = 97,
    NUMPAD2 = 98,
    NUMPAD3 = 99,
    NUMPAD4 = 100,
    NUMPAD5 = 101,
    NUMPAD6 = 102,
    NUMPAD7 = 103,
    NUMPAD8 = 104,
    NUMPAD9 = 105,
    MULTIPLY = 106,
    ADD = 107,
    SEPARATOR = 108,
    SUBTRACT = 109,
    DECIMAL = 110,
    DIVIDE = 111,
    F1 = 112,
    F2 = 113,
    F3 = 114,
    F4 = 115,
    F5 = 116,
    F6 = 117,
    F7 = 118,
    F8 = 119,
    F9 = 120,
    F10 = 121,
    F11 = 122,
    F12 = 123,
    F13 = 124,
    F14 = 125,
    F15 = 126,
    F16 = 127,
    F17 = 128,
    F18 = 129,
    F19 = 130,
    F20 = 131,
    F21 = 132,
    F22 = 133,
    F23 = 134,
    F24 = 135,
    NAVIGATION_VIEW = 136,
    NAVIGATION_MENU = 137,
    NAVIGATION_UP = 138,
    NAVIGATION_DOWN = 139,
    NAVIGATION_LEFT = 140,
    NAVIGATION_RIGHT = 141,
    NAVIGATION_ACCEPT = 142,
    NAVIGATION_CANCEL = 143,
    NUMLOCK = 144,
    SCROLL = 145,
    OEM_NEC_EQUAL = 146,
    // OEM_FJ_JISHO = 146, this enum value conflicts with OEM_NEC_EQUAL
    OEM_FJ_MASSHOU = 147,
    OEM_FJ_TOUROKU = 148,
    OEM_FJ_LOYA = 149,
    OEM_FJ_ROYA = 150,
    LSHIFT = 160,
    RSHIFT = 161,
    LCONTROL = 162,
    RCONTROL = 163,
    LMENU = 164,
    RMENU = 165,
    BROWSER_BACK = 166,
    BROWSER_FORWARD = 167,
    BROWSER_REFRESH = 168,
    BROWSER_STOP = 169,
    BROWSER_SEARCH = 170,
    BROWSER_FAVORITES = 171,
    BROWSER_HOME = 172,
    VOLUME_MUTE = 173,
    VOLUME_DOWN = 174,
    VOLUME_UP = 175,
    MEDIA_NEXT_TRACK = 176,
    MEDIA_PREV_TRACK = 177,
    MEDIA_STOP = 178,
    MEDIA_PLAY_PAUSE = 179,
    LAUNCH_MAIL = 180,
    LAUNCH_MEDIA_SELECT = 181,
    LAUNCH_APP1 = 182,
    LAUNCH_APP2 = 183,
    OEM_1 = 186,
    OEM_PLUS = 187,
    OEM_COMMA = 188,
    OEM_MINUS = 189,
    OEM_PERIOD = 190,
    OEM_2 = 191,
    OEM_3 = 192,
    GAMEPAD_A = 195,
    GAMEPAD_B = 196,
    GAMEPAD_X = 197,
    GAMEPAD_Y = 198,
    GAMEPAD_RIGHT_SHOULDER = 199,
    GAMEPAD_LEFT_SHOULDER = 200,
    GAMEPAD_LEFT_TRIGGER = 201,
    GAMEPAD_RIGHT_TRIGGER = 202,
    GAMEPAD_DPAD_UP = 203,
    GAMEPAD_DPAD_DOWN = 204,
    GAMEPAD_DPAD_LEFT = 205,
    GAMEPAD_DPAD_RIGHT = 206,
    GAMEPAD_MENU = 207,
    GAMEPAD_VIEW = 208,
    GAMEPAD_LEFT_THUMBSTICK_BUTTON = 209,
    GAMEPAD_RIGHT_THUMBSTICK_BUTTON = 210,
    GAMEPAD_LEFT_THUMBSTICK_UP = 211,
    GAMEPAD_LEFT_THUMBSTICK_DOWN = 212,
    GAMEPAD_LEFT_THUMBSTICK_RIGHT = 213,
    GAMEPAD_LEFT_THUMBSTICK_LEFT = 214,
    GAMEPAD_RIGHT_THUMBSTICK_UP = 215,
    GAMEPAD_RIGHT_THUMBSTICK_DOWN = 216,
    GAMEPAD_RIGHT_THUMBSTICK_RIGHT = 217,
    GAMEPAD_RIGHT_THUMBSTICK_LEFT = 218,
    OEM_4 = 219,
    OEM_5 = 220,
    OEM_6 = 221,
    OEM_7 = 222,
    OEM_8 = 223,
    OEM_AX = 225,
    OEM_102 = 226,
    ICO_HELP = 227,
    ICO_00 = 228,
    PROCESSKEY = 229,
    ICO_CLEAR = 230,
    PACKET = 231,
    OEM_RESET = 233,
    OEM_JUMP = 234,
    OEM_PA1 = 235,
    OEM_PA2 = 236,
    OEM_PA3 = 237,
    OEM_WSCTRL = 238,
    OEM_CUSEL = 239,
    OEM_ATTN = 240,
    OEM_FINISH = 241,
    OEM_COPY = 242,
    OEM_AUTO = 243,
    OEM_ENLW = 244,
    OEM_BACKTAB = 245,
    ATTN = 246,
    CRSEL = 247,
    EXSEL = 248,
    EREOF = 249,
    PLAY = 250,
    ZOOM = 251,
    NONAME = 252,
    PA1 = 253,
    OEM_CLEAR = 254,
    Other = 255,

    pub fn from(value: u16) @This() {
        if (value < 255) return @enumFromInt(value);
        return @This().Other;
    }

    pub fn range(start: VK, end: VK, value: u16) bool {
        return @intFromEnum(start) <= value and @intFromEnum(end) >= value;
    }
};

// fn try_read(&mut self, timeout: Option<Duration>) -> std::io::Result<Option<InternalEvent>> {
//        let poll_timeout = PollTimeout::new(timeout);
//
//        loop {
//            if let Some(event_ready) = self.poll.poll(poll_timeout.leftover())? {
//                let number = self.console.number_of_console_input_events()?;
//                if event_ready && number != 0 {
//                    let event = match self.console.read_single_input_event()? {
//                        InputRecord::KeyEvent(record) => {
//                            handle_key_event(record, &mut self.surrogate_buffer)
//                        }
//                        InputRecord::MouseEvent(record) => {
//                            let mouse_event =
//                                handle_mouse_event(record, &self.mouse_buttons_pressed);
//                            self.mouse_buttons_pressed = MouseButtonsPressed {
//                                left: record.button_state.left_button(),
//                                right: record.button_state.right_button(),
//                                middle: record.button_state.middle_button(),
//                            };
//
//                            mouse_event
//                        }
//                        InputRecord::WindowBufferSizeEvent(record) => {
//                            // windows starts counting at 0, unix at 1, add one to replicate unix behaviour.
//                            Some(Event::Resize(
//                                (record.size.x as i32 + 1) as u16,
//                                (record.size.y as i32 + 1) as u16,
//                            ))
//                        }
//                        InputRecord::FocusEvent(record) => {
//                            let event = if record.set_focus {
//                                Event::FocusGained
//                            } else {
//                                Event::FocusLost
//                            };
//                            Some(event)
//                        }
//                        _ => None,
//                    };
//
//                    if let Some(event) = event {
//                        return Ok(Some(InternalEvent::Event(event)));
//                    }
//                }
//            }
//
//            if poll_timeout.elapsed() {
//                return Ok(None);
//            }
//        }
//    }
