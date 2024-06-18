const std = @import("std");
const builtin = @import("builtin");

const os = @import("os.zig").os;
const Point = @import("root.zig").Point;
const Size = @import("root.zig").Size;

pub const Modifiers = packed struct(u6) {
    alt: bool = false,
    ctrl: bool = false,
    shift: bool = false,
    numlock: bool = false,
    scrolllock: bool = false,
    capslock: bool = false,

    const Self = @This();
    pub fn merge(a: Self, b: Self) Self {
        return .{
            .alt = a.alt or b.alt,
            .ctrl = a.ctrl or b.ctrl,
            .shift = a.shift or b.shift,
            .numlock = a.numlock or b.numlock,
            .scrolllock = a.scrolllock or b.scrolllock,
            .capslock = a.capslock or b.capslock,
        };
    }

    usingnamespace switch (builtin.target.os.tag) {
        .windows => struct {
            pub fn from(value: u32) Self {
                return .{
                    .alt = (value & 0x0001) == 0x0001 or (value & 0x0002) == 0x0002,
                    .ctrl = (value & 0x0004) == 0x0004 or (value & 0x0008) == 0x0008,
                    .shift = (value & 0x0010) == 0x0010,
                    .numlock = (value & 0x0020) == 0x0020,
                    .scrolllock = (value & 0x0040) == 0x0040,
                    .capslock = (value & 0x0080) == 0x0080,
                };
            }
        },
        // TODO: Linux
        else => @compileError("Unsupported OS"),
    };
};

pub const Key = union(enum) {
    up: void,
    down: void,
    right: void,
    left: void,
    backspace: void,
    esc: void,
    end: void,
    home: void,
    insert: void,
    delete: void,
    tab: void,
    alt: void,
    enter: void,
    pageup: void,
    pagedown: void,
    f0: void,
    f1: void,
    f2: void,
    f3: void,
    f4: void,
    f5: void,
    f6: void,
    f7: void,
    f8: void,
    f9: void,
    f10: void,
    f11: void,
    f12: void,
    f13: void,
    f14: void,
    f15: void,
    f16: void,
    f17: void,
    f18: void,
    f19: void,
    f20: void,
    f21: void,
    f22: void,
    f23: void,
    f24: void,
    char: u8,

    pub fn char(c: u8) @This() {
        return .{ .char = c };
    }

    pub fn eql(a: @This(), b: @This()) bool {
        switch (a) {
            .char => |ca| {
                switch (b) {
                    .char => |cb| {
                        return ca == cb;
                    },
                    else => return false,
                }
            },
            else => return false,
        }
        return a == b;
    }
};

pub const KeyEvent = struct {
    modifiers: Modifiers = .{},
    key: Key,

    const Self = @This();
    pub fn from_u8(input: u8) Self {
        switch (input) {
            '\x7f' => return .{ .key = .backspace },
            '\x1b' => return .{ .key = .esc },
            '\n' => return .{ .key = .enter },
            '\r' => return .{ .key = .enter },
            '\t' => return .{ .key = .tab },
            ' ' => return .{ .key = .{ .char = ' ' } },
            '\x08' => return .{ .key = .backspace, .modifiers = .{ .ctrl = true } },
            '\x00' => return .{ .key = .{ .char = ' ' }, .modifiers = .{ .ctrl = true } },
            '\x01' => return .{ .key = .{ .char = 'a' }, .modifiers = .{ .ctrl = true } },
            '\x02' => return .{ .key = .{ .char = 'b' }, .modifiers = .{ .ctrl = true } },
            '\x03' => return .{ .key = .{ .char = 'c' }, .modifiers = .{ .ctrl = true } },
            '\x04' => return .{ .key = .{ .char = 'd' }, .modifiers = .{ .ctrl = true } },
            '\x05' => return .{ .key = .{ .char = 'e' }, .modifiers = .{ .ctrl = true } },
            '\x06' => return .{ .key = .{ .char = 'f' }, .modifiers = .{ .ctrl = true } },
            '\x07' => return .{ .key = .{ .char = 'g' }, .modifiers = .{ .ctrl = true } },
            '\x0b' => return .{ .key = .{ .char = 'k' }, .modifiers = .{ .ctrl = true } },
            '\x0c' => return .{ .key = .{ .char = 'l' }, .modifiers = .{ .ctrl = true } },
            '\x0e' => return .{ .key = .{ .char = 'n' }, .modifiers = .{ .ctrl = true } },
            '\x0f' => return .{ .key = .{ .char = 'o' }, .modifiers = .{ .ctrl = true } },
            '\x10' => return .{ .key = .{ .char = 'p' }, .modifiers = .{ .ctrl = true } },
            '\x11' => return .{ .key = .{ .char = 'q' }, .modifiers = .{ .ctrl = true } },
            '\x12' => return .{ .key = .{ .char = 'r' }, .modifiers = .{ .ctrl = true } },
            '\x13' => return .{ .key = .{ .char = 's' }, .modifiers = .{ .ctrl = true } },
            '\x14' => return .{ .key = .{ .char = 't' }, .modifiers = .{ .ctrl = true } },
            '\x15' => return .{ .key = .{ .char = 'u' }, .modifiers = .{ .ctrl = true } },
            '\x16' => return .{ .key = .{ .char = 'v' }, .modifiers = .{ .ctrl = true } },
            '\x17' => return .{ .key = .{ .char = 'w' }, .modifiers = .{ .ctrl = true } },
            '\x18' => return .{ .key = .{ .char = 'x' }, .modifiers = .{ .ctrl = true } },
            '\x19' => return .{ .key = .{ .char = 'y' }, .modifiers = .{ .ctrl = true } },
            '\x1a' => return .{ .key = .{ .char = 'z' }, .modifiers = .{ .ctrl = true } },
            else => return .{ .key = .{ .char = input } },
        }
    }

    usingnamespace switch (builtin.target.os.tag) {
        .windows => struct {
            pub fn from(value: os.KEY_EVENT_RECORD) Self {
                const char = Self.from_u8(value.uChar.AsciiChar);
                return .{
                    .modifiers = Modifiers.from(value.dwControlKeyState).merge(char.modifiers),
                    .key = char.key,
                };
            }
        },
        // TODO: Linux
        else => @compileError("Unsupported OS"),
    };
};

