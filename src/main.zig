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
        std.debug.print("{any}", .{terminal.kbhit()});
        const char = try terminal.read();
        if (char) |c| {
            try terminal.print("char: {c}\n", .{c});
        }
        std.debug.print("{any}", .{terminal.kbhit()});
    }

    try terminal.context.enter();
    defer terminal.context.exit();

    {
        try terminal.print("\x1b[s\x1b[9999;9999H\x1b[6n\x1b[u", .{});
        const result = try terminal.readUntil(allocator, 'R');
        if (result) |r| {
            defer allocator.free(r);
            std.debug.print("RESPONSE: ", .{});
            for (r) |c| {
                switch (c) {
                    27 => std.debug.print("␛", .{}),
                    7 => std.debug.print("\\a", .{}),
                    8 => std.debug.print("\\b", .{}),
                    9 => std.debug.print("\\t", .{}),
                    10 => std.debug.print("\\n", .{}),
                    11 => std.debug.print("\\v", .{}),
                    12 => std.debug.print("\\f", .{}),
                    13 => std.debug.print("\\r", .{}),
                    else => |v| {
                        std.debug.print("{c}", .{v});
                    },
                }
            }
            std.debug.print("\n", .{});
        }
    }

    std.debug.print("q/ctrl+c to quit\n\n", .{});
    while (true) {
        if (terminal.kbhit()) {
            var char = (try terminal.read()).?;
            if (char == 'q') {
                break;
            } else if (char == '\r') {
                char = '\n';
            } else if (char == 3) {
                std.debug.print("\nctrl+c\n", .{});
                break;
            }
            std.debug.print("{c}", .{char});
        }
    }
}
