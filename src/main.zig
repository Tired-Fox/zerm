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

    const frames = [_]u21{ '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' };
    for (0..3) |_| {
        for (0..frames.len) |i| {
            try execute(.Stdout, .{
                "\r",
                Style { .fg = Color.Yellow },
                frames[i],
                Reset.fg(),
                " Loading..."
            });
            std.time.sleep(80 * std.time.ns_per_ms);
        }
    }

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

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    while (true) {
        if (events.pollEvent()) {
            if (try events.parseEvent(alloc)) |event| {
                switch (event) {
                    .key_event => |ke| {
                        std.log.debug("{any}", .{ ke });
                        if (ke.key.eql(Key.char('c')) and ke.modifiers.ctrl) {
                            break;
                        } else if (ke.key.eql(Key.char('q'))) {
                            break;
                        }
                    },
                    .mouse_event => |me| {
                        std.log.debug("{any}", .{ me });
                    },
                    .paste_event => |content| {
                        defer alloc.free(content);
                        std.log.debug("{s}", .{content});
                    },
                    else => {
                        std.log.debug("{any}", .{ event });
                    }
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
