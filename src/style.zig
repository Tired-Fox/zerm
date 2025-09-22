const std = @import("std");
const Stream = @import("root.zig").Stream;
const writeOp = @import("root.zig").writeOp;
const onCached = @import("tty.zig").onCached;

/// XTerm named colors
pub const XTerm = enum(u8) {
    black = 0,
    maroon = 1,
    green = 2,
    olive = 3,
    navy = 4,
    purple = 129,
    teal = 6,
    silver = 7,
    grey = 8,
    red = 9,
    lime = 10,
    yellow = 11,
    blue = 12,
    fuchsia = 13,
    aqua = 14,
    white = 15,
    navy_blue = 17,
    dark_blue = 18,
    blue_3 = 20,
    dark_green = 22,
    deep_sky_blue_4 = 25,
    dodger_blue_3 = 26,
    dodger_blue_2 = 27,
    green_4 = 28,
    spring_green_4 = 29,
    turquoise_4 = 30,
    deep_sky_blue_3 = 32,
    dodger_blue_1 = 33,
    green_3 = 40,
    spring_green_3 = 41,
    dark_cyan = 36,
    light_sea_green = 37,
    deep_sky_blue_2 = 38,
    deep_sky_blue_1 = 39,
    spring_green_2 = 47,
    cyan_3 = 43,
    dark_turquoise = 44,
    turquoise_2 = 45,
    spring_green_1 = 48,
    medium_spring_green = 49,
    cyan_2 = 50,
    dark_red = 88,
    deep_pink_4 = 125,
    purple_4 = 55,
    purple_3 = 56,
    blue_violet = 57,
    orange_4 = 94,
    grey_37 = 59,
    medium_purple_4 = 60,
    slate_blue_3 = 62,
    royal_blue_1 = 63,
    chartreuse_4 = 64,
    dark_sea_green_4 = 71,
    pale_turquoise_4 = 66,
    steel_blue = 67,
    steel_blue_3 = 68,
    cornflower_blue = 69,
    chartreuse_3 = 76,
    cadet_blue = 73,
    sky_blue_3 = 74,
    steel_blue_1 = 81,
    pale_green_3 = 114,
    sea_green_3 = 78,
    aquamarine_3 = 79,
    medium_turquoise = 80,
    chartreuse_2 = 112,
    sea_green_2 = 83,
    sea_green_1 = 85,
    aquamarine_1 = 122,
    dark_slate_gray_2 = 87,
    dark_magenta = 91,
    dark_violet = 128,
    light_pink_4 = 95,
    plum_4 = 96,
    medium_purple_3 = 98,
    slate_blue_1 = 99,
    yellow_4 = 106,
    wheat_4 = 101,
    grey_53 = 102,
    light_slate_grey = 103,
    medium_purple = 104,
    light_slate_blue = 105,
    dark_olive_green_3 = 149,
    dark_sea_green = 108,
    light_sky_blue_3 = 110,
    sky_blue_2 = 111,
    dark_sea_green_3 = 150,
    dark_slate_gray_3 = 116,
    sky_blue_1 = 117,
    chartreuse_1 = 118,
    light_green = 120,
    pale_green_1 = 156,
    dark_slate_gray_1 = 123,
    red_3 = 160,
    medium_violet_red = 126,
    magenta_3 = 164,
    dark_orange_3 = 166,
    indian_red = 167,
    hot_pink_3 = 168,
    medium_orchid_3 = 133,
    medium_orchid = 134,
    medium_purple_2 = 140,
    dark_goldenrod = 136,
    light_salmon_3 = 173,
    rosy_brown = 138,
    grey_63 = 139,
    medium_purple_1 = 141,
    gold_3 = 178,
    dark_khaki = 143,
    navajo_white_3 = 144,
    grey_69 = 145,
    light_steel_blue_3 = 146,
    light_steel_blue = 147,
    yellow_3 = 184,
    dark_sea_green_2 = 157,
    light_cyan_3 = 152,
    light_sky_blue_1 = 153,
    green_yellow = 154,
    dark_olive_green_2 = 155,
    dark_sea_green_1 = 193,
    pale_turquoise_1 = 159,
    deep_pink_3 = 162,
    magenta_2 = 200,
    hot_pink_2 = 169,
    orchid = 170,
    medium_orchid_1 = 207,
    orange_3 = 172,
    light_pink_3 = 174,
    pink_3 = 175,
    plum_3 = 176,
    violet = 177,
    light_goldenrod_3 = 179,
    tan = 180,
    misty_rose_3 = 181,
    thistle_3 = 182,
    plum_2 = 183,
    khaki_3 = 185,
    light_goldenrod_2 = 222,
    light_yellow_3 = 187,
    grey_84 = 188,
    light_steel_blue_1 = 189,
    yellow_2 = 190,
    dark_olive_green_1 = 192,
    honeydew_2 = 194,
    light_cyan_1 = 195,
    deep_pink_2 = 197,
    deep_pink_1 = 199,
    orange_red_1 = 202,
    indian_red_1 = 204,
    hot_pink = 206,
    dark_orange = 208,
    salmon_1 = 209,
    light_coral = 210,
    pale_violet_red_1 = 211,
    orchid_2 = 212,
    orchid_1 = 213,
    orange_1 = 214,
    sandy_brown = 215,
    light_salmon_1 = 216,
    light_pink_1 = 217,
    pink_1 = 218,
    plum_1 = 219,
    gold_1 = 220,
    navajo_white_1 = 223,
    misty_rose_1 = 224,
    thistle_1 = 225,
    light_goldenrod_1 = 227,
    khaki_1 = 228,
    wheat_1 = 229,
    cornsilk_1 = 230,
    grey_3 = 232,
    grey_7 = 233,
    grey_11 = 234,
    grey_15 = 235,
    grey_19 = 236,
    grey_23 = 237,
    grey_27 = 238,
    grey_30 = 239,
    grey_35 = 240,
    grey_39 = 241,
    grey_42 = 242,
    grey_46 = 243,
    grey_54 = 245,
    grey_58 = 246,
    grey_62 = 247,
    grey_66 = 248,
    grey_70 = 249,
    grey_74 = 250,
    grey_78 = 251,
    grey_82 = 252,
    grey_85 = 253,
    grey_89 = 254,
    grey_93 = 255,
};

