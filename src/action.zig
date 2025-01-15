const std = @import("std");

pub const Canvas = enum {
    EnterAlternateBuffer,
    ExitAlternateBuffer,
    SaveCursor,
    RestoreCursor,

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return writer.print("{s}", .{switch (value) {
            .EnterAlternateBuffer => "\x1b[?1049h",
            .ExitAlternateBuffer => "\x1b[?1049l",
            .SaveCursor => "\x1b[s",
            .RestoreCursor => "\x1b[u",
        }});
    }
};

pub const Cursor = struct {
    up: ?u16 = null,
    down: ?u16 = null,
    left: ?u16 = null,
    right: ?u16 = null,
    col: ?u16 = null,
    row: ?u16 = null,
    visibility: ?enum { visible, hidden } = null,
    blink: ?bool = null,
    shape: ?enum {
        block,
        block_blink,
        underline,
        underline_blink,
        bar,
        bar_blink,
        user,
    } = null,

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        if (value.up) |u| {
            try writer.print("\x1b[{d}A", .{u});
        }

        if (value.down) |d| {
            try writer.print("\x1b[{d}B", .{d});
        }

        if (value.left) |b| {
            try writer.print("\x1b[{d}D", .{b});
        }

        if (value.right) |f| {
            try writer.print("\x1b[{d}C", .{f});
        }

        if (value.col != null and value.row != null) {
            try writer.print("\x1b[{d};{d}H", .{ value.row.?, value.col.? });
        } else if (value.col) |_x| {
            try writer.print("\x1b[{d}G", .{_x});
        } else if (value.row) |_y| {
            try writer.print("\x1b[{d}d", .{_y});
        }

        if (value.blink) |b| {
            if (b) try writer.print("\x1b[?12h", .{}) else try writer.print("\x1b[?12l", .{});
        }

        if (value.visibility) |visibility| {
            switch (visibility) {
                .visible => try writer.print("\x1b[?25h", .{}),
                .hidden => try writer.print("\x1b[?25l", .{}),
            }
        }

        if (value.shape) |shape| {
            switch (shape) {
                .user => try writer.print("\x1b[0 q", .{}),
                .block_blink => try writer.print("\x1b[1 q", .{}),
                .block => try writer.print("\x1b[2 q", .{}),
                .underline_blink => try writer.print("\x1b[3 q", .{}),
                .underline => try writer.print("\x1b[4 q", .{}),
                .bar_blink => try writer.print("\x1b[5 q", .{}),
                .bar => try writer.print("\x1b[6 q", .{}),
            }
        }
    }
};

pub const Erase = enum(u2) {
    ToEnd = 0,
    FromBeginning = 1,
    All = 2,
};

pub const Screen = union(enum) {
    pub const SoftReset: @This() = .{ .soft_reset = {} };
    pub const Save: @This() = .{ .save = {} };
    pub const Restore: @This() = .{ .restore = {} };

    scroll_up: u16,
    scroll_down: u16,
    erase: Erase,
    title: []const u8,
    soft_reset: void,
    save: void,
    restore: void,

    pub fn scroll_up(u: u16) @This() {
        return .{ .scroll_up = u };
    }

    pub fn scroll_down(d: u16) @This() {
        return .{ .scroll_down = d };
    }

    pub fn erase(e: Erase) @This() {
        return .{ .erase = e };
    }

    pub fn title(t: []const u8) @This() {
        return .{ .title = t };
    }

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (value) {
            .scroll_up => |u| try writer.print("\x1b[{d}S", .{u}),
            .scroll_down => |u| try writer.print("\x1b[{d}T", .{u}),
            .erase => |e| try writer.print("\x1b[{d}J", .{@intFromEnum(e)}),
            .title => |t| try writer.print("\x1b]0;{s}\x07", .{t}),
            .soft_reset => try writer.print("\x1b[!p", .{}),
            .save => try writer.print("\x1b[47h", .{}),
            .restore => try writer.print("\x1b[47l", .{}),
        }
    }
};

pub const Line = union(enum) {
    insert: u16,
    delete: u16,
    erase: Erase,

    pub fn insert(i: u16) @This() {
        return .{ .insert = i };
    }

    pub fn delete(d: u16) @This() {
        return .{ .delete = d };
    }

    pub fn erase(e: Erase) @This() {
        return .{ .erase = e };
    }

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (value) {
            .insert => |u| try writer.print("\x1b[{d}L", .{u}),
            .delete => |u| try writer.print("\x1b[{d}M", .{u}),
            .erase => |e| try writer.print("\x1b[{d}K", .{@intFromEnum(e)}),
        }
    }
};

pub const Character = union(enum) {
    insert: u16,
    delete: u16,
    erase: u16,

    pub fn insert(i: u16) @This() {
        return .{ .insert = i };
    }

    pub fn delete(d: u16) @This() {
        return .{ .delete = d };
    }

    pub fn erase(e: u16) @This() {
        return .{ .erase = e };
    }

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (value) {
            .insert => |u| try writer.print("\x1b[{d}@", .{u}),
            .delete => |u| try writer.print("\x1b[{d}P", .{u}),
            .erase => |u| try writer.print("\x1b[{d}X", .{u}),
        }
    }
};

test "action::Canvas::format" {
    var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Canvas.EnterAlternateBuffer });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[?1049h"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Canvas.ExitAlternateBuffer });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[?1049l"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Canvas.SaveCursor });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[s"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Canvas.RestoreCursor });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[u"));
    std.testing.allocator.free(format);
}

test "action::Cursor::format" {
    var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Cursor {
        .up = 1,
        .down = 2,
        .left = 3,
        .right = 4,
        .col = 5,
        .row = 6,
        .blink = true,
        .visibility = .visible,
        .shape = .bar,
    }});
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1A\x1b[2B\x1b[3D\x1b[4C\x1b[6;5H\x1b[?12h\x1b[?25h\x1b[6 q"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Cursor {
        .col = 5,
        .blink = false,
        .visibility = .hidden,
        .shape = .block,
    }});
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[5G\x1b[?12l\x1b[?25l\x1b[2 q"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Cursor {
        .row = 6,
        .shape = .underline,
    }});
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[6d\x1b[4 q"));
    std.testing.allocator.free(format);
}

test "action::Screen::format" {
    var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.SoftReset });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[!p"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.Save });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[47h"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.Restore });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[47l"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.scroll_up(1) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1S"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.scroll_down(2) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[2T"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.erase(.ToEnd) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[0J"));
    std.testing.allocator.free(format);
    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.erase(.FromBeginning) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1J"));
    std.testing.allocator.free(format);
    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.erase(.All) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[2J"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Screen.title("test title") });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b]0;test title\x07"));
    std.testing.allocator.free(format);
}

test "action::Line::format" {
    var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Line.insert(1) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1L"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Line.delete(2) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[2M"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Line.erase(.ToEnd) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[0K"));
    std.testing.allocator.free(format);
    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Line.erase(.FromBeginning) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1K"));
    std.testing.allocator.free(format);
    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Line.erase(.All) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[2K"));
    std.testing.allocator.free(format);
}

test "action::Character::format" {
    var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Character.insert(1) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1@"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Character.delete(2) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[2P"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Character.erase(3) });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[3X"));
    std.testing.allocator.free(format);
}
