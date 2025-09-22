const std = @import("std");
const builtin = @import("builtin");

pub const style = @import("style.zig");
pub const action = @import("action.zig");
pub const event = @import("event.zig");

/// Available output streams
pub const Stream = enum(u2) {
    stdout,
    stderr,

    pub fn isTty(self: *const @This()) bool {
        return switch (self.*) {
            .stdout => std.fs.File.stdout().isTty(),
            .stderr => std.fs.File.stderr().isTty(),
        };
    }
};

pub const TerminalWriter = struct {
    const CHUNK_SIZE: usize = 8;

    // Public interface you’ll pass around
    interface: std.Io.Writer,

    // Platform state
    file: std.fs.File,
    buffer: [1024*CHUNK_SIZE*2]u16 = undefined,

    pub fn init(target: Stream, buffer: []u8) @This() {
        const f = switch (target) {
            .stdout => std.fs.File.stdout(),
            .stderr => std.fs.File.stderr(),
        };

        var self = @This(){
            .interface = undefined,
            .file = f,
        };

        self.interface = .{
            .vtable = &.{
                .drain = drain,
            },
            .buffer = buffer,
        };
        return self;
    }

    fn drain(io_w: *std.io.Writer, chunks: []const []const u8, splat: usize) std.io.Writer.Error!usize {
        const self: *@This() = @alignCast(@fieldParentPtr("interface", io_w));

        var written: usize = 0;
        if (builtin.target.os.tag == .windows) {
            while (io_w.end > 0) {
                const a = try self.drainWindows(&.{ io_w.buffer[0..@min(1024*CHUNK_SIZE, io_w.end)] }, splat);
                _ = io_w.consume(a);
                written += a;
            }
        } else {
            const a = try self.drainPosix(&.{ io_w.buffer }, splat);
            _ = io_w.consume(io_w.buffer.len);
            written += a;
        }

        if (builtin.target.os.tag == .windows) {
            written += try self.drainWindows(chunks, splat);
        } else {
            written += try self.drainPosix(chunks, splat);
        }

        return written;
    }

    fn drainPosix(self: *@This(), chunks: []const []const u8, splat: usize) std.io.Writer.Error!usize {
        var written: usize = 0;
        for (chunks, 0..) |chunk, i| {
            if (i + 1 == chunks.len and splat > 1) {
                // write last chunk `splat` times logically
                for (0..splat) |_| {
                    self.file.writeAll(chunk) catch return error.WriteFailed;
                    written += chunk.len;
                }
            } else {
                self.file.writeAll(chunk) catch return error.WriteFailed;
                written += chunk.len;
            }
        }
        return written;
    }

    fn drainWindows(self: *@This(), chunks: []const []const u8, splat: usize) std.io.Writer.Error!usize {
        const windows = std.os.windows;
        const kernel32 = windows.kernel32;

        // Get the output file handle
        const handle = self.file.handle;

        const is_console = blk: {
            var mode: windows.DWORD = 0;
            break :blk kernel32.GetConsoleMode(handle, &mode) != 0;
        };

        const helper = struct {
            pub fn writeUtf16Stream(buffer: []u16, source: []const u8, hnd: windows.HANDLE, console: bool) std.io.Writer.Error!usize {
                var written: usize = 0;
                if (console) {
                    var i: usize = 0;

                    var it = Utf8Iterator{ .bytes = source, .i = 0 };
                    while (true) {
                        const cp_slice = it.nextCodepointSlice() catch break orelse break;
                        const cp = std.unicode.utf8Decode(cp_slice) catch {
                            it.i -= cp_slice.len;
                            break;
                        };

                        if (cp <= 0xFFFF) {
                            buffer[i] = @intCast(cp);
                            i += 1;
                        } else if (cp <= 0x10FFFF) {
                            const adjusted = cp - 0x10000;
                            const high = 0xD800 + (adjusted >> 10);
                            const low = 0xDC00 + (adjusted & 0x3FF);
                            buffer[i] = @intCast(high);
                            buffer[i+1] = @intCast(low);
                            i += 2;
                        } else {
                            break;
                        }
                    }

                    if (kernel32.WriteConsoleW(hnd, buffer.ptr, @intCast(i), @ptrCast(&written), null) == 0)
                        return error.WriteFailed;
                    return it.i;
                } else {
                    if (kernel32.WriteFile(hnd, source.ptr, @intCast(source.len), @ptrCast(&written), null) == 0)
                        return error.WriteFailed;
                    return source.len;
                }
            }
        };

        var written: usize = 0;

        for (chunks, 0..) |chunk, i| {
            if (i + 1 == chunks.len and splat > 1) {
                for (0..splat) |_| {
                    written += try helper.writeUtf16Stream(&self.buffer, chunk, handle, is_console);
                }
            } else {
                written += try helper.writeUtf16Stream(&self.buffer, chunk, handle, is_console);
            }
        }

        return written;
    }

    pub const Utf8Iterator = struct {
        bytes: []const u8,
        i: usize,

        pub fn nextCodepointSlice(it: *Utf8Iterator) !?[]const u8 {
            if (it.i >= it.bytes.len) {
                return null;
            }

            const cp_len = try std.unicode.utf8ByteSequenceLength(it.bytes[it.i]);
            it.i += cp_len;
            return it.bytes[it.i - cp_len .. it.i];
        }

        pub fn nextCodepoint(it: *Utf8Iterator) !?u21 {
            const slice = try it.nextCodepointSlice() orelse return null;
            return try std.unicode.utf8Decode(slice);
        }

        /// Look ahead at the next n codepoints without advancing the iterator.
        /// If fewer than n codepoints are available, then return the remainder of the string.
        pub fn peek(it: *Utf8Iterator, n: usize) []const u8 {
            const original_i = it.i;
            defer it.i = original_i;

            var end_ix = original_i;
            var found: usize = 0;
            while (found < n) : (found += 1) {
                const next_codepoint = it.nextCodepointSlice() orelse return it.bytes[original_i..];
                end_ix += next_codepoint.len;
            }

            return it.bytes[original_i..end_ix];
        }
    };
};

