const std = @import("std");
const zerm = @import("zerm");

const styled = zerm.style.styled;
const ifSupportsColor = zerm.style.ifSupportsColor;

const execute = zerm.execute;

pub fn main() !void {
    try execute(.stdout, .{
        styled("something\n", .{ .fg = .red }),
        ifSupportsColor(.stdout, "something\n", .{ .fg = .red })
    });
}
