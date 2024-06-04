const std = @import("std");
const term = @import("term");

const Style = term.Style;
const Color = term.Color;

const Terminal = term.Terminal;

pub fn main() !void {
    var terminal = try Terminal.init();
    defer terminal.deinit();

    {
        try terminal.print("{s}Hello, world!\x1b[0m\n", .{Style{
            .bold = true,
            .italic = true,
            .crossed = true,
            .underline = true,
            .reverse = true,
        }});

        try terminal.print("{s}Hello, world!\x1b[0m\n", .{Style{
            .fg = .Red,
            .bg = .Yellow,
        }});

        try terminal.print("{s}Hello, world!\x1b[0m\n", .{Style{
            .fg = Color.rgb(255, 0, 255),
            .bg = Color.xterm(.Black),
        }});
    }
}
