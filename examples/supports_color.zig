const std = @import("std");
const termz = @import("termz");

const styled = termz.style.styled;
const ifSupportsColor = termz.style.ifSupportsColor;

const execute = termz.execute;

pub fn main() !void {
    try execute(.stdout, .{
        styled("something\n", .{ .fg = .red }),
        ifSupportsColor(.stdout, "something\n", .{ .fg = .red })
    });
}