/// Ansi Color Representation
pub const Color = union(enum) {
    pub const black: @This() = .{ .system_black = {} };
    pub const red: @This() = .{ .system_red = {} };
    pub const green: @This() = .{ .system_green = {} };
    pub const yellow: @This() = .{ .system_yellow = {} };
    pub const blue: @This() = .{ .system_blue = {} };
    pub const magenta: @This() = .{ .system_magenta = {} };
    pub const cyan: @This() = .{ .system_cyan = {} };
    pub const white: @This() = .{ .system_white = {} };
    pub const default: @This() = .{ .system_default = {} };

    /// System `black`
    system_black: void,
    /// System `red`
    system_red: void,
    /// System `green`
    system_green: void,
    /// System `yellow`
    system_yellow: void,
    /// System `blue`
    system_blue: void,
    /// System `magenta`
    system_magenta: void,
    /// System `cyan`
    system_cyan: void,
    /// System `white`
    system_white: void,
    system_default: void,

    ansi_rgb: std.meta.Tuple(&.{ u8, u8, u8 }),
    ansi_xterm: XTerm,

    pub fn rgb(r: u8, g: u8, b: u8) @This() {
        return .{ .ansi_rgb = .{ r, g, b } };
    }

    pub fn xterm(xt: XTerm) @This() {
        return .{ .ansi_xterm = xt };
    }

    pub fn format(self: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
        switch (self) {
            .system_black => try writer.print("0", .{}),
            .system_red => try writer.print("1", .{}),
            .system_green => try writer.print("2", .{}),
            .system_yellow => try writer.print("3", .{}),
            .system_blue => try writer.print("4", .{}),
            .system_magenta => try writer.print("5", .{}),
            .system_cyan => try writer.print("6", .{}),
            .system_white => try writer.print("7", .{}),
            .system_default => try writer.print("9", .{}),
            .ansi_rgb => |_rgb| {
                try writer.print("8;2;{d};{d};{d}", .{ _rgb[0], _rgb[1], _rgb[2] });
            },
            .ansi_xterm => |_xterm| {
                try writer.print("8;5;{d}", .{@intFromEnum(_xterm)});
            },
        }
    }
};

