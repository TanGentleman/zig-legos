const std = @import("std");
const builtin = @import("builtin");
const spider = @import("spider");

/// One snapshot of system usage, identical across platforms so the handlers and
/// templates never branch on OS. Each backend fills every field (0/"" when a
/// source is unavailable) rather than erroring, so the dashboard always renders.
pub const Metrics = struct {
    hostname: []const u8,
    kernel: []const u8,
    uptime_secs: u64,
    load1: f64,
    load5: f64,
    load15: f64,
    procs_total: u64,
    cpu_pct: f64,
    cores: u64,
    mem_total_kb: u64,
    mem_avail_kb: u64,
    swap_total_kb: u64,
    swap_free_kb: u64,
    disk_total_b: u64,
    disk_avail_b: u64,
};

const impl = switch (builtin.os.tag) {
    .linux => @import("metrics/linux.zig"),
    .macos => @import("metrics/darwin.zig"),
    else => @compileError("sysdiag supports Linux and macOS only"),
};

pub fn collect(c: *spider.Ctx) !Metrics {
    return impl.collect(c);
}
