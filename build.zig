// Reference: https://ziggit.dev/t/build-system-tricks/3531

const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // ========================================================================
    //                                  setup
    // ========================================================================
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const version = std.SemanticVersion{ .major = 0, .minor = 0, .patch = 0 };
    const lib_path = b.path("src/root.zig");

    // ========================================================================
    //                              lib module
    // ========================================================================

    const lib_mod = b.addModule("term", .{ .root_source_file = lib_path });

    switch (OS) {
        .windows => {
            const zigwin32_dep = b.dependency("zigwin32", .{});
            const zigwin32_mod = zigwin32_dep.module("zigwin32");

            lib_mod.addImport("zigwin32", zigwin32_mod);
        },
        else => {},
    }

    // ========================================================================
    //                                  Tests
    // ========================================================================

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // ========================================================================
    //                                    docs
    // ========================================================================

    // const docs_step = b.step("docs", "Generate documentation");
    //
    // const docs_install = b.addInstallDirectory(.{
    //     .install_dir = .prefix,
    //     .install_subdir = "docs",
    //     .source_dir = lib.getEmittedDocs(),
    // });
    // docs_step.dependOn(&docs_install.step);
    // b.default_step.dependOn(&docs_step.step);

    // ========================================================================
    //                                 examples
    // ========================================================================

    const examples_step = b.step("examples", "Run examples");
    inline for (EXAMPLES) |NAME| {
        const example = b.addExecutable(.{
            .name = NAME,
            .target = target,
            .version = version,
            .optimize = optimize,
            .root_source_file = b.path(EXAMPLES_DIR ++ NAME ++ "/main.zig"),
        });

        example.root_module.addImport("term", lib_mod);
        const example_run = b.addRunArtifact(example);

        // This allows the user to pass arguments to the application in the build
        // command itself, like this: `zig build examples -- arg1 arg2 etc`
        if (b.args) |args| {
            example_run.addArgs(args);
        }

        examples_step.dependOn(&example_run.step);
    }

    // Use this to make it so `zig build` also runs examples
    // b.default_step.dependOn(examples_step);
}

const OS = @import("builtin").target.os.tag;
const EXAMPLES_DIR = "examples/";
const EXAMPLES = &.{
    // "print",
    "query",
    // "input",
    // "actions",
    // "styling",
};