pub const Modifiers = packed struct(u8) {
    bold: bool = false,
    /// Either `single` or `double`
    underline: Underline = .none,
    overline: bool = false,
    italic: bool = false,
    blink: bool = false,
    /// Strikethrough
    crossed: bool = false,
    /// Swap foreground and background colors
    reverse: bool = false,

    pub const empty: @This() = .{};

    pub const Underline = enum(u2) {
        none = 0,
        single = 1,
        double = 2,
    };

    pub fn from(value: u8) @This() {
        return @bitCast(value);
    }

    pub fn bits(self: *const @This()) u8 {
        return @bitCast(self.*);
    }
};

/// Styling for ansi text
pub const Style = struct {
    /// Text modifier like `bold`, `italic`, etc.
    mod: Modifiers = .{},
    /// Foreground color
    fg: ?Color = null,
    /// Background color
    bg: ?Color = null,
    /// Underline color
    ///
    /// This is mostly supported but non `Windows` terminals
    underline_color: ?Color = null,

    /// Apply a clickable hyperlink
    hyperlink: ?[]const u8 = null,

    pub fn eql(self: *const @This(), other: *const @This()) bool {
        return self.mod == other.mod
            and std.meta.eql(self.fg, other.fg)
            and std.meta.eql(self.bg, other.bg)
            and std.meta.eql(self.underline_color, other.underline_color)
            and if (self.hyperlink != null and other.hyperlink != null) std.mem.eql(u8, self.hyperlink.?, other.hyperlink.?) else false;
    }

    pub const empty: @This() = .{};
    pub const bold: @This() = .{ .mod = .{ .bold = true } };
    pub const crossed: @This() = .{ .mod = .{ .crossed = true } };
    pub const italic: @This() = .{ .mod = .{ .italic = true } };
    pub const overline: @This() = .{ .mod = .{ .overline = true } };
    pub const blink: @This() = .{ .mod = .{ .blink = true } };
    pub const reverse: @This() = .{ .mod = .{ .reverse = true } };

    pub fn underline(kind: Modifiers.Underline) @This() {
        return .{ .mod = .{ .underline = kind }};
    }

    /// Generate the representation that will reset the styling
    pub fn reset(self: @This()) Reset {
        return .{
            .mod = self.mod,
            .fg = self.fg != null,
            .bg = self.bg != null,
            .underline_color = self.underline_color != null,
            .hyperlink = self.hyperlink != null,
        };
    }

    /// Merge two styles together where `other` will **NOT** replace `self`
    /// where the values overlap.
    pub fn merge(self: *const @This(), other: *const @This()) Style {
        return . {
            .mod = .from(self.mod.bits() | other.mod.bits()),
            .fg = self.fg orelse other.fg,
            .bg = self.bg orelse other.bg, 
            .underline_color = self.underline_color orelse other.underline_color,
            .hyperlink = self.hyperlink orelse other.hyperlink,
        };
    }

    pub fn format(self: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
        if (self.mod != Modifiers.empty or self.fg != null or self.bg != null) {
            var at_least_one = false;
            try writer.print("\x1b[", .{});

            if (self.mod.bold) {
                try writer.print("{s}1", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.mod.italic) {
                try writer.print("{s}3", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.mod.crossed) {
                try writer.print("{s}9", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            switch (self.mod.underline) {
                .single => {
                    try writer.print("{s}4", .{if (at_least_one) ";" else ""});
                    at_least_one = true;
                },
                .double => {
                    try writer.print("{s}21", .{if (at_least_one) ";" else ""});
                    at_least_one = true;
                },
                else => {}
            }

            if (self.mod.overline) {
                try writer.print("{s}53", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.mod.blink) {
                try writer.print("{s}5", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.mod.reverse) {
                try writer.print("{s}7", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.underline_color) |_uc| {
                if (at_least_one) try writer.print(";", .{});
                switch (_uc) {
                    .system_black => try writer.print("58;5;0", .{}),
                    .system_red => try writer.print("58;5;1", .{}),
                    .system_green => try writer.print("58;5;2", .{}),
                    .system_yellow => try writer.print("58;5;3", .{}),
                    .system_blue => try writer.print("58;5;4", .{}),
                    .system_magenta => try writer.print("58;5;5", .{}),
                    .system_cyan => try writer.print("58;5;6", .{}),
                    .system_white => try writer.print("58;5;7", .{}),
                    .system_default => try writer.print("59", .{}),
                    .ansi_xterm => |xterm| try writer.print("58;5;{d}", .{ @intFromEnum(xterm) }),
                    .ansi_rgb => |rgb| try writer.print("58;2;{d};{d};{d}", .{ rgb[0], rgb[1], rgb[2] }),
                }
                at_least_one = true;
            }

            if (self.fg) |_fg| {
                try writer.print("{s}3{f}", .{ if (at_least_one) ";" else "", _fg });
                at_least_one = true;
            }

            if (self.bg) |_bg| {
                try writer.print("{s}4{f}", .{ if (at_least_one) ";" else "", _bg });
                at_least_one = true;
            }
            try writer.print("m", .{});
        }

        if (self.hyperlink) |_hl| {
            try writer.print("\x1b]8;;{s}\x1b\\", .{ _hl });
        }
    }
};

/// Representation of sequences to reset ansi styling
pub const Reset = struct {
    mod: Modifiers = .{},
    fg: bool = false,
    bg: bool = false,
    underline_color: bool = false,
    hyperlink: bool = false,

    pub const empty: @This() = .{};
    pub const bold: @This() = .{ .mod = .{ .bold = true } };
    pub const crossed: @This() = .{ .mod = .{ .crossed = true } };
    pub const italic: @This() = .{ .mod = .{ .italic = true } };
    pub const overline: @This() = .{ .mod = .{ .overline = true } };
    pub const underline: @This() = .{ .mod = .{ .underline = true } };
    pub const blink: @This() = .{ .mod = .{ .blink = true } };
    pub const reverse: @This() = .{ .mod = .{ .reverse = true } };

    pub fn format(self: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
        if (self.mod != Modifiers.empty or self.fg or self.bg or self.underline_color) {
            var at_least_one = false;
            try writer.print("\x1b[", .{});

            if (self.mod.bold) {
                try writer.print("{s}22", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.mod.italic) {
                try writer.print("{s}23", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.mod.crossed) {
                try writer.print("{s}29", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.mod.underline != .none) {
                try writer.print("{s}24", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.mod.overline) {
                try writer.print("{s}55", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.mod.blink) {
                try writer.print("{s}25", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.mod.reverse) {
                try writer.print("{s}27", .{if (at_least_one) ";" else ""});
                at_least_one = true;
            }

            if (self.underline_color) {
                try writer.print("{s}59", .{ if (at_least_one) ";" else "" });
                at_least_one = true;
            }

            if (self.fg) {
                try writer.print("{s}39", .{ if (at_least_one) ";" else "" });
                at_least_one = true;
            }

            if (self.bg) {
                try writer.print("{s}49", .{ if (at_least_one) ";" else "" });
                at_least_one = true;
            }
            try writer.print("m", .{});
        }

        if (self.hyperlink) {
            try writer.print("\x1b]8;;\x1b\\", .{});
        }
    }
};

/// Wrapper around a writtable operator (command) to apply a style
///
/// Supported types:
///     - `[]const u8`
///     - `u8`, `u21`, `u32`, `comptime_int`
///     - Any type that implements `format` to be use with the string formatter
pub fn Styled(T: type) type {
    return struct{
        value: T,
        style: Style,

        pub fn init(value: T, style: Style) @This() {
            return .{
                .value = value,
                .style = style,
            };
        }

        pub fn format(self: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
            try writer.print("{f}", .{ self.style });
            try writeOp(self.value, writer);
            try writer.print("{f}", .{ self.style.reset() });
        }
    };
}

/// Create a styled writtable operator
///
/// Supported types:
///     - `[]const u8`
///     - `u8`, `u21`, `u32`, `comptime_int`
///     - Any type that implements `format` to be use with the string formatter
pub fn styled(value: anytype, style: Style) Styled(@TypeOf(value)) {
    return .{
        .value = value,
        .style = style,
    };
}

/// Wrapper around a writtable operator (command) to apply a style
/// only if the terminal supports color output
///
/// Supported types:
///     - `[]const u8`
///     - `u8`, `u21`, `u32`, `comptime_int`
///     - Any type that implements `format` to be use with the string formatter
pub fn SupportsColor(T: type) type {
    return struct{
        value: T,
        stream: Stream,
        style: Style,

        pub fn init(stream: Stream, value: T, style: Style) @This() {
            return .{
                .value = value,
                .style = style,
                .stream = stream,
            };
        }

        pub fn format(self: @This(), writer: *std.io.Writer) std.io.Writer.Error!void {
            if (onCached(self.stream)) |cached| {
                if (cached.has_basic) {
                    try writer.print("{f}", .{ self.style });
                    try writeOp(self.value, writer);
                    try writer.print("{f}", .{ self.style.reset() });
                    return;
                }
            }

            try writeOp(self.value, writer);
        }
    };
}

/// Create a writtable operator that styles it's content only if
/// the terminal supports color
///
/// Supported types:
///     - `[]const u8`
///     - `u8`, `u21`, `u32`, `comptime_int`
///     - Any type that implements `format` to be use with the string formatter
pub fn ifSupportsColor(stream: Stream, value: anytype, style: Style) SupportsColor(@TypeOf(value)) {
    return .{
        .value = value,
        .style = style,
        .stream = stream,
    };
}

test "style::Color::format" {
    var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Color.Black });
    try std.testing.expect(std.mem.eql(u8, format, "0"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Color.rgb(255, 10, 180) });
    try std.testing.expect(std.mem.eql(u8, format, "8;2;255;10;180"));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Color.xterm(.Aqua) });
    try std.testing.expect(std.mem.eql(u8, format, "8;5;14"));
    std.testing.allocator.free(format);
}

test "style::Style::format" {
    var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Style {} });
    try std.testing.expect(std.mem.eql(u8, format, ""));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Style {
        .bold = true,
        .italic = true,
        .crossed = true,
        .underline = true,
        .blink = true,
        .reverse = true,
        .fg = Color.Red,
        .bg = Color.Blue,
        .hyperlink = "https://example.com"
    } });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[1;3;9;4;5;7;31;44m\x1b]8;;https://example.com\x1b\\"));
    std.testing.allocator.free(format);
}

test "style::Reset::format" {
    var format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Reset {} });
    try std.testing.expect(std.mem.eql(u8, format, ""));
    std.testing.allocator.free(format);

    format = try std.fmt.allocPrint(std.testing.allocator, "{}", .{ Reset {
        .bold = true,
        .italic = true,
        .crossed = true,
        .underline = true,
        .blink = true,
        .reverse = true,
        .fg = true,
        .bg = true,
    } });
    try std.testing.expect(std.mem.eql(u8, format, "\x1b[22;23;29;24;25;27;39;49m"));
    std.testing.allocator.free(format);
}
