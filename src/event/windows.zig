const std = @import("std");
const event = @import("../event.zig");

const Event = event.Event;
const KeyEvent = event.KeyEvent;
const MouseEventKind = event.MouseEventKind;
const Modifiers = event.Modifiers;
const KeyCode = event.KeyCode;

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

    pub fn init(_: std.mem.Allocator) @This() {
        return .{};
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
                kind = MouseEventKind { .down = .left };
            } else if (!button.left() and pressed_buttons.left) {
                kind = MouseEventKind { .up = .left };
            } else if (button.right() and !pressed_buttons.right) {
                kind = MouseEventKind { .down = .right };
            } else if (!button.right() and pressed_buttons.right) {
                kind = MouseEventKind { .up = .right };
            } else if (button.middle() and !pressed_buttons.middle) {
                kind = MouseEventKind{ .down = .middle };
            } else if (!button.middle() and pressed_buttons.middle) {
                kind = MouseEventKind { .up = .middle };
            }

            return kind;
        },
        .move => {
            const b: event.MouseButton =
                if (button.right()) .right
                else if (button.middle()) .middle
                else .left;

            if (button.released()) {
                return MouseEventKind { .move = {} };
            } else {
                return MouseEventKind { .drag = b };
            }
        },
        .wheel => {
            if (button.scroll_down()) {
                return MouseEventKind.scroll_down;
            } else if (button.scroll_up()) {
                return MouseEventKind.scroll_up;
            }
        },
        .hwheel => {
            if (button.scroll_down()) {
                return MouseEventKind.scroll_left;
            } else if (button.scroll_up()) {
                return MouseEventKind.scroll_right;
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
                                .code = .char(k),
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
    const is_alt_code = vkc == @intFromEnum(VK.menu) and !record.pressed() and record.uChar.eql(0);

    if (is_alt_code) {
        if (record.uChar.inRange(0xD800, 0xDFFF)) {
            return .{ .surrogate = try record.uChar.value() };
        } else {
            return .{
                .event = .{
                    .code = .char(try record.uChar.value()),
                    .modifiers = ControlKeyState.from(record.dwControlKeyState).modifiers(),
                    .kind = if (record.pressed()) .press else .release,
                }
            };
        }
    }

    // Don't generate events for numpad key presses when they're producing Alt codes.
    const is_numpad_numeric_key = VK.range(.numpad0, .numpad9, vkc);
    const is_only_alt_modifier = modifiers.alt and !modifiers.shift and !modifiers.ctrl;
    if (is_only_alt_modifier and is_numpad_numeric_key) {
        return null;
    }

    var result: ?KeyCode = null;
    switch(vkc) {
        @intFromEnum(VK.shift), @intFromEnum(VK.control), @intFromEnum(VK.menu) => {},
        @intFromEnum(VK.back) => result = .backspace,
        @intFromEnum(VK.escape) => result = .esc,
        @intFromEnum(VK.@"return") => result = .enter,
        @intFromEnum(VK.f1) => result = .f(1),
        @intFromEnum(VK.f2) => result = .f(2),
        @intFromEnum(VK.f3) => result = .f(3),
        @intFromEnum(VK.f4) => result = .f(4),
        @intFromEnum(VK.f5) => result = .f(5),
        @intFromEnum(VK.f6) => result = .f(6),
        @intFromEnum(VK.f7) => result = .f(7),
        @intFromEnum(VK.f8) => result = .f(8),
        @intFromEnum(VK.f9) => result = .f(9),
        @intFromEnum(VK.f10) => result = .f(10),
        @intFromEnum(VK.f11) => result = .f(11),
        @intFromEnum(VK.f12) => result = .f(12),
        @intFromEnum(VK.f13) => result = .f(13),
        @intFromEnum(VK.f14) => result = .f(14),
        @intFromEnum(VK.f15) => result = .f(15),
        @intFromEnum(VK.@"f16") => result = .f(16),
        @intFromEnum(VK.f17) => result = .f(17),
        @intFromEnum(VK.f18) => result = .f(18),
        @intFromEnum(VK.f19) => result = .f(19),
        @intFromEnum(VK.f20) => result = .f(20),
        @intFromEnum(VK.f21) => result = .f(21),
        @intFromEnum(VK.f22) => result = .f(22),
        @intFromEnum(VK.f23) => result = .f(23),
        @intFromEnum(VK.f24) => result = .f(24),
        @intFromEnum(VK.left) => result = .left,
        @intFromEnum(VK.up) => result = .up,
        @intFromEnum(VK.right) => result = .right,
        @intFromEnum(VK.down) => result = .down,
        @intFromEnum(VK.prior) => result = .page_up,
        @intFromEnum(VK.next) => result = .page_down,
        @intFromEnum(VK.home) => result = .home,
        @intFromEnum(VK.end) => result = .end,
        @intFromEnum(VK.delete) => result = .delete,
        @intFromEnum(VK.insert) => result = .insert,
        @intFromEnum(VK.tab) => result = .tab,
        else => {
            if (record.uChar.inRange(0x00, 0x1f)) {
                // Some key combinations generate either no u_char value or generate control
                // codes. To deliver back a KeyCode::Char(...) event we want to know which
                // character the key normally maps to on the user's keyboard layout.
                // The keys that intentionally generate control codes (ESC, ENTER, TAB, etc.)
                // are handled by their virtual key codes above.
                // REF: https://github.com/crossterm-rs/crossterm/blob/master/src/event/sys/windows/parse.rs#L143
                if (getCharForKey(record)) |ch| {
                    result = .char(ch);
                }
            } else if (record.uChar.inRange(0xD800, 0xDFFF)) {
                return .{ .surrogate = try record.uChar.value() };
            } else {
                result = .char(try record.uChar.value());
            }
        }
    }

    if (result) |key| {
        return .{ .event = .{
            .code = key,
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
    a = 65,
    b = 66,
    c = 67,
    d = 68,
    e = 69,
    f = 70,
    g = 71,
    h = 72,
    i = 73,
    j = 74,
    k = 75,
    l = 76,
    m = 77,
    n = 78,
    o = 79,
    p = 80,
    q = 81,
    r = 82,
    s = 83,
    t = 84,
    u = 85,
    v = 86,
    w = 87,
    x = 88,
    y = 89,
    z = 90,
    lbutton = 1,
    rbutton = 2,
    cancel = 3,
    mbutton = 4,
    xbutton1 = 5,
    xbutton2 = 6,
    back = 8,
    tab = 9,
    clear = 12,
    @"return" = 13,
    shift = 16,
    control = 17,
    menu = 18,
    pause = 19,
    capital = 20,
    kana = 21,
    // hangeul = 21, this enum value conflicts with kana
    // hangul = 21, this enum value conflicts with kana
    ime_on = 22,
    junja = 23,
    final = 24,
    hanja = 25,
    // kanji = 25, this enum value conflicts with hanja
    ime_off = 26,
    escape = 27,
    convert = 28,
    nonconvert = 29,
    accept = 30,
    modechange = 31,
    space = 32,
    prior = 33,
    next = 34,
    end = 35,
    home = 36,
    left = 37,
    up = 38,
    right = 39,
    down = 40,
    select = 41,
    print = 42,
    execute = 43,
    snapshot = 44,
    insert = 45,
    delete = 46,
    help = 47,
    lwin = 91,
    rwin = 92,
    apps = 93,
    sleep = 95,
    numpad0 = 96,
    numpad1 = 97,
    numpad2 = 98,
    numpad3 = 99,
    numpad4 = 100,
    numpad5 = 101,
    numpad6 = 102,
    numpad7 = 103,
    numpad8 = 104,
    numpad9 = 105,
    multiply = 106,
    add = 107,
    separator = 108,
    subtract = 109,
    decimal = 110,
    divide = 111,
    f1 = 112,
    f2 = 113,
    f3 = 114,
    f4 = 115,
    f5 = 116,
    f6 = 117,
    f7 = 118,
    f8 = 119,
    f9 = 120,
    f10 = 121,
    f11 = 122,
    f12 = 123,
    f13 = 124,
    f14 = 125,
    f15 = 126,
    @"f16" = 127,
    f17 = 128,
    f18 = 129,
    f19 = 130,
    f20 = 131,
    f21 = 132,
    f22 = 133,
    f23 = 134,
    f24 = 135,
    navigation_view = 136,
    navigation_menu = 137,
    navigation_up = 138,
    navigation_down = 139,
    navigation_left = 140,
    navigation_right = 141,
    navigation_accept = 142,
    navigation_cancel = 143,
    numlock = 144,
    scroll = 145,
    oem_nec_equal = 146,
    // oem_fj_jisho = 146, this enum value conflicts with oem_nec_equal
    oem_fj_masshou = 147,
    oem_fj_touroku = 148,
    oem_fj_loya = 149,
    oem_fj_roya = 150,
    lshift = 160,
    rshift = 161,
    lcontrol = 162,
    rcontrol = 163,
    lmenu = 164,
    rmenu = 165,
    browser_back = 166,
    browser_forward = 167,
    browser_refresh = 168,
    browser_stop = 169,
    browser_search = 170,
    browser_favorites = 171,
    browser_home = 172,
    volume_mute = 173,
    volume_down = 174,
    volume_up = 175,
    media_next_track = 176,
    media_prev_track = 177,
    media_stop = 178,
    media_play_pause = 179,
    launch_mail = 180,
    launch_media_select = 181,
    launch_app1 = 182,
    launch_app2 = 183,
    oem_1 = 186,
    oem_plus = 187,
    oem_comma = 188,
    oem_minus = 189,
    oem_period = 190,
    oem_2 = 191,
    oem_3 = 192,
    gamepad_a = 195,
    gamepad_b = 196,
    gamepad_x = 197,
    gamepad_y = 198,
    gamepad_right_shoulder = 199,
    gamepad_left_shoulder = 200,
    gamepad_left_trigger = 201,
    gamepad_right_trigger = 202,
    gamepad_dpad_up = 203,
    gamepad_dpad_down = 204,
    gamepad_dpad_left = 205,
    gamepad_dpad_right = 206,
    gamepad_menu = 207,
    gamepad_view = 208,
    gamepad_left_thumbstick_button = 209,
    gamepad_right_thumbstick_button = 210,
    gamepad_left_thumbstick_up = 211,
    gamepad_left_thumbstick_down = 212,
    gamepad_left_thumbstick_right = 213,
    gamepad_left_thumbstick_left = 214,
    gamepad_right_thumbstick_up = 215,
    gamepad_right_thumbstick_down = 216,
    gamepad_right_thumbstick_right = 217,
    gamepad_right_thumbstick_left = 218,
    oem_4 = 219,
    oem_5 = 220,
    oem_6 = 221,
    oem_7 = 222,
    oem_8 = 223,
    oem_ax = 225,
    oem_102 = 226,
    ico_help = 227,
    ico_00 = 228,
    processkey = 229,
    ico_clear = 230,
    packet = 231,
    oem_reset = 233,
    oem_jump = 234,
    oem_pa1 = 235,
    oem_pa2 = 236,
    oem_pa3 = 237,
    oem_wsctrl = 238,
    oem_cusel = 239,
    oem_attn = 240,
    oem_finish = 241,
    oem_copy = 242,
    oem_auto = 243,
    oem_enlw = 244,
    oem_backtab = 245,
    attn = 246,
    crsel = 247,
    exsel = 248,
    ereof = 249,
    play = 250,
    zoom = 251,
    noname = 252,
    pa1 = 253,
    oem_clear = 254,
    other = 255,

    pub fn from(value: u16) @This() {
        if (value < 255) return @enumFromInt(value);
        return @This().Other;
    }

    pub fn range(start: VK, end: VK, value: u16) bool {
        return @intFromEnum(start) <= value and @intFromEnum(end) >= value;
    }
};
