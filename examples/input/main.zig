const std = @import("std");
const term = @import("term");

const Action = term.Action;
const Cursor = term.Cursor;
const Screen = term.Screen;
const Style = term.Style;
const Color = term.Color;
const rune = term.rune;

const Terminal = term.Terminal;

pub fn main() !void {
    var terminal = try Terminal.init();
    defer terminal.deinit();

    {
        try terminal.enable_raw_mode();
        // Reset the terminal in case it was left in a weird state
        errdefer terminal.disable_raw_mode() catch unreachable;
        try terminal.print("q/ctrl+c to quit\n\n", .{});
        while (true) {
            if (terminal.kbhit()) {
                var char = (try terminal.read()).?;
                if (char == 'q') {
                    break;
                } else if (char == '\r') {
                    char = '\n';
                } else if (char == 3) {
                    try terminal.print("\nctrl+c\n", .{});
                    break;
                }
                try terminal.print("{c}", .{char});
            }
        }
        try terminal.disable_raw_mode();
    }
}
