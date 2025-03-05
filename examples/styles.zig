const std = @import("std");
const termz = @import("termz");

const Style = termz.style.Style;
const Modifiers = termz.style.Modifiers;
const Reset = termz.style.Reset;
const Color = termz.style.Color;

pub fn main() !void {
    const style = Style { .mod = .{ .underline = .double, .overline = true } };
    std.debug.print("\x1b[51mHello, world\x1b[0m", .{
        style
    });
}
