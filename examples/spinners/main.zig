const std = @import("std");
const term = @import("term");

const Action = term.Action;
const Cursor = term.Cursor;
const Screen = term.Screen;
const rune = term.rune;
const Key = term.Key;

const Terminal = term.Terminal;

pub fn main() !void {
    var terminal = try Terminal.init();
    defer terminal.deinit();

    try terminal.enable_raw_mode();
    defer {
        terminal.disable_raw_mode() catch unreachable;
    }
    errdefer {
        terminal.disable_raw_mode() catch unreachable;
    }
    try terminal.print("Type 'q' or 'ctrl+c' to quit\r\n", .{});

    // const spinner = [_]u21{ '⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷' };

    // Framerate in nanoseconds
    // const framerate: f64 = 1.0 / 20.0;
    // var progress: f64 = 0.0;
    // var i: usize = 0;
    //
    // try terminal.execute(.{
    //     Action.SaveCursor,
    //     spinner[i],
    //     " Loading ...\r\n",
    // });
    //
    // var epoch: i128 = std.time.nanoTimestamp();
    while (true) {
        // const dt: f64 = @as(f64, @floatFromInt(std.time.nanoTimestamp() - epoch)) / 1_000_000_000.0;
        // progress += dt;
        // epoch = std.time.nanoTimestamp();
        //
        // if (progress >= framerate) {
        //     // TODO: update spinner and reset progress
        //     progress = 0.0;
        //     i = (i + 1) % spinner.len;
        //
        //     try terminal.execute(.{
        //         Action.RestoreCursor,
        //         spinner[i],
        //         " Loading ...\r\n",
        //     });
        // }

        if (terminal.hasEvent()) {
            const event = try terminal.readEvent();
            if (event) |e| {
                switch (e) {
                    .keyboard => |kb| {
                        std.debug.print("Key: {any}\r\n", .{kb.key});
                        if (Key.char('q').eql(kb.key) or (kb.modifiers.ctrl and Key.char('c').eql(kb.key))) {
                            break;
                        }
                    },
                    .mouse => |ms| {
                        std.debug.print("Mouse: {any}\r\n", .{ms});
                        if (ms.buttons.left and ms.modifiers.shift and ms.event == .Click) {
                            std.debug.print("Left Click\r\n", .{});
                        }
                    },
                    else => {},
                }
            }
        }
    }
}
