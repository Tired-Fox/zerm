const std = @import("std");
const event = @import("../event.zig");
const Screen = @import("../action.zig").Screen;

const Event = event.Event;
const MouseEventKind = event.MouseEventKind;
const KeyEvent = event.KeyEvent;
const Modifiers = event.Modifiers;
const EnhancementFlags = event.EnhancementFlags;
const KeyCode = event.KeyCode;

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

    /// Parse the next terminal/input event
    ///
    /// This method will block until the next event
    pub fn parseEvent(self: *@This()) !?Event {
        const stdin = std.fs.File.stdin();
        var buffer: [1024]u8 = undefined;
        var reader = stdin.reader(&buffer);

        var buff: [1]u8 = undefined;
        _ = try reader.read(&buff);

        switch (buff[0]) {
            0x1B => {
                if (self.pollEvent()) {
                    _ = try reader.read(&buff);
                    switch (buff[0]) {
                        '[' => return try self.parseCsi(&reader),
                        'O' => if (self.pollEvent()) {
                            _ = try reader.read(&buff);
                            switch (buff[0]) {
                                'D' => return Event { .key = .{ .code = .left }},
                                'C' => return Event { .key = .{ .code = .right }},
                                'A' => return Event { .key = .{ .code = .up }},
                                'B' => return Event { .key = .{ .code = .down }},
                                'H' => return Event { .key = .{ .code = .home }},
                                'F' => return Event { .key = .{ .code = .end }},

                                // F1 - F4
                                'P' => return Event { .key = .{ .code = .f(1) }},
                                'Q' => return Event { .key = .{ .code = .f(2) }},
                                'R' => return Event { .key = .{ .code = .f(3) }},
                                'S' => return Event { .key = .{ .code = .f(4) }},
                                else => {}
                            }
                        },
                        0x1B => return Event{ .key = .{ .code = .esc } },
                        else => {
                            if (try self.parseEvent()) |evt| {
                                var e = evt;
                                e.key.modifiers.alt = true;
                                return e;
                            }
                        }
                    }
                } else {
                    return Event { .key = .{ .code = .esc } };
                }
            },
            '\r' => return Event { .key = .{ .code = .enter }},
            '\n' => if (Screen.isRawModeEnabled()) {
                return Event { .key = .{ .code = .char('j'), .modifiers = .{ .ctrl = true }}};
            } else {
                return Event { .key = .{ .code = .enter }};
            },
            '\t' => return Event { .key = .{ .code = .tab } },
            0x7F => return Event { .key = .{ .code = .backspace } },
            0x00 => return Event { .key = .{ .code = .char(' '), .modifiers = .{ .ctrl = true }}},
            0x01...0x08 => return Event { .key = .{ .code = .char(@as(u21, @intCast(buff[0])) - 0x1 + 'a'), .modifiers = .{ .ctrl = true }}},
            0x0B...0x0C => return Event { .key = .{ .code = .char(@as(u21, @intCast(buff[0])) - 0x1 + 'a'), .modifiers = .{ .ctrl = true }}},
            0x0E...0x1A => return Event { .key = .{ .code = .char(@as(u21, @intCast(buff[0])) - 0x1 + 'a'), .modifiers = .{ .ctrl = true }}},
            0x1C...0x1F => return Event { .key = .{ .code = .char(@as(u21, @intCast(buff[0])) - 0x1C + '4'), .modifiers = .{ .ctrl = true }}},
            // TODO: Parse utf8 char and check if more chars are needed to make utf-8 encoding
            // ref: <https://github.com/crossterm-rs/crossterm/blob/master/src/event/sys/unix/parse.rs#L825>
            else => return Event { .key = .{ .code = .char(buff[0]) } },
        }

        return null;
    }

    fn parseCsi(self: *@This(), reader: *std.fs.File.Reader) !?Event {
        var buff = [1]u8{0};
        var buffer: std.ArrayList(u8) = .empty;
        defer buffer.deinit(self.alloc);

        while (self.pollEvent()) {
            _ = try reader.read(&buff);
            try buffer.append(self.alloc, buff[0]);
            if (isSequenceEnd(buff[0])) break;
        }

        const sequence = buffer.items;

        if (sequence.len == 0) {
            return null;
        } else if (sequence.len == 1) {
            switch (sequence[0]) {
                'O' => return Event { .focus = false },
                'I' => return Event { .focus = true },
                'A' => return Event { .key = .{ .code = .up }},
                'B' => return Event { .key = .{ .code = .down }},
                'C' => return Event { .key = .{ .code = .right }},
                'D' => return Event { .key = .{ .code = .left }},
                'F' => return Event { .key = .{ .code = .end }},
                'H' => return Event { .key = .{ .code = .home }},
                'P' => return Event { .key = .{ .code = .f(1) }},
                'Q' => return Event { .key = .{ .code = .f(2) }},
                'S' => return Event { .key = .{ .code = .f(4) }},
                'Z' => return Event { .key = .{ .code = .back_tab }},
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
                    var iter = std.mem.splitSequence(u8, sequence[0..sequence.len-1], ";");
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
        var split = std.mem.splitSequence(u8, sequence, ";");
        _ = split.next();

        var modifiers_mask: ?u8 = null;
        var kind_code: ?u8 = null;

        if (split.next()) |m| {
            var sub_iter = std.mem.splitSequence(u8, m, ":");
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

        const keycode: ?KeyCode = switch(key) {
            'A' => .up,
            'B' => .down,
            'C' => .right,
            'D' => .left,
            'F' => .end,
            'H' => .home,
            'P' => .f(1),
            'Q' => .f(2),
            'R' => .f(3),
            'S' => .f(4),
            else => null,
        };

        if (keycode) |k| {
            return Event{
                .key = .{
                    .code = k,
                    .modifiers = modifiers,
                    .kind = kind
                }
            };
        }
        return null;
    }

    fn parseCsiUEncodedKeyCode(self: *@This(), sequence: []const u8) !?Event {
        _ = self;
        var it = std.mem.splitSequence(u8, sequence, ";");

        if (it.next()) |a| {
            var codepoints = std.mem.splitSequence(u8, a, ":");

            if (codepoints.next()) |cp| {
                const codepoint = try std.fmt.parseInt(u21, cp, 10);
                var modifiers_mask: ?u8 = null;
                var kind_code: ?u8 = null;

                if (it.next()) |m| {
                    var sub_iter = std.mem.splitSequence(u8, m, ":");
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

                var keycode: KeyCode = .char(codepoint);
                var state: KeyEvent.State = .{};
                if (translateFunctionalKeyCode(codepoint)) |tf| {
                    keycode = tf[0];
                    state = tf[1];
                } else {
                    switch (codepoint) {
                        0x1B => keycode = .esc,
                        '\r' => keycode = .enter,
                        // Issue #371: \n = 0xA, which is also the keycode for Ctrl+J. The only reason we get
                        // newlines as input is because the terminal converts \r into \n for us. When we
                        // enter raw mode, we disable that, so \n no longer has any meaning - it's better to
                        // use Ctrl+J. Waiting to handle it here means it gets picked up later
                        '\n'  => if (!Screen.isRawModeEnabled()) { keycode = .enter; },
                        '\t' => {
                            if (modifiers.shift) {
                                keycode = .back_tab;
                            } else {
                                keycode = .tab;
                            }
                        },
                        0x7F => keycode = .backspace,
                        else => {}
                    }
                }

                switch (keycode) {
                    .modifier => |modifier| {
                        switch (modifier) {
                            .left_alt, .right_alt => modifiers.alt = true,
                            .left_control, .right_control => modifiers.ctrl = true,
                            .left_shift, .right_shift => modifiers.shift = true,
                            .left_super, .right_super => modifiers.super = true,
                            .left_hyper, .right_hyper => modifiers.hyper = true,
                            .left_meta, .right_meta => modifiers.meta = true,
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
                        keycode = .char(try std.fmt.parseInt(u21, shifted_c, 10));
                        modifiers.shift = false;
                    }
                }

                return Event {
                    .key = .{
                        .code = keycode,
                        .modifiers = modifiers,
                        .state = .from(key_state.bits() | state.bits()),
                        .kind = kind
                    }
                };
            }
        }

        return null;
    }

    fn parseCsiSpecialKeyCode(self: *@This(), sequence: []const u8) !?Event {
        _ = self;
        var iter = std.mem.splitSequence(u8, sequence, ";");

        if (iter.next()) |a| {
            const first = try std.fmt.parseInt(u8, a, 10);

            var modifiers_mask: ?u8 = null;
            var kind_code: ?u8 = null;

            if (iter.next()) |m| {
                var sub_iter = std.mem.splitSequence(u8, m, ":");
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

            const keycode: KeyCode = switch (first) {
                1, 7 => .home,
                2 => .insert,
                3 => .delete,
                4, 8 => .end,
                5 => .page_up,
                6 => .page_down,
                11...15 => .f(@intCast(first - 10)),
                17...21 => .f(@intCast(first - 11)),
                23...26 => .f(@intCast(first - 12)),
                28...29 => .f(@intCast(first - 15)),
                31...34 => .f(@intCast(first - 17)),
                else => return null,
            };

            return Event {
                .key = .{
                    .code = keycode,
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
        var iter = std.mem.splitSequence(u8, sequence, ";");
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

    fn parseCsiBracketedPaste(self: *@This(), reader: *std.fs.File.Reader) !?Event {
        var buff = [1]u8{0};
        var buffer: std.ArrayList(u8) = .empty;
        defer buffer.deinit(self.alloc);

        while (self.pollEvent()) {
            _ = try reader.read(&buff);
            switch (buff[0]) {
                '~' => {
                    if (buffer.items.len >= 5 and std.mem.eql(u8, buffer.items[buffer.items.len-5..buffer.items.len], "\x1b[201")) {
                        buffer.shrinkAndFree(self.alloc, buffer.items.len - 5);
                        break;
                    }
                    try buffer.append(self.alloc, buff[0]);
                },
                else => try buffer.append(self.alloc, buff[0]),
            }
        }

        if (self.paste) |paste| self.alloc.free(paste);

        const content = try buffer.toOwnedSlice(self.alloc);
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
        var iter = std.mem.splitSequence(u8, sequence, ";");
        _ = iter.next();

        var modifiers_mask: ?u8 = null;
        var kind_code: ?u8 = null;

        if (iter.next()) |m| {
            var sub_iter = std.mem.splitSequence(u8, m, ":");
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

        const key: KeyCode = switch (sequence[sequence.len - 1]) {
            'A' => .up,
            'B' => .down,
            'C' => .right,
            'D' => .left,
            'F' => .end,
            'H' => .home,
            'P' => .f(1),
            'Q' => .f(2),
            'R' => .f(3),
            'S' => .f(4),
            else => return null,
        };

        return Event{
            .key = .{
                .code = key,
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
        var iter = std.mem.splitSequence(u8, sequence, ";");
        const cb: u8 = if (iter.next()) |next| try std.fmt.parseInt(u8, next, 10) else return null;
        const cx: u16 = if (iter.next()) |next| try std.fmt.parseInt(u16, next, 10) else return null;
        const cy: u16 = if (iter.next()) |next| try std.fmt.parseInt(u16, next, 10) else return null;

        const released = sequence[sequence.len - 1] == 'm';

        var kind, const modifiers = parseCb(cb);
        if (released) kind = MouseEventKind { .up = kind.down };

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
        var kind: MouseEventKind = .{ .move = {} };
        if (!dragging) {
            switch (button_number) {
                0 => kind = .{ .down = .left },
                1 => kind = .{ .down = .middle },
                2 => kind = .{ .down = .right },
                3 => kind = .{ .up = .left },

                4 => kind = .scroll_up,
                5 => kind = .scroll_down,
                6 => kind = .scroll_left,
                7 => kind = .scroll_right,
                else => {}
            }
        } else {
            switch (button_number) {
                0 => kind = .{ .drag = .left },
                1 => kind = .{ .drag = .middle },
                2 => kind = .{ .drag = .right },

                3,4,5 => kind = .{ .move = {} },
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

fn translateFunctionalKeyCode(codepoint: u21) ?std.meta.Tuple(&[_]type{ KeyCode, KeyEvent.State }) {
    var key: ?KeyCode = switch (codepoint) {
        57399 => .char('0'),
        57400 => .char('1'),
        57401 => .char('2'),
        57402 => .char('3'),
        57403 => .char('4'),
        57404 => .char('5'),
        57405 => .char('6'),
        57406 => .char('7'),
        57407 => .char('8'),
        57408 => .char('9'),
        57409 => .char('.'),
        57410 => .char('/'),
        57411 => .char('*'),
        57412 => .char('-'),
        57413 => .char('+'),
        57414 => .enter,
        57415 => .char('='),
        57416 => .char(','),
        57417 => .left,
        57418 => .right,
        57419 => .up,
        57420 => .down,
        57421 => .page_up,
        57422 => .page_down,
        57423 => .home,
        57424 => .end,
        57425 => .insert,
        57426 => .delete,
        57427 => .keypad_begin,
        else => null
    };

    if (key) |k| {
        return .{ k, KeyEvent.State { .keypad = true } };
    }

    key = switch (codepoint) {
        57358 => .caps_lock,
        57359 => .scroll_lock,
        57360 => .num_lock,
        57361 => .print_screen,
        57362 => .pause,
        57363 => .menu,
        57376 => .f(13),
        57377 => .f(14),
        57378 => .f(15),
        57379 => .f(16),
        57380 => .f(17),
        57381 => .f(18),
        57382 => .f(19),
        57383 => .f(20),
        57384 => .f(21),
        57385 => .f(22),
        57386 => .f(23),
        57387 => .f(24),
        57388 => .f(25),
        57389 => .f(26),
        57390 => .f(27),
        57391 => .f(28),
        57392 => .f(29),
        57393 => .f(30),
        57394 => .f(31),
        57395 => .f(32),
        57396 => .f(33),
        57397 => .f(34),
        57398 => .f(35),
        57428 => .media(.play),
        57429 => .media(.pause),
        57430 => .media(.play_pause),
        57431 => .media(.reverse),
        57432 => .media(.stop),
        57433 => .media(.fast_forward),
        57434 => .media(.rewind),
        57435 => .media(.track_next),
        57436 => .media(.track_previous),
        57437 => .media(.record),
        57438 => .media(.lower_volume),
        57439 => .media(.raise_volume),
        57440 => .media(.mute_volume),
        57441 => .mod(.left_shift),
        57442 => .mod(.left_control),
        57443 => .mod(.left_alt),
        57444 => .mod(.left_super),
        57445 => .mod(.left_hyper),
        57446 => .mod(.left_meta),
        57447 => .mod(.right_shift),
        57448 => .mod(.right_control),
        57449 => .mod(.right_alt),
        57450 => .mod(.right_super),
        57451 => .mod(.right_hyper),
        57452 => .mod(.right_meta),
        57453 => .mod(.iso_level_3_shift),
        57454 => .mod(.iso_level_5_shift),
        else => null,
    };

    if (key) |k| {
        return .{ k, .{} };
    }

    return null;
}
