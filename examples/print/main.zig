const std = @import("std");
const term = @import("term");

const Terminal = term.Terminal;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("Memory Leak");
    }

    var terminal = try Terminal.init();
    defer terminal.deinit();

    {
        std.debug.print("{any}\n", .{terminal.getSize()});
        try terminal.print("Hello, {s}!\n", .{"world"});
    }

    {
        try terminal.print("Write something: ", .{});
        const msg = try terminal.readLine(allocator);
        if (msg) |m| {
            defer allocator.free(m);
            try terminal.print("msg: {s}\n", .{m});
        }
    }

    {
        try terminal.print("Enter a character: ", .{});
        const char = try terminal.read();
        if (char) |c| {
            try terminal.print("char: {c}\n", .{c});
        }
    }
}
