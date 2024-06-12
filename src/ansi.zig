const std = @import("std");
const Point = @import("root.zig").Point;

pub const Query = enum {
    ScreenSize,
    CursorPos,

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return writer.print("{s}", .{switch (value) {
            .ScreenSize => "\x1b[s\x1b[9999;9999H\x1b[6n\x1b[u",
            .CursorPos => "\x1b[6n",
        }});
    }
};

pub const Action = enum {
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
    forward: ?u16 = null,
    backward: ?u16 = null,
    x: ?u16 = null,
    y: ?u16 = null,
    pos: ?Point = null,
    visibility: enum { visible, hidden, none } = .none,
    blink: ?bool = null,
    shape: enum {
        block,
        block_blink,
        underline,
        underline_blink,
        bar,
        bar_blink,
        user,
        none,
    } = .none,

    pub fn up(u: u16) @This() {
        return .{ .up = u };
    }

    pub fn down(d: u16) @This() {
        return .{ .down = d };
    }

    pub fn forward(f: u16) @This() {
        return .{ .forward = f };
    }

    pub fn backward(b: u16) @This() {
        return .{ .backward = b };
    }

    pub fn x(_x: u16) @This() {
        return .{ .x = _x };
    }

    pub fn y(_y: u16) @This() {
        return .{ .y = _y };
    }

    pub fn pos(_x: u16, _y: u16) @This() {
        return .{ .pos = .{ _x, _y } };
    }

    pub fn visible() @This() {
        return .{ .visibility = .visible };
    }

    pub fn hidden() @This() {
        return .{ .visibility = .hidden };
    }

    pub fn blink(b: bool) @This() {
        return .{ .blink = b };
    }

    pub fn user() @This() {
        return .{ .shape = .user };
    }

    pub fn block(b: bool) @This() {
        return .{ .shape = if (b) .block_blink else .block };
    }

    pub fn underline(b: bool) @This() {
        return .{ .shape = if (b) .underline_blink else .underline };
    }

    pub fn bar(b: bool) @This() {
        return .{ .shape = if (b) .bar_blink else .bar };
    }

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        if (value.up) |u| {
            try writer.print("\x1b[{d}A", .{u});
        }
        if (value.down) |d| {
            try writer.print("\x1b[{d}B", .{d});
        }
        if (value.forward) |f| {
            try writer.print("\x1b[{d}C", .{f});
        }
        if (value.backward) |b| {
            try writer.print("\x1b[{d}D", .{b});
        }
        if (value.x) |_x| {
            try writer.print("\x1b[{d}G", .{_x});
        }
        if (value.y) |_y| {
            try writer.print("\x1b[{d}d", .{_y});
        }
        if (value.pos) |p| {
            try writer.print("\x1b[{d};{d}H", .{ p[0], p[1] });
        }

        if (value.blink) |b| {
            if (b) try writer.print("\x1b[?12h", .{}) else try writer.print("\x1b[?12l", .{});
        }

        if (value.visibility != .none) {
            switch (value.visibility) {
                .visible => try writer.print("\x1b[?25h", .{}),
                .hidden => try writer.print("\x1b[?25l", .{}),
                else => {},
            }
        }

        if (value.shape != .none) {
            switch (value.shape) {
                .user => try writer.print("\x1b[0 q", .{}),
                .block_blink => try writer.print("\x1b[1 q", .{}),
                .block => try writer.print("\x1b[2 q", .{}),
                .underline_blink => try writer.print("\x1b[3 q", .{}),
                .underline => try writer.print("\x1b[4 q", .{}),
                .bar_blink => try writer.print("\x1b[5 q", .{}),
                .bar => try writer.print("\x1b[6 q", .{}),
                else => {},
            }
        }
    }
};