pub const MouseButtons = struct {
    left: bool = false,
    right: bool = false,
    middle: bool = false,
    xbutton1: bool = false,
    xbutton2: bool = false,

    const Self = @This();
    usingnamespace switch (builtin.target.os.tag) {
        .windows => struct {
            pub fn from(value: u32) Self {
                return .{
                    .left = (value & 0x0001) == 0x0001,
                    .right = (value & 0x0002) == 0x0002,
                    .middle = (value & 0x0004) == 0x0004,
                    .xbutton1 = (value & 0x0008) == 0x0008,
                    .xbutton2 = (value & 0x0010) == 0x0010,
                };
            }
        },
        // TODO: Linux
        else => @compileError("Unsupported OS"),
    };
};

pub const MouseEvent = enum {
    other,
    Move,
    VScroll,
    HScroll,
    DoubleClick,
    Click,

    const Self = @This();
    usingnamespace switch (builtin.target.os.tag) {
        .windows => struct {
            pub fn from(value: u32) Self {
                switch (value) {
                    0x0001 => return .Move,
                    0x0002 => return .DoubleClick,
                    0x0004 => return .VScroll,
                    0x0008 => return .HScroll,
                    0 => return .Click,
                    else => return .other,
                }
            }
        },
        // TODO: Linux
        else => @compileError("Unsupported OS"),
    };
};

pub const Mouse = struct {
    position: Point,
    buttons: MouseButtons,
    modifiers: Modifiers,
    event: MouseEvent,

    const Self = @This();
    usingnamespace switch (builtin.target.os.tag) {
        .windows => struct {
            pub fn from(value: os.MOUSE_EVENT_RECORD) Self {
                return .{
                    .position = .{ @intCast(@max(value.dwMousePosition.X, 0)), @intCast(@max(value.dwMousePosition.Y, 0)) },
                    .buttons = MouseButtons.from(value.dwButtonState),
                    .modifiers = Modifiers.from(value.dwControlKeyState),
                    .event = MouseEvent.from(value.dwEventFlags),
                };
            }
        },
        // TODO: Linux
        else => @compileError("Unsupported OS"),
    };
};

pub const Event = union(enum) {
    other: void,
    keyboard: KeyEvent,
    mouse: Mouse,
    focus: bool,
    resize: Size,

    pub fn from(value: os.INPUT_RECORD) @This() {
        switch (os.EventType.from(value.EventType)) {
            .FOCUS_EVENT => {
                const event = value.Event.FocusEvent;
                return .{
                    .focus = event.bSetFocus != 0,
                };
            },
            .KEY_EVENT => {
                const event = value.Event.KeyEvent;
                return .{ .keyboard = KeyEvent.from(event) };
            },
            .MOUSE_EVENT => {
                const event = value.Event.MouseEvent;
                return .{ .mouse = Mouse.from(event) };
            },
            .WINDOW_BUFFER_SIZE_EVENT => {
                const event = value.Event.WindowBufferSizeEvent;
                return .{ .resize = .{
                    @intCast(@max(event.dwSize.X, 0)),
                    @intCast(@max(event.dwSize.Y, 0)),
                } };
            },
            .MENU_EVENT => return .other,
        }
    }
};

