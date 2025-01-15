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

pub const Modifiers = packed struct(u6) {
    alt: bool = false,
    ctrl: bool = false,
    shift: bool = false,
    num_lock: bool = false,
    scroll_lock: bool = false,
    caps_lock: bool = false,

    pub fn merge(a: @This(), b: @This()) @This() {
        return .{
            .alt = a.alt or b.alt,
            .ctrl = a.ctrl or b.ctrl,
            .shift = a.shift or b.shift,
            .num_lock = a.num_lock or b.num_lock,
            .scroll_lock = a.scroll_lock or b.scroll_lock,
            .caps_lock = a.caps_lock or b.caps_lock,
        };
    }
};

const utils = switch (@import("builtin").target.os.tag) {
    .windows => struct {
        extern "kernel32" fn GetNumberOfConsoleInputEvents(
            hConsoleInput: std.os.windows.HANDLE,
            lpcNumberOfEvents: *std.os.windows.DWORD
        ) callconv(.winapi) std.os.windows.BOOL;
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
            const result = utils.GetNumberOfConsoleInputEvents(std.os.windows.GetStdHandle(std.os.windows.STD_INPUT_HANDLE), &count);
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

// TODO:
// - implement parse event method

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
