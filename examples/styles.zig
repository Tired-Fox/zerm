const std = @import("std");
const termz = @import("termz");

pub fn main() !void {
    const underline = termz.style.Style.underline();
    const bold = termz.style.Style.bold();

    std.debug.print("{any}", .{ underline.eql(&bold) });
}
