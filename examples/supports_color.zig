const std = @import("std");
const termz = @import("termz");

const Style = termz.style.Style;
const Color = termz.style.Color;
const Reset = termz.style.Reset;
const styled = termz.style.styled;
const ifSupportsColor = termz.style.ifSupportsColor;

const Utf8ConsoleOutput = termz.Utf8ConsoleOutput;
const execute = termz.execute;

pub fn main() !void {
    // This is needed for windows since it wants utf16
    // but zig encodes it's output as utf8
    const utf8_ctx = Utf8ConsoleOutput.init();
    defer utf8_ctx.deinit();

    try execute(.Stdout, .{
        styled("something\n", .{ .fg = Color.Red }),
        ifSupportsColor(.Stdout, "something\n", .{ .fg = Color.Red })
    });
}
