const std = @import("std");

pub const Key = union(enum) {
    pub const Up: @This() = .{ .up = {} };
    pub const Down: @This() = .{ .down = {} };
    pub const Right: @This() = .{ .right = {} };
    pub const Left: @This() = .{ .left = {} };
    pub const Backspace: @This() = .{ .backspace = {} };
    pub const Esc: @This() = .{ .esc = {} };
    pub const End: @This() = .{ .end = {} };
    pub const Home: @This() = .{ .home = {} };
    pub const Insert: @This() = .{ .insert = {} };
    pub const Delete: @This() = .{ .delete = {} };
    pub const Tab: @This() = .{ .tab = {} };
    pub const Alt: @This() = .{ .alt = {} };
    pub const Enter: @This() = .{ .enter = {} };
    pub const Pageup: @This() = .{ .pageup = {} };
    pub const Pagedown: @This() = .{ .pagedown = {} };
    pub const F0: @This() = .{ .f0 = {} };
    pub const F1: @This() = .{ .f1 = {} };
    pub const F2: @This() = .{ .f2 = {} };
    pub const F3: @This() = .{ .f3 = {} };
    pub const F4: @This() = .{ .f4 = {} };
    pub const F5: @This() = .{ .f5 = {} };
    pub const F6: @This() = .{ .f6 = {} };
    pub const F7: @This() = .{ .f7 = {} };
    pub const F8: @This() = .{ .f8 = {} };
    pub const F9: @This() = .{ .f9 = {} };
    pub const F10: @This() = .{ .f10 = {} };
    pub const F11: @This() = .{ .f11 = {} };
    pub const F12: @This() = .{ .f12 = {} };
    pub const F13: @This() = .{ .f13 = {} };
    pub const F14: @This() = .{ .f14 = {} };
    pub const F15: @This() = .{ .f15 = {} };
    pub const F16: @This() = .{ .f16 = {} };
    pub const F17: @This() = .{ .f17 = {} };
    pub const F18: @This() = .{ .f18 = {} };
    pub const F19: @This() = .{ .f19 = {} };
    pub const F20: @This() = .{ .f20 = {} };
    pub const F21: @This() = .{ .f21 = {} };
    pub const F22: @This() = .{ .f22 = {} };
    pub const F23: @This() = .{ .f23 = {} };
    pub const F24: @This() = .{ .f24 = {} };

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
    char: u21,

    pub fn char(value: u21) @This() {
        return .{ .char = value };
    }

    pub fn eql(current: @This(), other: @This()) bool {
        switch (current) {
            .char => |a| {
                switch (other) {
                    .char => |b| {
                        return a == b;
                    },
                    else => return false,
                }
            },
            else => return @intFromEnum(current) == @intFromEnum(other),
        }
    }
};

pub const Modifiers = packed struct(u3) {
    alt: bool = false,
    ctrl: bool = false,
    shift: bool = false,

    pub fn merge(a: @This(), b: @This()) @This() {
        return .{
            .alt = a.alt or b.alt,
            .ctrl = a.ctrl or b.ctrl,
            .shift = a.shift or b.shift,
        };
    }
};

const Utils = switch (@import("builtin").target.os.tag) {
    .windows => struct {
        extern "kernel32" fn GetNumberOfConsoleInputEvents(
            hConsoleInput: std.os.windows.HANDLE,
            lpcNumberOfEvents: *std.os.windows.DWORD
        ) callconv(.Win64) std.os.windows.BOOL;
    },
    else => struct {}
};

