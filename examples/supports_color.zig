const std = @import("std");
const termz = @import("termz");

const Color = termz.style.Color;
const styled = termz.style.styled;
const ifSupportsColor = termz.style.ifSupportsColor;

const execute = termz.execute;

pub fn main() !void {
    try execute(.Stdout, .{
        styled("something\n", .{ .fg = Color.Red }),
        ifSupportsColor(.Stdout, "something\n", .{ .fg = Color.Red })
    });
}
