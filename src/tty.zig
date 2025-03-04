/// This is a port of the rust crate `supports-color`
/// https://github.com/zkat/supports-color
///

const std = @import("std");
const Stream = @import("root.zig").Stream;

fn envForceColor(force_color: ?[]const u8, cli_color_force: ?[]const u8) !usize {
    if (force_color) |fc| {
        if (std.mem.eql(u8, fc, "true") or std.mem.eql(u8, fc, "")) {
            return 1;
        } else if (std.mem.eql(u8, fc, "false")) {
            return 0;
        } else {
            return @min(3, std.fmt.parseInt(usize, fc, 10) catch 1);
        }
    } else if (cli_color_force) |ccf| {
        return if (!std.mem.eql(u8, ccf, "0")) 1 else 0;
    }
    return 0;
}

fn envNoColor(no_color: ?[]const u8) bool {
    const nc = no_color orelse return false;
    if (std.mem.eql(u8, nc, "0")) return false;
    return true;
}

fn checkColorTerm16M(color_term: ?[]const u8) bool {
    const variable = color_term orelse return false;
    return std.mem.eql(u8, variable, "truecolor") or std.mem.eql(u8, variable, "24bit");
}

fn checkTerm16M(term: ?[]const u8) bool {
    const variable = term orelse return false;
    return std.mem.endsWith(u8, variable, "direct") or std.mem.endsWith(u8, variable, "truecolor");
}

fn check256Color(term: ?[]const u8) bool {
    const variable = term orelse return false;
    return std.mem.endsWith(u8, variable, "256") or std.mem.endsWith(u8, variable, "256color");
}

fn checkAnsiColor(term: ?[]const u8) bool {
    switch (@import("builtin").os.tag) {
        .windows => {
            const variable = term orelse return true;
            return !std.mem.eql(u8, variable, "dumb") and !std.mem.eql(u8, variable, "cygwin");
        },
        else => {
            const variable = term orelse return true;
            return !std.mem.eql(u8, variable, "dumb");
        },
    }
}

pub const ColorLevel = struct {
    level: usize,
    has_basic: bool = false,
    has_256: bool = false,
    has_16m: bool = false,

    pub fn translateLevel(level: usize) ?@This() {
        if (level != 0) {
            return .{
                .level = level,
                .has_basic = true,
                .has_256 = level >= 2,
                .has_16m = level >= 3,
            };
        }
        return null;
    }
};

fn isTty(stream: Stream) bool {
    return switch (stream) {
        .Stdout => std.io.getStdOut().isTty(),
        .Stderr => std.io.getStdErr().isTty(),
    };
}

fn varEql(variable: ?[]const u8, value: []const u8) bool {
    const env = variable orelse return false;
    return std.mem.eql(u8, env, value);
}

fn varNotEql(variable: ?[]const u8, value: []const u8) bool {
    const env = variable orelse return false;
    return !std.mem.eql(u8, env, value);
}

fn supportsColor(stream: Stream) usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allo = arena.allocator();

    var map = std.process.getEnvMap(allo) catch return 0;
    defer map.deinit();

    const force_color = envForceColor(map.get("FORCE_COLOR"), map.get("CLICOLOR_FORCE")) catch 0;
    if (force_color > 0) return force_color;

    if (envNoColor(map.get("NO_COLOR")) or varEql(map.get("TERM"), "dumb") or !(isTty(stream) or varNotEql(map.get("IGNORE_IS_TERMINAL"), "0"))) {
        return 0;
    }

    if (checkColorTerm16M(map.get("COLORTERM")) or checkTerm16M(map.get("TERM")) or varEql(map.get("TERM_PROGRAM"), "iTerm.app")) {
        return 3;
    }

    if (varEql(map.get("TERM_PROGRAM"), "Apple_Terminal") or check256Color(map.get("TERM"))) {
        return 2;
    }

    if (map.get("COLORTERM") != null or checkAnsiColor(map.get("TERM")) or varNotEql(map.get("CLICOLOR"), "0") or isCi(&map)) {
        return 1;
    }

    return 0;
}

pub fn on(stream: Stream) ?ColorLevel {
    return ColorLevel.translateLevel(supportsColor(stream));
}

const ColorOnce = union(enum) {
    unset: void,
    set: ?ColorLevel,

    pub fn getOrInit(self: *@This(), stream: Stream) ?ColorLevel {
        switch (self.*) {
            .unset => {
                self.* = .{ .set = ColorLevel.translateLevel(supportsColor(stream)) };
                return self.set;
            },
            .set => |value| return value,
        }
    }
};

var COLOR_LEVEL_CACHE: [2]ColorOnce = [_]ColorOnce{.{ .unset = {}}, .{ .unset = {}}};
pub fn onCached(stream: Stream) ?ColorLevel {
    return COLOR_LEVEL_CACHE[@intFromEnum(stream)].getOrInit(stream);
}

/// Port of rust's is_ci crate: https://docs.rs/is_ci/latest/src/is_ci/lib.rs.html#25-66
fn isCi(map: *const std.process.EnvMap) bool {
    if (map.get("CI")) |ci| {
        if (std.mem.eql(u8, ci, "true") or std.mem.eql(u8, ci, "1") or std.mem.eql(u8, ci, "woodpecker")) return true;
    }

    if (map.get("NODE")) |node| {
        if (std.mem.endsWith(u8, node, "//heroku/node/bin/node")) return true;
    }

    return map.get("CI_NAME") != null
        or map.get("CI_NAME") != null
        or map.get("GITHUB_ACTION") != null
        or map.get("GITLAB_CI") != null
        or map.get("NETLIFY") != null
        or map.get("TRAVIS") != null
        or map.get("CODEBUILD_SRC_DIR") != null
        or map.get("BUILDER_OUTPUT") != null
        or map.get("GITLAB_DEPLOYMENT") != null
        or map.get("NOW_GITHUB_DEPLOYMENT") != null
        or map.get("NOW_BUILDER") != null
        or map.get("BITBUCKET_DEPLOYMENT") != null
        or map.get("GERRIT_PROJECT") != null
        or map.get("SYSTEM_TEAMFOUNDATIONCOLLECTIONURI") != null
        or map.get("BITRISE_IO") != null
        or map.get("BUDDY_WORKSPACE_ID") != null
        or map.get("BUILDKITE") != null
        or map.get("CIRRUS_CI") != null
        or map.get("APPVEYOR") != null
        or map.get("CIRCLECI") != null
        or map.get("SEMAPHORE") != null
        or map.get("DRONE") != null
        or map.get("DSARI") != null
        or map.get("TDDIUM") != null
        or map.get("STRIDER") != null
        or map.get("TASKCLUSTER_ROOT_URL") != null
        or map.get("JENKINS_URL") != null
        or map.get("bamboo.buildKey") != null
        or map.get("GO_PIPELINE_NAME") != null
        or map.get("HUDSON_URL") != null
        or map.get("WERCKER") != null
        or map.get("MAGNUM") != null
        or map.get("NEVERCODE") != null
        or map.get("RENDER") != null
        or map.get("SAIL_CI") != null
        or map.get("SHIPPABLE") != null;
}