fn parseEscapeSequenceModifier(input: []const u8) !Modifiers {
    return switch (try std.fmt.parseInt(u8, input, 10)) {
        2 => .{ .shift = true },
        3 => .{ .alt = true },
        4 => .{ .alt = true, .shift = true },
        5 => .{ .ctrl = true },
        6 => .{ .ctrl = true, .shift = true },
        7 => .{ .alt = true, .ctrl = true },
        8 => .{ .alt = true, .ctrl = true, .shift = true },
        else => .{},
    };
}

/// Parses modifier state from `\x1b[{key};{mod}<ST>`
fn shortEscapeModifier(escape: []const u8) !Modifiers {
    var parts = std.mem.split(u8, escape, ";");
    _ = parts.next();
    return try parseEscapeSequenceModifier(parts.next().?);
}

pub fn parseEscapeSequence(input: []const u8) !?Event {
    std.debug.print("Input: {s}\r\n", .{input});
    if (input.len == 2) {
        if (input[0] == '[') {
            switch (input[1]) {
                'A' => return .{ .keyboard = .{ .key = .up } },
                'B' => return .{ .keyboard = .{ .key = .down } },
                'C' => return .{ .keyboard = .{ .key = .right } },
                'D' => return .{ .keyboard = .{ .key = .left } },
                'F' => return .{ .keyboard = .{ .key = .end } },
                'H' => return .{ .keyboard = .{ .key = .home } },
                'Z' => return .{ .keyboard = .{ .key = .tab, .modifiers = .{ .shift = true } } },
                else => return null,
            }
        } else if (input[0] == 'O') {
            switch (input[1]) {
                'P' => return .{ .keyboard = .{ .key = .f1 } },
                'Q' => return .{ .keyboard = .{ .key = .f2 } },
                'R' => return .{ .keyboard = .{ .key = .f3 } },
                'S' => return .{ .keyboard = .{ .key = .f4 } },
                else => return null,
            }
        }
    } else {
        const st = input[input.len - 1];
        const first = input[0];

        if (first == '<') {
            // TODO: Mouse input
        } else {
            switch (st) {
                'P' => return .{ .keyboard = .{ .key = .f1, .modifiers = try shortEscapeModifier(input[1 .. input.len - 1]) } },
                'Q' => return .{ .keyboard = .{ .key = .f2, .modifiers = try shortEscapeModifier(input[1 .. input.len - 1]) } },
                'R' => return .{ .keyboard = .{ .key = .f3, .modifiers = try shortEscapeModifier(input[1 .. input.len - 1]) } },
                'S' => return .{ .keyboard = .{ .key = .f4, .modifiers = try shortEscapeModifier(input[1 .. input.len - 1]) } },
                'A' => return .{ .keyboard = .{ .key = .up, .modifiers = try shortEscapeModifier(input[1 .. input.len - 1]) } },
                'B' => return .{ .keyboard = .{ .key = .down, .modifiers = try shortEscapeModifier(input[1 .. input.len - 1]) } },
                'C' => return .{ .keyboard = .{ .key = .right, .modifiers = try shortEscapeModifier(input[1 .. input.len - 1]) } },
                'D' => return .{ .keyboard = .{ .key = .left, .modifiers = try shortEscapeModifier(input[1 .. input.len - 1]) } },
                'F' => return .{ .keyboard = .{ .key = .end, .modifiers = try shortEscapeModifier(input[1 .. input.len - 1]) } },
                'H' => return .{ .keyboard = .{ .key = .home, .modifiers = try shortEscapeModifier(input[1 .. input.len - 1]) } },
                '~' => {
                    var parts = std.mem.split(u8, input[1 .. input.len - 1], ";");
                    const match = try std.fmt.parseInt(u8, parts.next().?, 10);
                    var modifiers: Modifiers = .{};
                    if (parts.next()) |next| {
                        modifiers = try parseEscapeSequenceModifier(next);
                    }

                    const key: Key = switch (match) {
                        1 => .home,
                        2 => .insert,
                        3 => .delete,
                        4 => .end,
                        // TODO: Special sequence for shift+pageup
                        5 => .pageup,
                        // TODO: Special sequence for shift+pagedown
                        6 => .pagedown,
                        7 => .home,
                        8 => .end,
                        10 => .f0,
                        11 => .f1,
                        12 => .f2,
                        13 => .f3,
                        14 => .f4,
                        15 => .f5,
                        17 => .f6,
                        18 => .f7,
                        19 => .f8,
                        20 => .f9,
                        21 => .f10,
                        23 => .f11,
                        24 => .f12,
                        25 => .f13,
                        26 => .f14,
                        28 => .f15,
                        29 => .f16,
                        31 => .f17,
                        32 => .f18,
                        33 => .f19,
                        34 => .f20,
                        else => return null,
                    };

                    return .{ .keyboard = .{ .key = key, .modifiers = modifiers } };
                },
                // TODO: Rest of options
                else => return null,
            }
        }
    }
    return null;
}
