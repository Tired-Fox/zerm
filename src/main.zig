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

    var terminal = try Terminal.init(allocator);
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

    {
        try terminal.enable_raw_mode();
        for (0..10) |_| {
            const result = try terminal.cursorPos();
            std.debug.print("RESULTS FOUND {any}\n", .{result});
        }
        terminal.disable_raw_mode();
    }

    {
        try terminal.enable_raw_mode();
        // errdefer terminal.disable_raw_mode();
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
        terminal.disable_raw_mode();
    }
}
