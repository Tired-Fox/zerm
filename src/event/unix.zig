const std = @import("std");
const event = @import("../event.zig");

const Event = event.Event;
const Key = event.Key;

pub fn parseEvent(alloc: std.mem.Allocator) !?Event {
    const stdin = std.io.getStdIn();
    const reader = stdin.reader();

    var buff: [1]u8 = undefined;
    _ = try reader.read(&buff);

    switch (buff[0]) {
        0x1B => {
            if (event.pollEvent()) {
                _ = try reader.read(&buff);
                switch (buff[0]) {
                    '[' => {
                        var buffer = std.ArrayList(u8).init(alloc);
                        defer buffer.deinit();


                        while (event.pollEvent()) {
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
                                35 => return Event { .mouse = .{ .col = x, .row = y, .kind = .Move } },
                                64 => return Event { .mouse = .{ .col = x, .row = y, .kind = .ScrollUp } },
                                65 => return Event { .mouse = .{ .col = x, .row = y, .kind = .ScrollDown } },
                                else => {
                                    const kind = if (sequence[sequence.len - 1] == 'm') .{
                                        .down  = switch (variant) {
                                            0 => .Left,
                                            1 => .Middle,
                                            2 => .Right,
                                            66 => .ScrollLeft,
                                            67 => .ScrollRight,
                                            128 => .XButton1,
                                            129 => .XButton2,
                                            else => .Other
                                        }
                                    } else .{
                                        .up  = switch (variant) {
                                            0 => .Left,
                                            1 => .Middle,
                                            2 => .Right,
                                            66 => .ScrollLeft,
                                            67 => .ScrollRight,
                                            128 => .XButton1,
                                            129 => .XButton2,
                                            else => .Other
                                        }
                                    };

                                    return Event { .mouse = .{
                                        .col = x,
                                        .row = y,
                                        .kind = kind 
                                    }};
                                },
                            }
                        } else if (sequence.len == 1) {
                            switch (sequence[0]) {
                                'O' => return Event { .focus = false },
                                'I' => return Event { .focus = true },
                                'A' => return Event { .key = .{ .key = Key.Up } },
                                'B' => return Event { .key = .{ .key = Key.Down } },
                                'C' => return Event { .key = .{ .key = Key.Right } },
                                'D' => return Event { .key = .{ .key = Key.Left } },
                                'F' => return Event { .key = .{ .key = Key.End } },
                                'H' => return Event { .key = .{ .key = Key.Home } },
                                'Z' => return Event { .key = .{ .key = Key.Tab, .modifiers = .{ .shift = true } } },
                                else => {}
                            }
                        } else if (std.mem.eql(u8, sequence, "2~")) {
                            return Event { .key = .{ .key = Key.Insert } };
                        } else if (std.mem.eql(u8, sequence, "3~")) {
                            return Event { .key = .{ .key = Key.Delete } };
                        } else if (std.mem.eql(u8, sequence, "5~")) {
                            return Event { .key = .{ .key = Key.Pageup } };
                        } else if (std.mem.eql(u8, sequence, "6~")) {
                            return Event { .key = .{ .key = Key.Pagedown } };
                        }
                        else if (std.mem.eql(u8, sequence, "201~")) {}
                        else if (std.mem.eql(u8, sequence, "200~")) {
                            buffer.clearAndFree();

                            while (event.pollEvent()) {
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

                            return Event{ .paste = try buffer.toOwnedSlice() };
                        }

                        std.debug.print("Unknown CSI sequence: {s}", .{ sequence });
                        return null;
                    },
                    else => return Event { .key = .{ .key = Key.char(buff[0]), .modifiers = .{ .alt = true } } }
                }
            }
            return Event { .key = .{ .key = Key.Esc } };
        },
        0x0D, 0x0A => return Event { .key = .{ .key = Key.Enter } },
        0x08 => return Event { .key = .{ .key = Key.Backspace, .modifiers = .{ .ctrl = true } } },
        0x09 => return Event { .key = .{ .key = Key.Tab } },
        0x7F => return Event { .key = .{ .key = Key.Backspace } },
        // 126 => return Event { .key = .{ .key = Key.Delete } },
        0x00 => return Event { .key = .{ .key = Key.char(' '), .modifiers = .{ .ctrl = true } } },
        0x01 => return Event { .key = .{ .key = Key.char('a'), .modifiers = .{ .ctrl = true } } },
        0x02 => return Event { .key = .{ .key = Key.char('b'), .modifiers = .{ .ctrl = true } } },
        0x03 => return Event { .key = .{ .key = Key.char('c'), .modifiers = .{ .ctrl = true } } },
        0x04 => return Event { .key = .{ .key = Key.char('d'), .modifiers = .{ .ctrl = true } } },
        0x05 => return Event { .key = .{ .key = Key.char('e'), .modifiers = .{ .ctrl = true } } },
        0x06 => return Event { .key = .{ .key = Key.char('f'), .modifiers = .{ .ctrl = true } } },
        0x07 => return Event { .key = .{ .key = Key.char('g'), .modifiers = .{ .ctrl = true } } },
        // 0x08 => return Event { .key = .{ .key = Key.char('h'), .modifiers = .{ .ctrl = true } } },
        // 0x09 => return Event { .key = .{ .key = Key.char('i'), .modifiers = .{ .ctrl = true } } },
        // 0x0A => return Event { .key = .{ .key = Key.char('j'), .modifiers = .{ .ctrl = true } } },
        0x0B => return Event { .key = .{ .key = Key.char('k'), .modifiers = .{ .ctrl = true } } },
        0x0C => return Event { .key = .{ .key = Key.char('l'), .modifiers = .{ .ctrl = true } } },
        // 0x0D => return Event { .key = .{ .key = Key.char('m'), .modifiers = .{ .ctrl = true } } },
        0x0E => return Event { .key = .{ .key = Key.char('n'), .modifiers = .{ .ctrl = true } } },
        0x0F => return Event { .key = .{ .key = Key.char('o'), .modifiers = .{ .ctrl = true } } },
        0x10 => return Event { .key = .{ .key = Key.char('p'), .modifiers = .{ .ctrl = true } } },
        0x11 => return Event { .key = .{ .key = Key.char('q'), .modifiers = .{ .ctrl = true } } },
        0x12 => return Event { .key = .{ .key = Key.char('r'), .modifiers = .{ .ctrl = true } } },
        0x13 => return Event { .key = .{ .key = Key.char('s'), .modifiers = .{ .ctrl = true } } },
        0x14 => return Event { .key = .{ .key = Key.char('t'), .modifiers = .{ .ctrl = true } } },
        0x15 => return Event { .key = .{ .key = Key.char('u'), .modifiers = .{ .ctrl = true } } },
        0x16 => return Event { .key = .{ .key = Key.char('v'), .modifiers = .{ .ctrl = true } } },
        0x17 => return Event { .key = .{ .key = Key.char('w'), .modifiers = .{ .ctrl = true } } },
        0x18 => return Event { .key = .{ .key = Key.char('x'), .modifiers = .{ .ctrl = true } } },
        0x19 => return Event { .key = .{ .key = Key.char('y'), .modifiers = .{ .ctrl = true } } },
        0x1A => return Event { .key = .{ .key = Key.char('z'), .modifiers = .{ .ctrl = true } } },
        // 0x1B => return Event { .key = .{ .key = Key.char('['), .modifiers = .{ .ctrl = true } } },
        0x1C => return Event { .key = .{ .key = Key.char('\\'), .modifiers =.{ .ctrl = true } } },
        0x1D => return Event { .key = .{ .key = Key.char(']'), .modifiers = .{ .ctrl = true } } },
        0x1E => return Event { .key = .{ .key = Key.char('^'), .modifiers = .{ .ctrl = true } } },
        0x1F => return Event { .key = .{ .key = Key.char('_'), .modifiers = .{ .ctrl = true } } },
        else => return Event { .key = .{ .key = Key.char(buff[0]) } },
    }

    return null;
}

// ABCD F H M PQRS Z m ~
// 65 66 67 68  70  72  77  80 81 82 83  90  109  126
pub fn isSequenceEnd(char: u8) bool {
    return ('A' <= char and char <= 'D')
        or char == 'F'
        or ('H' <= char and char <= 'I')
        or ('M' <= char and char <= 'O')
        or ('P' <= char and char <= 'S')
        or char == 'Z'
        or char == 'm'
        or char == '~';
}
