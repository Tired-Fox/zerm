const std = @import("std");
const term = @import("term");

const Terminal = term.Terminal;

pub fn main() !void {
    var terminal = try Terminal.init();
    defer terminal.deinit();

    {
        try terminal.enable_raw_mode();
        // In case of unhandled error reset terminal to not be in raw mode
        errdefer terminal.disable_raw_mode() catch unreachable;
        try terminal.print("{any}\n", .{try terminal.cursorPos()});
        for (0..5) |_| {
            const result = terminal.cursorPos() catch {
                try terminal.print("Failed to get cursor position\n", .{});
                continue;
            };
            try terminal.print("RESULTS FOUND {any}\n", .{result});
            std.time.sleep(1 * std.time.ns_per_s);
        }
        try terminal.disable_raw_mode();
    }
}
