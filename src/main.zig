const std = @import("std");
const termz = @import("termz");

const Screen = termz.action.Screen;
const Cursor = termz.action.Cursor;
const Line = termz.action.Line;
const Capture = termz.action.Capture;
const Style = termz.style.Style;
const Color = termz.style.Color;
const Reset = termz.style.Reset;

const events = termz.events;
const Key = termz.events.Key;

const execute = termz.execute;

pub fn main() !void {
    try execute(.Stdout, .{
        Screen.title("Hello World"),

        Style { .fg = Color.Red },
        "Hello, ",
        Reset.fg(),

        Screen.SaveCursor,

        Style { .fg = Color.Magenta },
        "world!\n",
        Reset.fg(),

        Cursor { .shape = .block_blink }
    });

    std.time.sleep(3 * std.time.ns_per_s);

    try execute(.Stdout, .{
        Screen.title("Hello Everyone"),
        Screen.RestoreCursor,
        Line.erase(.ToEnd),

        Style { .fg = Color.Yellow },
        "everyone!\n",
        Reset.fg(),

        Cursor { .shape = .block }
    });

    // PERF: Broken on linux
    try Screen.enableRawMode();
    errdefer _ = Screen.disableRawMode() catch { std.log.err("error disabling raw mode", .{}); };

    try execute(.Stdout, .{
        Screen.EnterAlternateBuffer,
        Capture.EnableMouse,
        Capture.EnableFocus,
        Capture.EnableBracketedPaste,
        Cursor { .col = 5, .row = 5, .up = 2, .left = 2 },
        "Press 'ctrl+c' to quit:\r\n"
    });

    while (true) {
        if (events.pollEvent()) {
            if (try events.parseEvent()) |event| {
                std.log.debug("{any}", .{ event });
                switch (event) {
                    .key_event => |ke| {
                        if (ke.key.eql(Key.char('c')) and ke.modifiers.ctrl) {
                            break;
                        } else if (ke.key.eql(Key.char('q'))) {
                            break;
                        }
                    },
                    else => {}
                }
            }
        }
    }

    try execute(.Stdout, .{
        Capture.DisableMouse,
        Capture.DisableFocus,
        Capture.DisableBracketedPaste,
        Screen.LeaveAlternateBuffer,
    });

    try Screen.disableRawMode();
}