/// Check if the stdin buffer has data to read
///
/// @return true if there is data in the buffer
pub fn pollEvent() bool {
    switch (@import("builtin").target.os.tag) {
        .windows => {
            var count: u32 = 0; 
            const stdin = std.os.windows.GetStdHandle(std.os.windows.STD_INPUT_HANDLE) catch { return false; };
            const result = Utils.GetNumberOfConsoleInputEvents(stdin, &count);
            return result != 0 and count > 0;
        },
        .linux, .macos => {
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
    key: Key,
    modifiers: Modifiers = .{}
};

pub const MouseButton = enum { Left, Middle, Right, ScrollRight, ScrollLeft, Other };
pub const ButtonState = enum(u2) { Pressed, Released };
pub const ScrollDirection = enum(u2) { Up, Down };

pub const MouseButtonEvent = struct {
    type: MouseButton,
    state: ButtonState,
};

pub const MouseEventType = union(enum) {
    move: void,
    button: MouseButtonEvent,
    scroll: ScrollDirection,
};

pub const MouseEvent = struct {
    col: u16,
    row: u16,

    type: MouseEventType,
};

pub const Event = union(enum) {
    key_event: KeyEvent,
    mouse_event: MouseEvent,
    focus_event: bool,
    paste_event: []const u8
};

// ABCD F H M PQRS Z m ~
// 65 66 67 68  70  72  77  80 81 82 83  90  109  126
fn isSequenceEnd(char: u8) bool {
    return ('A' <= char and char <= 'D')
        or char == 'F'
        or ('H' <= char and char <= 'I')
        or ('M' <= char and char <= 'O')
        or ('P' <= char and char <= 'S')
        or char == 'Z'
        or char == 'm'
        or char == '~';
}

/// Parse the next input event.
///
/// The User is responsible for freeing memory allocated from a paste event
///
/// **WARNING**: This function blocks until the next input event.
///
/// **WARNING**: Most of the data is stack allocated, except for the `paste_event`.
/// This event occurs when the `BracketedPaste` feature is enabled and contains a variable
/// length allocated string which is the content pasted into the terminal.
///
/// # Example
///
/// ```zig
/// var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
/// defer arena.deinit();
/// const allocator = arena.allocator();
///
/// if (try events.parseEvent(alloc)) |event| {
///     switch (event) {
///         .paste_event => |content| allocator.free(content),
///         else => {}
///     }
/// }
/// ```
pub fn parseEvent(allocator: std.mem.Allocator) !?Event {
    const stdin = std.io.getStdIn();
    const reader = stdin.reader();

    var buff: [1]u8 = undefined;
    _ = try reader.read(&buff);

    switch (buff[0]) {
        0x1B => {
            if (pollEvent()) {
                _ = try reader.read(&buff);
                switch (buff[0]) {
                    '[' => {
                        var buffer = std.ArrayList(u8).init(allocator);
                        defer buffer.deinit();


                        while (pollEvent()) {
                            _ = try reader.read(&buff);
                            try buffer.append(buff[0]);
                            if (isSequenceEnd(buff[0])) break;
                        }

                        const sequence = buffer.items;

                        if (sequence.len > 0 and sequence[0] == '<') {
                            var iter = std.mem.split(u8, sequence[1..sequence.len - 1], ";");
                            const variant = if (iter.next()) |next| try std.fmt.parseInt(u16, next, 10) else return null;
                            const x = if (iter.next()) |next| try std.fmt.parseInt(u16, next, 10) else return null;
                            const y = if (iter.next()) |next| try std.fmt.parseInt(u16, next, 10) else return null;

                            switch (variant) {
                                35 => return Event { .mouse_event = .{ .col = x, .row = y, .type = .{ .move = {} } } },
                                64 => return Event { .mouse_event = .{ .col = x, .row = y, .type = .{ .scroll = .Down } } },
                                63 => return Event { .mouse_event = .{ .col = x, .row = y, .type = .{ .scroll = .Up } } },
                                else => return Event { .mouse_event = .{
                                    .col = x,
                                    .row = y,
                                    .type = .{
                                        .button = .{
                                            .type = switch (variant) {
                                                0 => .Left,
                                                1 => .Middle,
                                                2 => .Right,
                                                66 => .ScrollLeft,
                                                67 => .ScrollRight,
                                                else => .Other
                                            },
                                            .state = if (sequence[sequence.len - 1] == 'm') .Released else .Pressed
                                        }
                                    }
                                }},
                            }
                        } else if (sequence.len == 1) {
                            switch (sequence[0]) {
                                'O' => return Event { .focus_event = false },
                                'I' => return Event { .focus_event = true },
                                'A' => return Event { .key_event = .{ .key = Key.Up } },
                                'B' => return Event { .key_event = .{ .key = Key.Down } },
                                'C' => return Event { .key_event = .{ .key = Key.Right } },
                                'D' => return Event { .key_event = .{ .key = Key.Left } },
                                'F' => return Event { .key_event = .{ .key = Key.End } },
                                'H' => return Event { .key_event = .{ .key = Key.Home } },
                                'Z' => return Event { .key_event = .{ .key = Key.Tab, .modifiers = .{ .shift = true } } },
                                else => {}
                            }
                        } else if (std.mem.eql(u8, sequence, "2~")) {
                            return Event { .key_event = .{ .key = Key.Insert } };
                        } else if (std.mem.eql(u8, sequence, "3~")) {
                            return Event { .key_event = .{ .key = Key.Delete } };
                        } else if (std.mem.eql(u8, sequence, "5~")) {
                            return Event { .key_event = .{ .key = Key.Pageup } };
                        } else if (std.mem.eql(u8, sequence, "6~")) {
                            return Event { .key_event = .{ .key = Key.Pagedown } };
                        }
                        else if (std.mem.eql(u8, sequence, "201~")) {}
                        else if (std.mem.eql(u8, sequence, "200~")) {
                            buffer.clearAndFree();

                            while (pollEvent()) {
                                _ = try reader.read(&buff);
                                switch (buff[0]) {
                                    '~' => {
                                        if (buffer.items.len >= 5 and std.mem.eql(u8, buffer.items[buffer.items.len-5..buffer.items.len], "\x1b[201")) {
                                            buffer.shrinkAndFree(buffer.items.len - 5);
                                            break;
                                        }
                                        try buffer.append(buff[0]);
                                    },
                                    else => try buffer.append(buff[0]),
                                }
                            }

                            return Event{ .paste_event = try buffer.toOwnedSlice() };
                        }

                        std.debug.print("Unknown CSI sequence: {s}", .{ sequence });
                        return null;
                    },
                    else => return Event { .key_event = .{ .key = Key.char(buff[0]), .modifiers = .{ .alt = true } } }
                }
            }
            return Event { .key_event = .{ .key = Key.Esc } };
        },
        0x0D, 0x0A => return Event { .key_event = .{ .key = Key.Enter } },
        0x08 => return Event { .key_event = .{ .key = Key.Backspace, .modifiers = .{ .ctrl = true } } },
        0x09 => return Event { .key_event = .{ .key = Key.Tab } },
        0x7F => return Event { .key_event = .{ .key = Key.Backspace } },
        // 126 => return Event { .key_event = .{ .key = Key.Delete } },
        0x00 => return Event { .key_event = .{ .key = Key.char(' '), .modifiers = .{ .ctrl = true } } },
        0x01 => return Event { .key_event = .{ .key = Key.char('a'), .modifiers = .{ .ctrl = true } } },
        0x02 => return Event { .key_event = .{ .key = Key.char('b'), .modifiers = .{ .ctrl = true } } },
        0x03 => return Event { .key_event = .{ .key = Key.char('c'), .modifiers = .{ .ctrl = true } } },
        0x04 => return Event { .key_event = .{ .key = Key.char('d'), .modifiers = .{ .ctrl = true } } },
        0x05 => return Event { .key_event = .{ .key = Key.char('e'), .modifiers = .{ .ctrl = true } } },
        0x06 => return Event { .key_event = .{ .key = Key.char('f'), .modifiers = .{ .ctrl = true } } },
        0x07 => return Event { .key_event = .{ .key = Key.char('g'), .modifiers = .{ .ctrl = true } } },
        // 0x08 => return Event { .key_event = .{ .key = Key.char('h'), .modifiers = .{ .ctrl = true } } },
        // 0x09 => return Event { .key_event = .{ .key = Key.char('i'), .modifiers = .{ .ctrl = true } } },
        // 0x0A => return Event { .key_event = .{ .key = Key.char('j'), .modifiers = .{ .ctrl = true } } },
        0x0B => return Event { .key_event = .{ .key = Key.char('k'), .modifiers = .{ .ctrl = true } } },
        0x0C => return Event { .key_event = .{ .key = Key.char('l'), .modifiers = .{ .ctrl = true } } },
        // 0x0D => return Event { .key_event = .{ .key = Key.char('m'), .modifiers = .{ .ctrl = true } } },
        0x0E => return Event { .key_event = .{ .key = Key.char('n'), .modifiers = .{ .ctrl = true } } },
        0x0F => return Event { .key_event = .{ .key = Key.char('o'), .modifiers = .{ .ctrl = true } } },
        0x10 => return Event { .key_event = .{ .key = Key.char('p'), .modifiers = .{ .ctrl = true } } },
        0x11 => return Event { .key_event = .{ .key = Key.char('q'), .modifiers = .{ .ctrl = true } } },
        0x12 => return Event { .key_event = .{ .key = Key.char('r'), .modifiers = .{ .ctrl = true } } },
        0x13 => return Event { .key_event = .{ .key = Key.char('s'), .modifiers = .{ .ctrl = true } } },
        0x14 => return Event { .key_event = .{ .key = Key.char('t'), .modifiers = .{ .ctrl = true } } },
        0x15 => return Event { .key_event = .{ .key = Key.char('u'), .modifiers = .{ .ctrl = true } } },
        0x16 => return Event { .key_event = .{ .key = Key.char('v'), .modifiers = .{ .ctrl = true } } },
        0x17 => return Event { .key_event = .{ .key = Key.char('w'), .modifiers = .{ .ctrl = true } } },
        0x18 => return Event { .key_event = .{ .key = Key.char('x'), .modifiers = .{ .ctrl = true } } },
        0x19 => return Event { .key_event = .{ .key = Key.char('y'), .modifiers = .{ .ctrl = true } } },
        0x1A => return Event { .key_event = .{ .key = Key.char('z'), .modifiers = .{ .ctrl = true } } },
        // 0x1B => return Event { .key_event = .{ .key = Key.char('['), .modifiers = .{ .ctrl = true } } },
        0x1C => return Event { .key_event = .{ .key = Key.char('\\'), .modifiers =.{ .ctrl = true } } },
        0x1D => return Event { .key_event = .{ .key = Key.char(']'), .modifiers = .{ .ctrl = true } } },
        0x1E => return Event { .key_event = .{ .key = Key.char('^'), .modifiers = .{ .ctrl = true } } },
        0x1F => return Event { .key_event = .{ .key = Key.char('_'), .modifiers = .{ .ctrl = true } } },
        else => return Event { .key_event = .{ .key = Key.char(buff[0]) } },
    }

    return null;
}

test "event::pollEvent" {
    try std.testing.expect(!pollEvent());
}

test "event::Key::eql" {
    try std.testing.expect(Key.Esc.eql(Key.Esc));
    try std.testing.expect(Key.char('d').eql(Key.char('d')));
    try std.testing.expect(!Key.char('d').eql(Key.Esc));
}

test "event::Key::char" {
    try std.testing.expectEqual(Key.char('d'), Key { .char = 'd' });
}
