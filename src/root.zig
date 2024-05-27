const std = @import("std");

pub const Terminal = @import("terminal.zig");

pub fn Pair(comptime _type1: type, comptime _type2: type) type {
    return std.meta.Tuple(&.{ _type1, _type2 });
}

pub const Size = Pair(u16, u16);
