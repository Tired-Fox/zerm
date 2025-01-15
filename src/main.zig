const std = @import("std");
const termz = @import("termz");

const Screen = termz.action.Screen;
const Canvas = termz.action.Canvas;
const Cursor = termz.action.Cursor;
const Line = termz.action.Line;
const Style = termz.style.Style;
const Color = termz.style.Color;
const Reset = termz.style.Reset;

const execute = termz.execute;

pub fn main() !void {
    try execute(.Stdout, .{
        Screen.title("Hello World"),

        Style { .fg = Color.Red },
        "Hello, ",
        Reset.fg(),

        Canvas.SaveCursor,

        Style { .fg = Color.Magenta },
        "world!\n",
        Reset.fg(),

        Cursor { .shape = .block_blink }
    });

    std.time.sleep(3 * std.time.ns_per_s);

    try execute(.Stdout, .{
        Screen.title("Hello Everyone"),
        Canvas.RestoreCursor,
        Line.erase(.ToEnd),

        Style { .fg = Color.Yellow },
        "everyone!\n",
        Reset.fg(),

        Cursor { .shape = .block }
    });
}
