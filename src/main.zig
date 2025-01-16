const std = @import("std");
const termz = @import("termz");

const Screen = termz.action.Screen;
const Cursor = termz.action.Cursor;
const Line = termz.action.Line;
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
    try Screen.enable_raw_mode(.Stdout);
    errdefer _ = Screen.disable_raw_mode(.Stdout) catch { std.log.err("error disabling raw mode", .{}); };

    try execute(.Stdout, .{
        Screen.Save,
        Screen.EnterAlternateBuffer,
        Cursor { .col = 0, .row = 0 },
        "Press 'ctrl+c' to quit:\r\n"
    });

    while (true) {
        if (events.pollEvent()) {
            if (try events.parseEvent()) |event| {
                switch (event) {
                    .key_event => |ke| {
                        if (ke.key.eql(Key.char('c')) and ke.modifiers.ctrl) {
                            return;
                        }
                    },
                    else => {}
                }
            }
        }
    }

    try Screen.disable_raw_mode(.Stdout);

    try execute(.Stdout, .{
        // PERF: Experiment how this should behave, doesn't seem to work as expected
        Screen.LeaveAlternateBuffer,
        Screen.Restore,
    });
}
