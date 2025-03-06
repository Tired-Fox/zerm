const std = @import("std");
const termz = @import("termz");

const Screen = termz.action.Screen;
const getTermSize = termz.action.getTermSize;

const Utf8ConsoleOutput = termz.Utf8ConsoleOutput;

const EventStream = termz.event.EventStream;
const Key = termz.event.Key;

const execute = termz.execute;

pub fn main() !void {
    // This is needed for windows since it wants utf16
    // but zig encodes it's output as utf8
    const utf8_ctx = Utf8ConsoleOutput.init();
    defer utf8_ctx.deinit();

    const cols, const rows = try getTermSize();
    try execute(.stdout, .{
        Screen { .title = "Screen Example" },
        .{ "Size: {d} x {d}\n", .{ cols, rows } },
    });

    try execute(.stdout, .{
        "Resize to 30 x 30\n",
        Screen { .resize = .{ .w = 30, .h = 30 }}
    });

    const c, const r = try getTermSize();
    try execute(.stdout, .{
        .{ "Size: {d} x {d}\n", .{ c, r } },
    });

    try execute(.stdout, .{
        .{ "Resize to {d} x {d}", .{ cols, rows }},
        Screen { .resize = .{ .w = cols, .h = rows }}
    });
}
