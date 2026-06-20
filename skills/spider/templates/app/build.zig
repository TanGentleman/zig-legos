const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const spider_dep = b.dependency("spider", .{ .target = target });
    const spider_mod = spider_dep.module("spider");

    // Register our spider.config.zig as spider's `spider_config` import, overriding
    // the framework's default. Without this, spider boots with views_dir="./views"
    // and warns about a missing config and a missing views dir on every start.
    const spider_config = b.createModule(.{
        .root_source_file = b.path("spider.config.zig"),
        .imports = &.{.{ .name = "spider", .module = spider_mod }},
    });
    spider_mod.addImport("spider_config", spider_config);

    const exe = b.addExecutable(.{
        .name = "app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "spider", .module = spider_mod },
            },
        }),
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the server");
    run_step.dependOn(&b.addRunArtifact(exe).step);
}