pub const Erase = enum(u2) {
    CursorToEnd = 0,
    BeginningToCursor = 1,
    All = 2,
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

pub const Screen = union(enum) {
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

    pub fn soft_reset() @This() {
        return .{ .soft_reset = {} };
    }

    pub fn save() @This() {
        return .{ .save = {} };
    }

    pub fn restore() @This() {
        return .{ .restore = {} };
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

pub const XTerm = enum(u8) {
    Black = 0,
    Maroon = 1,
    Green = 2,
    Olive = 3,
    Navy = 4,
    Purple = 129,
    Teal = 6,
    Silver = 7,
    Grey = 8,
    Red = 9,
    Lime = 10,
    Yellow = 11,
    Blue = 12,
    Fuchsia = 13,
    Aqua = 14,
    White = 15,
    NavyBlue = 17,
    DarkBlue = 18,
    Blue3 = 20,
    DarkGreen = 22,
    DeepSkyBlue4 = 25,
    DodgerBlue3 = 26,
    DodgerBlue2 = 27,
    Green4 = 28,
    SpringGreen4 = 29,
    Turquoise4 = 30,
    DeepSkyBlue3 = 32,
    DodgerBlue1 = 33,
    Green3 = 40,
    SpringGreen3 = 41,
    DarkCyan = 36,
    LightSeaGreen = 37,
    DeepSkyBlue2 = 38,
    DeepSkyBlue1 = 39,
    SpringGreen2 = 47,
    Cyan3 = 43,
    DarkTurquoise = 44,
    Turquoise2 = 45,
    SpringGreen1 = 48,
    MediumSpringGreen = 49,
    Cyan2 = 50,
    DarkRed = 88,
    DeepPink4 = 125,
    Purple4 = 55,
    Purple3 = 56,
    BlueViolet = 57,
    Orange4 = 94,
    Grey37 = 59,
    MediumPurple4 = 60,
    SlateBlue3 = 62,
    RoyalBlue1 = 63,
    Chartreuse4 = 64,
    DarkSeaGreen4 = 71,
    PaleTurquoise4 = 66,
    SteelBlue = 67,
    SteelBlue3 = 68,
    CornflowerBlue = 69,
    Chartreuse3 = 76,
    CadetBlue = 73,
    SkyBlue3 = 74,
    SteelBlue1 = 81,
    PaleGreen3 = 114,
    SeaGreen3 = 78,
    Aquamarine3 = 79,
    MediumTurquoise = 80,
    Chartreuse2 = 112,
    SeaGreen2 = 83,
    SeaGreen1 = 85,
    Aquamarine1 = 122,
    DarkSlateGray2 = 87,
    DarkMagenta = 91,
    DarkViolet = 128,
    LightPink4 = 95,
    Plum4 = 96,
    MediumPurple3 = 98,
    SlateBlue1 = 99,
    Yellow4 = 106,
    Wheat4 = 101,
    Grey53 = 102,
    LightSlateGrey = 103,
    MediumPurple = 104,
    LightSlateBlue = 105,
    DarkOliveGreen3 = 149,
    DarkSeaGreen = 108,
    LightSkyBlue3 = 110,
    SkyBlue2 = 111,
    DarkSeaGreen3 = 150,
    DarkSlateGray3 = 116,
    SkyBlue1 = 117,
    Chartreuse1 = 118,
    LightGreen = 120,
    PaleGreen1 = 156,
    DarkSlateGray1 = 123,
    Red3 = 160,
    MediumVioletRed = 126,
    Magenta3 = 164,
    DarkOrange3 = 166,
    IndianRed = 167,
    HotPink3 = 168,
    MediumOrchid3 = 133,
    MediumOrchid = 134,
    MediumPurple2 = 140,
    DarkGoldenrod = 136,
    LightSalmon3 = 173,
    RosyBrown = 138,
    Grey63 = 139,
    MediumPurple1 = 141,
    Gold3 = 178,
    DarkKhaki = 143,
    NavajoWhite3 = 144,
    Grey69 = 145,
    LightSteelBlue3 = 146,
    LightSteelBlue = 147,
    Yellow3 = 184,
    DarkSeaGreen2 = 157,
    LightCyan3 = 152,
    LightSkyBlue1 = 153,
    GreenYellow = 154,
    DarkOliveGreen2 = 155,
    DarkSeaGreen1 = 193,
    PaleTurquoise1 = 159,
    DeepPink3 = 162,
    Magenta2 = 200,
    HotPink2 = 169,
    Orchid = 170,
    MediumOrchid1 = 207,
    Orange3 = 172,
    LightPink3 = 174,
    Pink3 = 175,
    Plum3 = 176,
    Violet = 177,
    LightGoldenrod3 = 179,
    Tan = 180,
    MistyRose3 = 181,
    Thistle3 = 182,
    Plum2 = 183,
    Khaki3 = 185,
    LightGoldenrod2 = 222,
    LightYellow3 = 187,
    Grey84 = 188,
    LightSteelBlue1 = 189,
    Yellow2 = 190,
    DarkOliveGreen1 = 192,
    Honeydew2 = 194,
    LightCyan1 = 195,
    DeepPink2 = 197,
    DeepPink1 = 199,
    OrangeRed1 = 202,
    IndianRed1 = 204,
    HotPink = 206,
    DarkOrange = 208,
    Salmon1 = 209,
    LightCoral = 210,
    PaleVioletRed1 = 211,
    Orchid2 = 212,
    Orchid1 = 213,
    Orange1 = 214,
    SandyBrown = 215,
    LightSalmon1 = 216,
    LightPink1 = 217,
    Pink1 = 218,
    Plum1 = 219,
    Gold1 = 220,
    NavajoWhite1 = 223,
    MistyRose1 = 224,
    Thistle1 = 225,
    LightGoldenrod1 = 227,
    Khaki1 = 228,
    Wheat1 = 229,
    Cornsilk1 = 230,
    Grey3 = 232,
    Grey7 = 233,
    Grey11 = 234,
    Grey15 = 235,
    Grey19 = 236,
    Grey23 = 237,
    Grey27 = 238,
    Grey30 = 239,
    Grey35 = 240,
    Grey39 = 241,
    Grey42 = 242,
    Grey46 = 243,
    Grey54 = 245,
    Grey58 = 246,
    Grey62 = 247,
    Grey66 = 248,
    Grey70 = 249,
    Grey74 = 250,
    Grey78 = 251,
    Grey82 = 252,
    Grey85 = 253,
    Grey89 = 254,
    Grey93 = 255,

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        return writer.print("8;5;{d}", .{@intFromEnum(self)});
    }
};

pub const Color = union(enum) {
    Black: void,
    Red: void,
    Green: void,
    Yellow: void,
    Blue: void,
    Magenta: void,
    Cyan: void,
    White: void,
    Default: void,

    RGB: std.meta.Tuple(&.{ u8, u8, u8 }),
    XTerm: XTerm,

    pub fn rgb(r: u8, g: u8, b: u8) @This() {
        return .{ .RGB = .{ r, g, b } };
    }

    pub fn xterm(xt: XTerm) @This() {
        return .{ .XTerm = xt };
    }

    pub fn format(value: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (value) {
            .Black => try writer.print("0", .{}),
            .Red => try writer.print("1", .{}),
            .Green => try writer.print("2", .{}),
            .Yellow => try writer.print("3", .{}),
            .Blue => try writer.print("4", .{}),
            .Magenta => try writer.print("5", .{}),
            .Cyan => try writer.print("6", .{}),
            .White => try writer.print("7", .{}),
            .Default => try writer.print("9", .{}),
            .RGB => |_rgb| {
                try writer.print("8;2;{d};{d};{d}", .{ _rgb[0], _rgb[1], _rgb[2] });
            },
            .XTerm => |_xterm| {
                try writer.print("8;5;{d}", .{@intFromEnum(_xterm)});
            },
        }
    }
};

pub const Style = struct {
    bold: bool = false,
    underline: bool = false,
    italic: bool = false,
    blink: bool = false,
    crossed: bool = false,
    reverse: bool = false,

    fg: ?Color = null,
    bg: ?Color = null,

    pub fn new() @This() {
        return .{};
    }

    pub fn bold() @This() {
        return .{ .bold = true };
    }

    pub fn crossed() @This() {
        return .{ .crossed = true };
    }

    pub fn italic() @This() {
        return .{ .italic = true };
    }

    pub fn underline() @This() {
        return .{ .underline = true };
    }

    pub fn blink() @This() {
        return .{ .blink = true };
    }

    pub fn reverse() @This() {
        return .{ .reverse = true };
    }

    pub fn fg(color: Color) @This() {
        return .{ .fg = color };
    }

    pub fn bg(color: Color) @This() {
        return .{ .bg = color };
    }

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        if (self.bold or self.italic or self.underline or self.blink or self.reverse or self.fg != null or self.bg != null) {
            var at_least_one = false;
            try writer.print("\x1b[", .{});

            if (self.bold) {
                try writer.print("{s}1", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.italic) {
                try writer.print("{s}3", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.crossed) {
                try writer.print("{s}9", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.underline) {
                try writer.print("{s}4", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.blink) {
                try writer.print("{s}5", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.reverse) {
                try writer.print("{s}7", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.fg) |_fg| {
                try writer.print("{s}3{s}", .{ if (at_least_one) ";" else "", _fg });
                at_least_one = true;
            }

            if (self.bg) |_bg| {
                try writer.print("{s}4{s}", .{ if (at_least_one) ";" else "", _bg });
                at_least_one = true;
            }
            try writer.print("m", .{});
        }
    }
};
