const std = @import("std");
const termz = @import("termz");

const Cursor = termz.action.Cursor;
const Screen = termz.action.Screen;
const Line = termz.action.Line;
const Capture = termz.action.Capture;
const Style = termz.style.Style;
const Color = termz.style.Color;
const Reset = termz.style.Reset;
const getTermSize = termz.action.getTermSize;

const Utf8ConsoleOutput = termz.Utf8ConsoleOutput;

const Key = termz.event.Key;

const execute = termz.execute;

pub fn main() !void {
    const cols, const rows = try getTermSize();

    const border = .{
        .tl = '╭',
        .tr = '╮',
        .bl = '╰',
        .br = '╯',
        .l = '│',
        .r = '│',
        .t = '─',
        .b = '─',
    };

    std.log.debug("COLS: {d} ; Rows: {d}", .{ cols, rows });

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allo = arena.allocator();

    var buffer = try Buffer.init(allo, cols, rows);
    defer buffer.deinit();

    try buffer.set(0, 0, border.tl, null);
    try buffer.setRepeatX(1, 0, cols-2, border.t, null);
    try buffer.set(cols-1, 0, border.tr, null);

    for (1..rows-1) |i| {
        try buffer.set(0, @intCast(i), border.l, null);
        try buffer.set(cols-1, @intCast(i), border.r, null);
    }

    try buffer.set(0, rows-1, border.bl, null);
    try buffer.setRepeatX(1, rows-1, cols-2, border.b, null);
    try buffer.set(cols-1, rows-1, border.br, null);

    const message = "Enter any input to exit";
    try buffer.setSlice(@divFloor(cols, 2) - @as(u16, @intCast(@divFloor(message.len, 2))), @divFloor(rows, 2), message, null);

    const utf8_ctx = Utf8ConsoleOutput.init();
    try Screen.enableRawMode();
    errdefer _ = Screen.disableRawMode() catch { std.log.err("error disabling raw mode", .{}); };
    try execute(.Stdout, .{
        Screen.EnterAlternateBuffer,
        Cursor { .col = 1, .row = 1 },
        Cursor.Hide,
        Capture.EnableMouse,
        Capture.EnableFocus,
        Capture.EnableBracketedPaste,
    });


    try buffer.render(std.io.getStdOut().writer());

    var buff = [1]u8{ 0 };
    _ = std.io.getStdIn().reader().read(&buff) catch {};

    _ = Screen.disableRawMode() catch { std.log.err("error disabling raw mode", .{}); };
    _ = execute(.Stdout, .{
        Capture.DisableMouse,
        Capture.DisableFocus,
        Capture.DisableBracketedPaste,
        Cursor.Show,
        Screen.LeaveAlternateBuffer,
    }) catch { std.log.err("error reseting terminal", .{}); };
    utf8_ctx.deinit();
}

const Cell = struct {
    symbol: ?[]const u8 = null,
    style: ?Style = null,
};

const Buffer = struct {
    alloc: std.mem.Allocator,
    inner: []Cell,
    width: u16,
    height: u16,

    pub fn init(alloc: std.mem.Allocator, width: u16, height: u16) !@This() {
        var buff = try alloc.alloc(Cell, @as(usize, @intCast(width)) * @as(usize, @intCast(height)));
        for (0..buff.len) |i| {
            buff[i] = .{};
        }

        return .{
            .inner = buff,
            .alloc = alloc,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: @This()) void {
        for (0..self.inner.len) |i| {
            if (self.inner[i].symbol) |symbol| {
                self.alloc.free(symbol);
            }
        }
        self.alloc.free(self.inner);
    }

    pub fn set(self: *@This(), x: u16, y: u16, char: anytype, style: ?Style) !void {
        const pos: usize = @intCast((y * self.width) + x);
        if (pos >= self.inner.len) return error.OutOfBounds;

        var item = &self.inner[pos];

        switch (@TypeOf(char)) {
            u8 => {
                if (item.symbol) |symbol| self.alloc.free(symbol);
                var buffer = try self.alloc.alloc(u8, 1);
                buffer[0] = char;
                item.symbol = buffer;
            },
            u16 => {
                var buffer = std.ArrayList(u8).init(self.alloc);
                var it = std.unicode.Utf16LeIterator.init([1]u16{ char });
                while (try it.nextCodepoint()) |cp| {
                    var buff: [4]u8 = undefined;
                    const length = try std.unicode.utf8Encode(cp, &buff);
                    try buffer.appendSlice(buff[0..length]);
                }

                if (item.symbol) |*symbol| self.alloc.free(symbol);
                item.symbol = try buffer.toOwnedSlice();
            },
            u21, u32, comptime_int => {
                var buffer = std.ArrayList(u8).init(self.alloc);

                var buff: [4]u8 = [_]u8{0}**4;
                const length = try std.unicode.utf8Encode(@intCast(char), &buff);
                try buffer.appendSlice(buff[0..length]);

                if (item.symbol) |symbol| self.alloc.free(symbol);
                item.symbol = try buffer.toOwnedSlice();
            },
            else => @compileError("type not supported as a buffer cell")
        }

        if (style) |s| {
            item.style = s;
        }
    }

    pub fn setSlice(self: *@This(), x: u16, y: u16, slice: []const u8, style: ?Style) !void {
        for (0..slice.len) |i| {
            try self.set(x + @as(u16, @intCast(i)), y, slice[i], style);
        }
    }

    pub fn setRepeatX(self: *@This(), x: u16, y: u16, count: usize, char: anytype, style: ?Style) !void {
        for (0..count) |i| {
            try self.set(x + @as(u16, @intCast(i)), y, char, style);
        }
    }

    pub fn setRepeatY(self: *@This(), x: u16, y: u16, count: usize, char: anytype, style: ?Style) !void {
        for (0..count) |i| {
            try self.set(x, y + @as(u16, @intCast(i)), char, style);
        }
    }

    pub fn get(self: *const @This(), x: u16, y: u16) ?*const Cell {
        const pos: usize = @intCast((y * self.width) + x);
        if (pos >= self.inner.len) return null;

        return &self.inner[pos];
    }

    pub fn render(self: *const @This(), writer: anytype) !void {
        var buffer = std.io.bufferedWriter(writer);
        var output = buffer.writer();

        for (0..self.height) |h| {
            for (0..self.width) |w| {
                if (self.get(@intCast(w), @intCast(h))) |cell| {
                    if (cell.symbol) |symbol| {
                        try output.print("{s}", .{ symbol });
                    } else {
                        try output.writeByte(' ');
                    }
                } else {
                    return error.OutOfBounds;
                }
            }

            if (h < self.height-1) {
                try output.writeByte('\n');
            }
        }

        try buffer.flush();
    }
};
