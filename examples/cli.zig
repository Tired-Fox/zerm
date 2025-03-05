const std = @import("std");
const termz = @import("termz");

const Screen = termz.action.Screen;
const Cursor = termz.action.Cursor;
const getTermSize = termz.action.getTermSize;
const getCursorPos = termz.action.getCursorPos;
const Line = termz.action.Line;
const Capture = termz.action.Capture;
const Style = termz.style.Style;
const Color = termz.style.Color;
const Reset = termz.style.Reset;

const Utf8ConsoleOutput = termz.Utf8ConsoleOutput;

const EventStream = termz.event.EventStream;
const KeyCode = termz.event.KeyCode;

const execute = termz.execute;

pub fn main() !void {
    // This is needed for windows since it wants utf16
    // but zig encodes it's output as utf8
    const utf8_ctx = Utf8ConsoleOutput.init();
    defer utf8_ctx.deinit();

    try execute(.Stdout, .{
        Screen.title("Hello World"),

        Style { .fg = Color.Red },
        "Hello, ",
        Reset.fg(),

        Cursor.Save,
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
        Line.erase(.FromBeginning),
        '\r',
        Style { .fg = Color.Green },
        '✓',
        Reset.fg(),
        " Success\n"
    });

    try execute(.Stdout, .{
        Screen.title("Hello Everyone"),

        Cursor.Restore,
        Line.erase(.ToEnd),

        Style { .fg = Color.Yellow },
        "everyone!",
        Reset.fg(),
        Cursor { .shape = .block, .down = 2, .col = 1 }
    });

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

    var stream = EventStream.init(arena.allocator());
    defer stream.deinit();

    while (true) {
        if (try stream.parseEvent()) |evt| {
            switch (evt) {
                .key => |ke| {
                    std.log.debug("{any}\r", .{ ke });
                    if (ke.matches(.{ .code = KeyCode.char('c'), .ctrl = true })) break;
                    if (ke.matches(.{ .code = KeyCode.char('q') })) break;
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

    try execute(.Stdout, .{
        Capture.DisableMouse,
        Capture.DisableFocus,
        Capture.DisableBracketedPaste,
        Screen.LeaveAlternateBuffer,
    });

    try Screen.disableRawMode();

    try execute(.Stdout, .{
        Style { .mod = .{ .underline = true }, .hyperlink = "https://example.com" },
        "Example",
        Reset { .mod = .{ .underline = true }, .hyperlink = true },
        '\n',
    });

    std.log.debug("Terminal Size: {any}", .{ getTermSize() });
    std.log.debug("Cursor Pos: {any}", .{ getCursorPos() });
}
