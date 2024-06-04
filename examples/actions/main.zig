const std = @import("std");
const term = @import("term");

const Action = term.Action;
const Cursor = term.Cursor;
const Screen = term.Screen;
const rune = term.rune;

const Terminal = term.Terminal;

pub fn main() !void {
    var terminal = try Terminal.init();
    defer terminal.deinit();

    {
        try terminal.execute(.{
            Screen.title("Example Actions"),
        });

        try terminal.execute(.{
            Cursor.up(2),
            Cursor.x(1),
            "Hello               ",
            Cursor.x(1),
            Cursor.down(2),
        });
        std.time.sleep(3 * std.time.ns_per_s);
        try terminal.execute(.{
            Cursor{ .up = 2, .x = 1 },
            "World               ",
            Cursor{ .down = 2, .x = 1 },
        });

        try terminal.execute(.{Action.SaveCursor});

        const spinner = [_]u21{ '⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷' };
        var i: usize = 0;
        try terminal.print("{s} Loading...", .{rune(spinner[0])});

        // while (true) {
        for (0..spinner.len * 10) |_| {
            std.time.sleep(std.time.ns_per_s / 20);
            i = (i + 1) % spinner.len;
            try terminal.execute(.{
                Action.RestoreCursor,
                spinner[i],
                " Loading...",
            });
        }
        try terminal.print("\n", .{});

        try terminal.execute(.{
            Cursor.blink(true),
            Cursor.block(true),
        });

        std.time.sleep(3 * std.time.ns_per_s);

        try terminal.execute(.{
            Cursor.user(),
            Cursor.blink(false),
        });

        try terminal.execute(.{
            Action.SaveCursor,
            "→ Clearing in 3 ...",
        });
        std.time.sleep(1 * std.time.ns_per_s);
        try terminal.execute(.{
            Action.RestoreCursor,
            "→ Clearing in 2 ...",
        });
        std.time.sleep(1 * std.time.ns_per_s);
        try terminal.execute(.{
            Action.RestoreCursor,
            "→ Clearing in 1 ...",
        });
        std.time.sleep(1 * std.time.ns_per_s);
        try terminal.execute(.{
            Cursor.pos(0, 0),
            Screen.erase(.All),
            Screen.soft_reset(),
        });
    }
}
