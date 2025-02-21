const std = @import("std");
const event = @import("../event.zig");
const Screen = @import("../action.zig").Screen;

const Event = event.Event;
const MouseEventKind = event.MouseEventKind;
const KeyEvent = event.KeyEvent;
const Modifiers = event.Modifiers;
const EnhancementFlags = event.EnhancementFlags;
const Key = event.Key;

pub const EventStream = struct {
    alloc: std.mem.Allocator,

    paste: ?[]const u8 = null,

    pub fn init(alloc: std.mem.Allocator) @This() {
        return .{ .alloc = alloc };
    }

    pub fn deinit(self: *@This()) void {
        if (self.paste) |paste| self.alloc.free(paste);
    }

    /// Check if the stdin buffer has data to read
    ///
    /// @return true if there is data in the buffer
    pub fn pollEvent(self: *const @This()) bool {
        _ = self;
        switch (@import("builtin").os.tag) {
            .windows => {
                return (@import("windows.zig").getNumberOfConsoleInputEvents() catch 0) > 0;
            },
            else => {
                var buffer: [1]std.os.linux.pollfd = [_]std.os.linux.pollfd{std.os.linux.pollfd{
                    .fd = std.os.linux.STDIN_FILENO,
                    .events = std.os.linux.POLL.IN,
                    .revents = 0,
                }};
                return std.os.linux.poll(&buffer, 1, 1) > 0;
            }
        }
    }

    pub fn parseEvent(self: *@This()) !?Event {
        if (!self.pollEvent()) return null;

        const stdin = std.io.getStdIn();
        const reader = stdin.reader();

        var buff: [1]u8 = undefined;
        _ = try reader.read(&buff);

        switch (buff[0]) {
            0x1B => {
                if (self.pollEvent()) {
                    _ = try reader.read(&buff);
                    switch (buff[0]) {
                        '[' => return try self.parseCsi(reader),
                        'O' => {
                            var buffer = std.ArrayList(u8).init(self.alloc);
                            defer buffer.deinit();


                            while (self.pollEvent()) {
                                _ = try reader.read(&buff);
                                try buffer.append(buff[0]);
                                if (isSequenceEnd(buff[0])) break;
                            }

                            const sequence = buffer.items;

                            if (sequence.len == 1) {
                                switch (sequence[0]) {
                                    'D' => return Event { .key = .{ .key = Key.Left }},
                                    'C' => return Event { .key = .{ .key = Key.Right }},
                                    'A' => return Event { .key = .{ .key = Key.Up }},
                                    'B' => return Event { .key = .{ .key = Key.Down }},
                                    'H' => return Event { .key = .{ .key = Key.Home }},
                                    'F' => return Event { .key = .{ .key = Key.End }},

                                    // F1 - F4
                                    'P' => return Event { .key = .{ .key = Key.f(1) }},
                                    'Q' => return Event { .key = .{ .key = Key.f(2) }},
                                    'R' => return Event { .key = .{ .key = Key.f(3) }},
                                    'S' => return Event { .key = .{ .key = Key.f(4) }},
                                    else => {}
                                }
                            }
                        },
                        0x1B => return Event{ .key = .{ .key = Key.Esc } },
                        else => {
                            if (try self.parseEvent()) |evt| {
                                var e = evt;
                                e.key.modifiers.alt = true;
                                return e;
                            }
                        }
                    }
                } else {
                    return Event { .key = .{ .key = Key.Esc } };
                }
            },
            '\r' => return Event { .key = .{ .key = Key.Enter }},
            '\n' => if (Screen.isRawModeEnabled()) {
                return Event { .key = .{ .key = Key.char('j'), .modifiers = .{ .ctrl = true }}};
            } else {
                return Event { .key = .{ .key = Key.Enter }};
            },
            '\t' => return Event { .key = .{ .key = Key.Tab } },
            0x7F => return Event { .key = .{ .key = Key.Backspace } },
            0x00 => return Event { .key = .{ .key = Key.char(' '), .modifiers = .{ .ctrl = true }}},
            0x01...0x08 => return Event { .key = .{ .key = Key.char(@as(u21, @intCast(buff[0])) - 0x1 + 'a'), .modifiers = .{ .ctrl = true }}},
            0x0B...0x0C => return Event { .key = .{ .key = Key.char(@as(u21, @intCast(buff[0])) - 0x1 + 'a'), .modifiers = .{ .ctrl = true }}},
            0x0E...0x1A => return Event { .key = .{ .key = Key.char(@as(u21, @intCast(buff[0])) - 0x1 + 'a'), .modifiers = .{ .ctrl = true }}},
            0x1C...0x1F => return Event { .key = .{ .key = Key.char(@as(u21, @intCast(buff[0])) - 0x1C + '4'), .modifiers = .{ .ctrl = true }}},
            // TODO: Parse utf8 char and check if more chars are needed to make utf-8 encoding
            // ref: <https://github.com/crossterm-rs/crossterm/blob/master/src/event/sys/unix/parse.rs#L825>
            else => return Event { .key = .{ .key = Key.char(buff[0]) } },
        }

        return null;
    }

    fn parseCsi(self: *@This(), reader: anytype) !?Event {
        var buff = [1]u8{0};
        var buffer = std.ArrayList(u8).init(self.alloc);
        defer buffer.deinit();

        while (self.pollEvent()) {
            _ = try reader.read(&buff);
            try buffer.append(buff[0]);
            if (isSequenceEnd(buff[0])) break;
        }

        const sequence = buffer.items;

        if (sequence.len == 0) {
            return null;
        } else if (sequence.len == 1) {
            switch (sequence[0]) {
                'O' => return Event { .focus = false },
                'I' => return Event { .focus = true },
                'A' => return Event { .key = .{ .key = Key.Up }},
                'B' => return Event { .key = .{ .key = Key.Down }},
                'C' => return Event { .key = .{ .key = Key.Right }},
                'D' => return Event { .key = .{ .key = Key.Left }},
                'F' => return Event { .key = .{ .key = Key.End }},
                'H' => return Event { .key = .{ .key = Key.Home }},
                'P' => return Event { .key = .{ .key = Key.f(1) }},
                'Q' => return Event { .key = .{ .key = Key.f(2) }},
                'S' => return Event { .key = .{ .key = Key.f(4) }},
                'Z' => return Event { .key = .{ .key = Key.BackTab }},
                else => {}
            }
        } else if (sequence[0] == '<') {
            return try self.parseCsiSgrMouse(sequence[1..]);
        } else if (sequence[0] == 'M') {
            return self.parseCsiNormalMouse(sequence[1..]);
        } else if (sequence[0] == ';') {
            return try self.parseCsiModifierKey(sequence[1..]);
        } else if (sequence[0] == '?') {
            switch (sequence[sequence.len - 1]) {
                'u' => return try self.parseCsiKeyboardEnhancementFlags(sequence[1..sequence.len - 1]),
                'c' => return try self.parseCsiPrimaryDeviceAttributes(sequence[1..sequence.len - 1]),
                else => {}
            }
        } else if (std.ascii.isDigit(sequence[0]) and sequence.len > 1) {
            if (std.ascii.startsWithIgnoreCase(sequence, "200~")) {
                return try self.parseCsiBracketedPaste(reader);
            }

            switch (sequence[sequence.len - 1]) {
                'M' => return try self.parseCsiRxvtMouse(sequence[0..sequence.len-1]),
                '~' => return try self.parseCsiSpecialKeyCode(sequence[0..sequence.len-1]),
                'u' => return try self.parseCsiUEncodedKeyCode(sequence[0..sequence.len-1]),
                'R' => {
                    var iter = std.mem.split(u8, sequence[0..sequence.len-1], ";");
                    const cx = try std.fmt.parseInt(u16, iter.next().?, 10);
                    const cy = try std.fmt.parseInt(u16, iter.next().?, 10);

                    return Event { .cursor = .{ cx, cy } };
                },
                else => return try self.parseCsiModifierKeyCode(sequence[0..sequence.len-1]),
            }
        }

        std.debug.print("Unknown CSI sequence: {s}", .{ sequence });
        return null;
    }

    fn parseCsiModifierKeyCode(self: *@This(), sequence: []const u8) !?Event {
        _ = self;
        var split = std.mem.split(u8, sequence, ";");
        _ = split.next();

        var modifiers_mask: ?u8 = null;
        var kind_code: ?u8 = null;

        if (split.next()) |m| {
            var sub_iter = std.mem.split(u8, m, ":");
            if (sub_iter.next()) |a| {
                const mask = try std.fmt.parseInt(u8, a, 10);
                if (sub_iter.next()) |b| {
                    modifiers_mask = mask;
                    kind_code = try std.fmt.parseInt(u8, b, 10);
                } else {
                    modifiers_mask = mask;
                    kind_code = 1;
                }
            }
        }

        var modifiers: Modifiers = .{};
        var kind: KeyEvent.Kind = .press;
        if (modifiers_mask != null and kind_code != null) {
            modifiers = parseModifierFromMask(modifiers_mask.?);
            kind = parseKeyEventKind(kind_code.?);
        } else if (sequence.len > 3) {
            modifiers = parseModifierFromMask(try std.fmt.parseInt(u8, &[_]u8{sequence[sequence.len - 2]}, 10));
        }

        const key = sequence[sequence.len - 1];

        const keycode = switch(key) {
            'A' => Key.Up,
            'B' => Key.Down,
            'C' => Key.Right,
            'D' => Key.Left,
            'F' => Key.End,
            'H' => Key.Home,
            'P' => Key.f(1),
            'Q' => Key.f(2),
            'R' => Key.f(3),
            'S' => Key.f(4),
            else => null,
        };

        if (keycode) |k| {
            return Event{
                .key = .{
                    .key = k,
                    .modifiers = modifiers,
                    .kind = kind
                }
            };
        }
        return null;
    }

    fn parseCsiUEncodedKeyCode(self: *@This(), sequence: []const u8) !?Event {
        _ = self;
        var it = std.mem.split(u8, sequence, ";");

        if (it.next()) |a| {
            var codepoints = std.mem.split(u8, a, ":");

            if (codepoints.next()) |cp| {
                const codepoint = try std.fmt.parseInt(u21, cp, 10);
                var modifiers_mask: ?u8 = null;
                var kind_code: ?u8 = null;

                if (it.next()) |m| {
                    var sub_iter = std.mem.split(u8, m, ":");
                    if (sub_iter.next()) |b| {
                        const mask = try std.fmt.parseInt(u8, b, 10);
                        if (sub_iter.next()) |c| {
                            modifiers_mask = mask;
                            kind_code = try std.fmt.parseInt(u8, c, 10);
                        } else {
                            modifiers_mask = mask;
                            kind_code = 1;
                        }
                    }
                }

                var modifiers: Modifiers = .{};
                var kind: KeyEvent.Kind = .press;
                var key_state: KeyEvent.State = .{};

                if (modifiers_mask != null and kind_code != null) {
                    modifiers = parseModifierFromMask(modifiers_mask.?);
                    kind = parseKeyEventKind(kind_code.?);
                    key_state = parseKeyStateFromMask(kind_code.?);
                }

                var keycode = Key.char(codepoint);
                var state: KeyEvent.State = .{};
                if (translateFunctionalKeyCode(codepoint)) |tf| {
                    keycode = tf[0];
                    state = tf[1];
                } else {
                    switch (codepoint) {
                        0x1B => keycode = Key.Esc,
                        '\r' => keycode = Key.Enter,
                        // Issue #371: \n = 0xA, which is also the keycode for Ctrl+J. The only reason we get
                        // newlines as input is because the terminal converts \r into \n for us. When we
                        // enter raw mode, we disable that, so \n no longer has any meaning - it's better to
                        // use Ctrl+J. Waiting to handle it here means it gets picked up later
                        '\n'  => if (!Screen.isRawModeEnabled()) { keycode = Key.Enter; },
                        '\t' => {
                            if (modifiers.shift) {
                                keycode = Key.BackTab;
                            } else {
                                keycode = Key.Tab;
                            }
                        },
                        0x7F => keycode = Key.Backspace,
                        else => {}
                    }
                }

                switch (keycode) {
                    .modifier => |modifier| {
                        switch (modifier) {
                            .LeftAlt, .RightAlt => modifiers.alt = true,
                            .LeftControl, .RightControl => modifiers.ctrl = true,
                            .LeftShift, .RightShift => modifiers.shift = true,
                            .LeftSuper, .RightSuper => modifiers.super = true,
                            .LeftHyper, .RightHyper => modifiers.hyper = true,
                            .LeftMeta, .RightMeta => modifiers.meta = true,
                            else => {}
                        }
                    },
                    else => {}
                }

                // When the "report alternate keys" flag is enabled in the Kitty Keyboard Protocol
                // and the terminal sends a keyboard event containing shift, the sequence will
                // contain an additional codepoint separated by a ':' character which contains
                // the shifted character according to the keyboard layout.
                if (modifiers.shift) {
                    if (codepoints.next()) |shifted_c| {
                        keycode = Key.char(try std.fmt.parseInt(u21, shifted_c, 10));
                        modifiers.shift = false;
                    }
                }

                return Event {
                    .key = .{
                        .key = keycode,
                        .modifiers = modifiers,
                        .state = key_state.Or(state),
                        .kind = kind
                    }
                };
            }
        }

        return null;
    }

    fn parseCsiSpecialKeyCode(self: *@This(), sequence: []const u8) !?Event {
        _ = self;
        var iter = std.mem.split(u8, sequence, ";");

        if (iter.next()) |a| {
            const first = try std.fmt.parseInt(u8, a, 10);

            var modifiers_mask: ?u8 = null;
            var kind_code: ?u8 = null;

            if (iter.next()) |m| {
                var sub_iter = std.mem.split(u8, m, ":");
                if (sub_iter.next()) |b| {
                    const mask = try std.fmt.parseInt(u8, b, 10);
                    if (sub_iter.next()) |c| {
                        modifiers_mask = mask;
                        kind_code = try std.fmt.parseInt(u8, c, 10);
                    } else {
                        modifiers_mask = mask;
                        kind_code = 1;
                    }
                }
            }

            var modifiers: Modifiers = .{};
            var kind: KeyEvent.Kind = .press;
            var state: KeyEvent.State = .{};

            if (modifiers_mask != null and kind_code != null) {
                modifiers = parseModifierFromMask(modifiers_mask.?);
                kind = parseKeyEventKind(kind_code.?);
                state = parseKeyStateFromMask(kind_code.?);
            }

            const keycode = switch (first) {
                1, 7 => Key.Home,
                2 => Key.Insert,
                3 => Key.Delete,
                4, 8 => Key.End,
                5 => Key.PageUp,
                6 => Key.PageDown,
                11...15 => Key.f(@intCast(first - 10)),
                17...21 => Key.f(@intCast(first - 11)),
                23...26 => Key.f(@intCast(first - 12)),
                28...29 => Key.f(@intCast(first - 15)),
                31...34 => Key.f(@intCast(first - 17)),
                else => return null,
            };

            return Event {
                .key = .{
                    .key = keycode,
                    .kind = kind,
                    .modifiers = modifiers,
                    .state = state,
                }
            };
        }
        return null;
    }

    fn parseCsiRxvtMouse(self: *@This(), sequence: []const u8) !?Event {
        _ = self;
        var iter = std.mem.split(u8, sequence, ";");
        if (iter.next()) |a| {
            const cb = (try std.fmt.parseInt(u8, a, 10)) - 32;
            const kind, const modifiers = parseCb(cb);
            const cx = if (iter.next()) |b| try std.fmt.parseInt(u16, b, 10) else return null;
            const cy = if (iter.next()) |b| try std.fmt.parseInt(u16, b, 10) else return null;

            return Event{
                .mouse = .{
                    .col = cx,
                    .row = cy,
                    .modifiers = modifiers,
                    .kind = kind,
                }
            };
        }
        return null;
    }

    fn parseCsiBracketedPaste(self: *@This(), reader: anytype) !?Event {
        var buff = [1]u8{0};
        var buffer = std.ArrayList(u8).init(self.alloc);
        defer buffer.deinit();

        while (self.pollEvent()) {
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

        if (self.paste) |paste| self.alloc.free(paste);

        const content = try buffer.toOwnedSlice();
        self.paste = content;
        return Event{ .paste = content };
    }

    fn parseCsiKeyboardEnhancementFlags(self: *@This(), sequence: []const u8) !?Event {
        _ = self;
        _ = sequence;
        // _: EnhancementFlags = @bitCast(sequence[0]);
        // Return an event for enhancement flags
        return null;
    }

    fn parseCsiPrimaryDeviceAttributes(self: *@This(), sequence: []const u8) !?Event {
        _ = self;
        _ = sequence;

        // TODO: return an event for primary device attributes
        // source <https://vt100.net/docs/vt510-rm/DA1.html>
        return null;
    }

    fn parseCsiModifierKey(self: *@This(), sequence: []const u8) !?Event {
        _ = self;
        var iter = std.mem.split(u8, sequence, ";");
        _ = iter.next();

        var modifiers_mask: ?u8 = null;
        var kind_code: ?u8 = null;

        if (iter.next()) |m| {
            var sub_iter = std.mem.split(u8, m, ":");
            if (sub_iter.next()) |a| {
                const mask = try std.fmt.parseInt(u8, a, 10);
                if (sub_iter.next()) |b| {
                    modifiers_mask = mask;
                    kind_code = try std.fmt.parseInt(u8, b, 10);
                } else {
                    modifiers_mask = mask;
                    kind_code = 1;
                }
            }
        }

        var modifiers: Modifiers = .{};
        var kind: KeyEvent.Kind = .press;
        if (modifiers_mask != null and kind_code != null) {
            modifiers = parseModifierFromMask(modifiers_mask.?);
            kind = parseKeyEventKind(kind_code.?);
        } else if (sequence.len > 3) {
            modifiers = parseModifierFromMask(try std.fmt.parseInt(u8, &[_]u8{sequence[sequence.len - 2]}, 10));
        }

        const key: Key = switch (sequence[sequence.len - 1]) {
            'A' => Key.Up,
            'B' => Key.Down,
            'C' => Key.Right,
            'D' => Key.Left,
            'F' => Key.End,
            'H' => Key.Home,
            'P' => Key.f(1),
            'Q' => Key.f(2),
            'R' => Key.f(3),
            'S' => Key.f(4),
            else => return null,
        };

        return Event{
            .key = .{
                .key = key,
                .modifiers = modifiers,
                .kind = kind,
            }
        };
    }

    fn parseKeyEventKind(kind: u8) KeyEvent.Kind {
        return switch (kind) {
            2 => .release,
            3 => .repeat,
            else => .press
        };
    }

    fn parseKeyStateFromMask(mask: u8) KeyEvent.State {
        const m = if (mask > 0) mask - 1 else mask;

        return .{
            .caps_lock = m & 64 != 0,
            .num_lock = m & 128 != 0,
        };
    }

    fn parseModifierFromMask(mask: u8) Modifiers {
        const m = if (mask > 0) mask - 1 else mask;

        return .{
            .shift = m & 1 != 0,
            .alt = m & 2 != 0,
            .ctrl = m & 4 != 0,
            .super = m & 8 != 0,
            .hyper = m & 16 != 0,
            .meta = m & 32 != 0,
        };
    }

    fn parseCsiSgrMouse(self: *@This(), sequence: []const u8) !?Event {
        _ = self;
        var iter = std.mem.split(u8, sequence, ";");
        const cb: u8 = if (iter.next()) |next| try std.fmt.parseInt(u8, next, 10) else return null;
        const cx: u16 = if (iter.next()) |next| try std.fmt.parseInt(u16, next, 10) else return null;
        const cy: u16 = if (iter.next()) |next| try std.fmt.parseInt(u16, next, 10) else return null;

        const released = sequence[sequence.len - 1] == 'm';

        var kind, const modifiers = parseCb(cb);
        if (released) kind = MouseEventKind.up(kind.down);

        return Event { .mouse = .{
            .col = cx,
            .row = cy,
            .kind = kind,
            .modifiers = modifiers,
        }};
    }

    fn parseCsiNormalMouse(self: *@This(), sequence: []const u8) ?Event {
        _ = self;

        // Must have 6 characters include `csi M`
        if (sequence.len < 3) return null;

        const kind, const modifiers = parseCb(sequence[0]);

        // See http://www.xfree86.org/current/ctlseqs.html#Mouse%20Tracking
        const cx = sequence[1] - 32;
        const cy = sequence[2] - 32;

        return Event { .mouse = .{
            .col = cx,
            .row = cy,
            .kind = kind,
            .modifiers = modifiers,
        }};
    }

    fn parseCb(c: u8) std.meta.Tuple(&[_]type{ MouseEventKind, Modifiers }) {
        const cb = c - 32;
        const button_number = (cb & 0b0000_0011) | ((cb & 0b1100_0000) >> 4);
        const dragging = cb & 0b0010_0000 == 0b0010_0000;
        var kind: MouseEventKind = MouseEventKind.Move;
        if (!dragging) {
            switch (button_number) {
                0 => kind = MouseEventKind.down(.Left),
                1 => kind = MouseEventKind.down(.Middle),
                2 => kind = MouseEventKind.down(.Right),
                3 => kind = MouseEventKind.up(.Left),

                4 => kind = MouseEventKind.ScrollUp,
                5 => kind = MouseEventKind.ScrollDown,
                6 => kind = MouseEventKind.ScrollLeft,
                7 => kind = MouseEventKind.ScrollRight,
                else => {}
            }
        } else {
            switch (button_number) {
                0 => kind = MouseEventKind.drag(.Left),
                1 => kind = MouseEventKind.drag(.Middle),
                2 => kind = MouseEventKind.drag(.Right),

                3,4,5 => kind = MouseEventKind.Move,
                else => {}
            }
        }

        var modifiers = Modifiers {};
        if (c & 0b0000_0100 == 0b0000_0100) {
            modifiers.shift = true;
        }
        if (c & 0b0000_1000 == 0b0000_1000) {
            modifiers.alt = true;
        }
        if (c & 0b0001_0000 == 0b0001_0000) {
            modifiers.ctrl = true;
        }

        return .{ kind, modifiers };
    }
};

// End of CSI can be 64..=126
pub fn isSequenceEnd(char: u8) bool {
    return '@' <= char and char <= '~';
}

fn translateFunctionalKeyCode(codepoint: u21) ?std.meta.Tuple(&[_]type{ Key, KeyEvent.State }) {
    var key: ?Key = switch (codepoint) {
        57399 => Key.char('0'),
        57400 => Key.char('1'),
        57401 => Key.char('2'),
        57402 => Key.char('3'),
        57403 => Key.char('4'),
        57404 => Key.char('5'),
        57405 => Key.char('6'),
        57406 => Key.char('7'),
        57407 => Key.char('8'),
        57408 => Key.char('9'),
        57409 => Key.char('.'),
        57410 => Key.char('/'),
        57411 => Key.char('*'),
        57412 => Key.char('-'),
        57413 => Key.char('+'),
        57414 => Key.Enter,
        57415 => Key.char('='),
        57416 => Key.char(','),
        57417 => Key.Left,
        57418 => Key.Right,
        57419 => Key.Up,
        57420 => Key.Down,
        57421 => Key.PageUp,
        57422 => Key.PageDown,
        57423 => Key.Home,
        57424 => Key.End,
        57425 => Key.Insert,
        57426 => Key.Delete,
        57427 => Key.KeypadBegin,
        else => null
    };

    if (key) |k| {
        return .{ k, KeyEvent.State.KEYPAD };
    }

    key = switch (codepoint) {
        57358 => Key.CapsLock,
        57359 => Key.ScrollLock,
        57360 => Key.NumLock,
        57361 => Key.PrintScreen,
        57362 => Key.Pause,
        57363 => Key.Menu,
        57376 => Key.f(13),
        57377 => Key.f(14),
        57378 => Key.f(15),
        57379 => Key.f(16),
        57380 => Key.f(17),
        57381 => Key.f(18),
        57382 => Key.f(19),
        57383 => Key.f(20),
        57384 => Key.f(21),
        57385 => Key.f(22),
        57386 => Key.f(23),
        57387 => Key.f(24),
        57388 => Key.f(25),
        57389 => Key.f(26),
        57390 => Key.f(27),
        57391 => Key.f(28),
        57392 => Key.f(29),
        57393 => Key.f(30),
        57394 => Key.f(31),
        57395 => Key.f(32),
        57396 => Key.f(33),
        57397 => Key.f(34),
        57398 => Key.f(35),
        57428 => Key.media(.Play),
        57429 => Key.media(.Pause),
        57430 => Key.media(.PlayPause),
        57431 => Key.media(.Reverse),
        57432 => Key.media(.Stop),
        57433 => Key.media(.FastForward),
        57434 => Key.media(.Rewind),
        57435 => Key.media(.TrackNext),
        57436 => Key.media(.TrackPrevious),
        57437 => Key.media(.Record),
        57438 => Key.media(.LowerVolume),
        57439 => Key.media(.RaiseVolume),
        57440 => Key.media(.MuteVolume),
        57441 => Key.modifier(.LeftShift),
        57442 => Key.modifier(.LeftControl),
        57443 => Key.modifier(.LeftAlt),
        57444 => Key.modifier(.LeftSuper),
        57445 => Key.modifier(.LeftHyper),
        57446 => Key.modifier(.LeftMeta),
        57447 => Key.modifier(.RightShift),
        57448 => Key.modifier(.RightControl),
        57449 => Key.modifier(.RightAlt),
        57450 => Key.modifier(.RightSuper),
        57451 => Key.modifier(.RightHyper),
        57452 => Key.modifier(.RightMeta),
        57453 => Key.modifier(.IsoLevel3Shift),
        57454 => Key.modifier(.IsoLevel5Shift),
        else => null,
    };

    if (key) |k| {
        return .{ k, .{} };
    }

    return null;
}