/// Run each command in the arguments
///
/// All commands that print to the `source` will
/// be buffered and batched all at once.
///
/// All commands that run native code will be executed
/// immediatly.
///
/// Supports u8, u16, u21, u32, comptime_int and anything that implements the `format`
/// function for printing with a writer.
///
/// # Example
///
/// ```zig
/// pub const CustomType = struct {
///    pub fn format(
///       _: @This(),
///       writer: *std.io.Writer
///    ) std.io.Writer.Error!void {
///         try writer.print("CustomType");
///    }
/// }
///
/// try execute(.stdout, .{
///     Style { .fg = Color.Green },
///     '✓',
///     Reset.fg(),
///     ' ',
///     CustomType{},
/// });
/// ```
pub fn execute(source: Stream, ops: anytype) !void {
    var buffer: [1024]u8 = undefined;
    var output = TerminalWriter.init(source, &buffer);

    inline for (ops) |op| {
        try writeOp(op, &output.interface);
    }

    try output.interface.flush();
}

/// Run each command in the arguments
///
/// All commands that print to the `source` will
/// be buffered and batched all at once.
///
/// All commands that run native code will be executed
/// immediatly.
///
/// Supports u8, u16, u21, u32, comptime_int and anything that implements the `format`
/// function for printing with a writer.
///
/// This will run WinApi calls immediatly but hold onto the ansi sequences until `flush`
/// is called on the returned queue.
///
/// # Example
///
/// ```zig
/// pub const CustomType = struct {
///    pub fn format(
///       _: @This(),
///       writer: *std.io.Writer
///    ) std.io.Writer.Error!void {
///         try writer.print("CustomType");
///    }
/// }
///
/// const q = Queue.init(.stdout);
/// try q.writeAll(.{
///     Style { .fg = Color.Green },
///     '✓',
///     Reset.fg(),
///     ' ',
///     CustomType{},
/// });
///
/// try q.write("Some other item");
///
/// // ... Additional logic
///
/// try q.flush();
/// ```
pub const Queue = struct {
    buffer: [1024]u8 = undefined,
    writer: TerminalWriter = undefined,

    pub fn init(stream: Stream) @This() {
        var instance = @This(){};
        instance.writer = TerminalWriter.init(stream, &instance.buffer);
        return instance;
    }

    pub fn write(self: *@This(), op: anytype) !void {
        try writeOp(op, &self.writer.interface);
    }

    pub fn writeAll(self: *@This(), ops: anytype) !void {
        inline for (ops) |op| {
            try writeOp(op, &self.writer.interface);
        }
    }

    pub fn flush(self: *@This()) !void {
        try self.writer.interface.flush();
    }
};

/// Write the value, if it's type is supported, to the provider writer
///
/// Supported types:
///     - `[]const u8`
///     - `u8`, `u21`, `u32`, `comptime_int`
///     - Any type that implements `format` to be use with the string formatter
pub fn writeOp(op: anytype, writer: *std.io.Writer) !void {
    const T = @TypeOf(op);
    switch (T) {
        u8 => try writer.writeByte(op),
        []const u8, [:0]const u8 => try writer.writeAll(op),
        u21, u32, comptime_int => {
            var buff: [4]u8 = [_]u8{0} ** 4;
            const length = try std.unicode.utf8Encode(@intCast(op), &buff);
            try writer.writeAll(buff[0..length]);
        },
        else => {
            switch (@typeInfo(T)) {
                .@"struct" => {
                    if (@hasDecl(T, "format")) {
                        try writer.print("{f}", .{op});
                    } else {
                        try writer.print(op[0], op[1]);
                    }
                },
                .pointer => |p| {
                    if (p.size == .many and p.child == u8) {
                        try writer.writeAll(std.mem.sliceTo(op, 0));
                    } else if (p.size == .one and @typeInfo(p.child) == .array and @typeInfo(p.child).array.child == u8) {
                        try writer.writeAll(op);
                    }
                },
                else => {
                    try writer.print("{f}", .{op});
                },
            }
        },
    }
}

/// This is a work around on `windows` since windows likes `UTF16` encoding.
///
/// If a user attempts to print a unicode character that is not in the ascii space
/// the user is required to encode it as utf16.
///
/// It just sets the console output to `UTF8` and requires the user to call `deinit`
/// to reset it to what it was before the app ran. This is to avoid causing problems
/// for other terminal applications in the future.
pub const Utf8ConsoleOutput = struct {
    original: if (builtin.os.tag == .windows) c_uint else void,

    pub fn init() @This() {
        if (builtin.os.tag == .windows) {
            const original = std.os.windows.kernel32.GetConsoleOutputCP();
            _ = std.os.windows.kernel32.SetConsoleOutputCP(65001);
            return .{ .original = original };
        }
        return .{ .original = {} };
    }

    pub fn deinit(self: @This()) void {
        if (builtin.os.tag == .windows) {
            _ = std.os.windows.kernel32.SetConsoleOutputCP(self.original);
        }
    }
};

test {
    std.testing.refAllDecls(@This());
}
