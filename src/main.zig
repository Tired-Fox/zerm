const std = @import("std");
const term = @import("root.zig");

const Action = term.Action;
const Cursor = term.Cursor;
const Screen = term.Screen;
const Style = term.Style;
const Color = term.Color;
const rune = term.rune;

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

    // {
    //     try terminal.enable_raw_mode();
    //     for (0..5) |_| {
    //         const result = try terminal.cursorPos();
    //         try terminal.print("RESULTS FOUND {any}\n", .{result});
    //         std.time.sleep(1 * std.time.ns_per_s);
    //     }
    //     try terminal.disable_raw_mode();
    // }
    //
    // {
    //     try terminal.enable_raw_mode();
    //     // errdefer terminal.disable_raw_mode();
    //     try terminal.print("q/ctrl+c to quit\n\n", .{});
    //     while (true) {
    //         if (terminal.kbhit()) {
    //             var char = (try terminal.read()).?;
    //             if (char == 'q') {
    //                 break;
    //             } else if (char == '\r') {
    //                 char = '\n';
    //             } else if (char == 3) {
    //                 try terminal.print("\nctrl+c\n", .{});
    //                 break;
    //             }
    //             try terminal.print("{c}", .{char});
    //         }
    //     }
    //     try terminal.disable_raw_mode();
    // }
    //
    // {
    //     try terminal.execute(.{
    //         Screen.title("Example Actions"),
    //     });
    //
    //     try terminal.execute(.{
    //         Cursor.up(2),
    //         Cursor.x(1),
    //         "Hello               ",
    //         Cursor.x(1),
    //         Cursor.down(2),
    //     });
    //     std.time.sleep(3 * std.time.ns_per_s);
    //     try terminal.execute(.{
    //         Cursor{ .up = 2, .x = 1 },
    //         "World               ",
    //         Cursor{ .down = 2, .x = 1 },
    //     });
    //
    //     try terminal.execute(.{Action.SaveCursor});
    //
    //     const spinner = [_]u21{ '⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷' };
    //     var i: usize = 0;
    //     try terminal.print("{s} Loading...", .{rune(spinner[0])});
    //
    //     // while (true) {
    //     for (0..spinner.len * 10) |_| {
    //         std.time.sleep(std.time.ns_per_s / 20);
    //         i = (i + 1) % spinner.len;
    //         try terminal.execute(.{
    //             Action.RestoreCursor,
    //             spinner[i],
    //             " Loading...",
    //         });
    //     }
    //     try terminal.print("\n", .{});
    //
    //     try terminal.execute(.{
    //         Cursor.blink(true),
    //         Cursor.block(true),
    //     });
    //
    //     std.time.sleep(3 * std.time.ns_per_s);
    //
    //     try terminal.execute(.{
    //         Cursor.user(),
    //         Cursor.blink(false),
    //     });
    //
    //     try terminal.execute(.{
    //         Action.SaveCursor,
    //         "→ Clearing in 3 ...",
    //     });
    //     std.time.sleep(1 * std.time.ns_per_s);
    //     try terminal.execute(.{
    //         Action.RestoreCursor,
    //         "→ Clearing in 2 ...",
    //     });
    //     std.time.sleep(1 * std.time.ns_per_s);
    //     try terminal.execute(.{
    //         Action.RestoreCursor,
    //         "→ Clearing in 1 ...",
    //     });
    //     std.time.sleep(1 * std.time.ns_per_s);
    //     try terminal.execute(.{
    //         Cursor.pos(0, 0),
    //         Screen.erase(.All),
    //         Screen.soft_reset(),
    //     });
    // }

    {
        try terminal.print("{s}Hello, world!\x1b[0m\n", .{Style{ .bold = true, .italic = true, .crossed = true, .underline = true, .reverse = true }});
        try terminal.print("{s}Hello, world!\x1b[0m\n", .{Style{ .fg = .Red, .bg = .Yellow }});
        try terminal.print("{s}Hello, world!\x1b[0m\n", .{Style{ .fg = Color.rgb(255, 0, 255), .bg = Color.xterm(.Black) }});
    }
}
