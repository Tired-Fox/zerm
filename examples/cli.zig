const std = @import("std");
const zerm = @import("zerm");

const Screen = zerm.action.Screen;
const Cursor = zerm.action.Cursor;
const getTermSize = zerm.action.getTermSize;
const getCursorPos = zerm.action.getCursorPos;
const Line = zerm.action.Line;
const Capture = zerm.action.Capture;
const Style = zerm.style.Style;
const Reset = zerm.style.Reset;

const Utf8ConsoleOutput = zerm.Utf8ConsoleOutput;

const EventStream = zerm.event.EventStream;

const execute = zerm.execute;

pub fn main() !void {
    // This is needed for windows since it wants utf16
    //
    // This is only needed if you are printing non ascii directly
    // to stdout or stderr.
    //
    // The execute and queue flows already handle this and converts the utf8
    // to utf16 using a buffer and chunking the output to avoid allocations.
    // However this could cause multiple writes if the output is large enough.
    //
    // const utf8_ctx = Utf8ConsoleOutput.init();
    // defer utf8_ctx.deinit();

    try execute(.stdout, .{
        Screen{ .title = "Hello World" },
        Style { .fg = .red },
        "Hello, ",
        Reset { .fg = true },

        Cursor { .save = true  },
        Style { .fg = .magenta },
        "world!\n",
        Reset { .fg = true },

        Cursor { .shape = .block_blink }
    });

    const frames = [_]u21{ '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' };
    for (0..3) |_| {
        for (0..frames.len) |i| {
            try execute(.stdout, .{
                "\r",
                Style { .fg = .yellow },
                frames[i],
                Reset { .fg = true },
                " Loading..."
            });
            std.Thread.sleep(80 * std.time.ns_per_ms);
        }
    }

    try execute(.stdout, .{
        Line{ .erase = .from_beginning },
        '\r',
        Style { .fg = .green },
        '✓',
        Reset { .fg = true },
        " Success\n"
    });

    try execute(.stdout, .{
        Screen { .title = "Hello Everyone" },

        Cursor { .restore = true  },
        Line { .erase = .to_end },

        Style { .fg = .yellow },
        "everyone!",
        Reset { .fg = true },
        Cursor { .shape = .block, .down = 2, .col = 1 }
    });

    try Screen.enableRawMode();
    errdefer _ = Screen.disableRawMode() catch { std.log.err("error disabling raw mode", .{}); };

    try execute(.stdout, .{
        Screen.enter_alternate_buffer,
        Capture.enable_mouse,
        Capture.enable_focus,
        Capture.enable_bracketed_paste,
        Cursor { .col = 5, .row = 5, .up = 2, .left = 2 },
        "Press 'ctrl+c' to quit:\r\n"
    });

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var stream = EventStream.init(arena.allocator());
    defer stream.deinit();

    while (true) {
        if (try stream.parseEvent()) |evt| {
            switch (evt) {
                .key => |ke| {
                    std.log.debug("{any}\r", .{ ke });
                    if (ke.matches(&.{
                        .{ .code = .char('c'), .ctrl = true },
                        .{ .code = .char('q') },
                    })) break;
                },
                .mouse => |me| {
                    std.log.debug("{any}\r", .{ me });
                },
                else => {
                    std.log.debug("{any}\r", .{ evt });
                }
            }
        }
    }

    try execute(.stdout, .{
        Capture.disable_mouse,
        Capture.disable_focus,
        Capture.disable_bracketed_paste,
        Screen.leave_alternate_buffer,
    });

    try Screen.disableRawMode();

    try execute(.stdout, .{
        Style { .mod = .{ .underline = .single }, .hyperlink = "https://example.com" },
        "Example",
        Reset { .mod = .{ .underline = .single }, .hyperlink = true },
        '\n',
    });

    std.log.debug("Terminal Size: {any}", .{ getTermSize() });
    std.log.debug("Cursor Pos: {any}", .{ getCursorPos() });
}
