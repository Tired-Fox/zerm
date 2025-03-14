# Zerm

A fast pure zig implementation of a terminal ansi library. It is heavily inspired by the `rust` crate [`crossterm`](https://docs.rs/crossterm/latest/crossterm/)

This project is still a work in progress, but already has most of the terminal ansi sequences implemented as batched commands. See `main.zig` for an example of using the commands.

## Installation

```
zig fetch --save git+https://github.com/Tired-Fox/zerm#{commit|tag|branch}
```

```zig
const zerm = b.dependency("zerm", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zerm", zerm.module("zerm"));
```

## Example

**Styling**
```zig
const std = @import("std");
const zerm = @import("zerm");

const execute = zerm.execute;
const Style = zerm.style.Style;
const Reset = zerm.style.Reset;

const styling: Style = .{ .fg = .red };
std.debug.print("{s}Hello, world{s}", .{ styling, styling.reset() });

const styling: Style = .{ .fg = .red };
try execute(.stdout, .{ styling, "Hello, world", Reset { .fg = true } });
```

**Event Handling**

```zig
const std = @import("std");
const zerm = @import("zerm");

const Cursor = zerm.action.Cursor;
const Screen = zerm.action.Screen;
const Capture = zerm.action.Capture;
const getTermSize = zerm.action.getTermSize;

const EventStream = zerm.event.EventStream;

const Style = zerm.style.Style;

const Utf8ConsoleOutput = zerm.Utf8ConsoleOutput;
const execute = zerm.execute;

fn setup() !void {
    try Screen.enableRawMode();
    try execute(.stdout, .{
        Screen.enter_alternate_buffer,
        Cursor { .col = 1, .row = 1, .visibility = .hidden },
    });
}

fn cleanup() !void {
    try Screen.disableRawMode();
    try execute(.stdout, .{
        Cursor { .visibility = .visible },
        Screen.leave_alternate_buffer,
    });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer if (gpa.deinit() == .leak) { std.debug.print("memory leak detected", .{}); };
    const allo = gpa.allocator();

    var stream = EventStream.init(allo);
    defer stream.deinit();

    // Used to get around issue with zig not being able to print utf-8 unicode
    // by default
    const utf8_ctx = Utf8ConsoleOutput.init();
    defer utf8_ctx.deinit();

    try setup();
    errdefer _ = Screen.disableRawMode() catch { std.log.err("error disabling raw mode", .{}); };
    defer cleanup() catch { std.log.err("error cleaning up terminal", .{}); };

    var term = try zuit.Terminal.init(allo, .stdout);
    defer term.deinit();

    try execute(.stdout, .{ "Press `q` to quit\r\n" });

    while (true) {
        if (try stream.parseEvent()) |event| {
            switch (event) {
                .key => |key| {
                    if (key.matches(&.{ 
                        .{ .code = .char('q') },
                        .{ .code = .char('c'), .ctrl = true },
                        .{ .code = .char('C'), .ctrl = true }
                    })) break;

                    try execute(.stdout, .{ .{ "{any}", .{key} } })
                },
                .resize => |resize| {
                    try term.resize(resize[0], resize[1]);
                    try term.render(&app);
                },
                else => {}
            }
        }
    }
}
```
