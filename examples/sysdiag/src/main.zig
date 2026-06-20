const std = @import("std");
const builtin = @import("builtin");
const spider = @import("spider");
const metrics = @import("metrics.zig");

// Kernel name shown on the Host card, e.g. "Linux 6.18.5" / "Darwin 25.5.0".
const os_name = switch (builtin.os.tag) {
    .linux => "Linux",
    .macos => "Darwin",
    else => "Unknown",
};

pub fn main() void {
    var server = spider.app(.{});
    defer server.deinit();
    server
        .get("/", index)
        .get("/htmx.js", htmxJs) // vendored htmx 2.0.4, embedded in the binary
        .get("/metrics", metricsFragment)
        .get("/api/metrics", metricsJson)
        .listen(.{ .port = 3000 }) catch {};
}

fn index(c: *spider.Ctx) !spider.Response {
    return c.html(@embedFile("index.html"), .{});
}

fn htmxJs(_: *spider.Ctx) !spider.Response {
    return .{ .body = @embedFile("vendor/htmx.min.js"), .content_type = "text/javascript" };
}

// ----------------------------------------------------------------- handlers

fn metricsJson(c: *spider.Ctx) !spider.Response {
    const m = try metrics.collect(c);
    return c.json(m, .{});
}

fn pctUsed(total: u64, avail: u64) f64 {
    if (total == 0) return 0;
    const used: f64 = @floatFromInt(total - avail);
    return 100.0 * used / @as(f64, @floatFromInt(total));
}

fn fmtBytes(c: *spider.Ctx, b: u64) ![]const u8 {
    const f: f64 = @floatFromInt(b);
    if (b >= 1 << 30) return std.fmt.allocPrint(c.arena, "{d:.1} GiB", .{f / (1 << 30)});
    if (b >= 1 << 20) return std.fmt.allocPrint(c.arena, "{d:.1} MiB", .{f / (1 << 20)});
    return std.fmt.allocPrint(c.arena, "{d:.1} KiB", .{f / (1 << 10)});
}

fn barClass(pct: f64) []const u8 {
    if (pct >= 85) return "bar hot";
    if (pct >= 60) return "bar warm";
    return "bar";
}

/// One gauge card: big value, fill bar, footnote.
fn gauge(c: *spider.Ctx, label: []const u8, pct: f64, detail: []const u8) ![]const u8 {
    return std.fmt.allocPrint(c.arena,
        \\<div class="card">
        \\  <div class="label">{s}</div>
        \\  <div class="value">{d:.1}<span class="unit">%</span></div>
        \\  <div class="track"><div class="{s}" style="width:{d:.1}%"></div></div>
        \\  <div class="detail">{s}</div>
        \\</div>
    , .{ label, pct, barClass(pct), @min(pct, 100), detail });
}

// HTMX fragment: the dashboard grid, re-rendered every poll.
fn metricsFragment(c: *spider.Ctx) !spider.Response {
    const m = try metrics.collect(c);

    const mem_pct = pctUsed(m.mem_total_kb, m.mem_avail_kb);
    const disk_pct = pctUsed(m.disk_total_b, m.disk_avail_b);

    const cpu_detail = try std.fmt.allocPrint(c.arena, "{d} cores &middot; load {d:.2} / {d:.2} / {d:.2}", .{ m.cores, m.load1, m.load5, m.load15 });
    const mem_detail = try std.fmt.allocPrint(c.arena, "{s} of {s} in use", .{
        try fmtBytes(c, (m.mem_total_kb - m.mem_avail_kb) * 1024),
        try fmtBytes(c, m.mem_total_kb * 1024),
    });
    const disk_detail = try std.fmt.allocPrint(c.arena, "{s} free of {s} on /", .{
        try fmtBytes(c, m.disk_avail_b),
        try fmtBytes(c, m.disk_total_b),
    });

    const days = m.uptime_secs / 86400;
    const hrs = (m.uptime_secs % 86400) / 3600;
    const mins = (m.uptime_secs % 3600) / 60;
    const secs = m.uptime_secs % 60;
    const uptime = if (days > 0)
        try std.fmt.allocPrint(c.arena, "{d}d {d}h {d}m", .{ days, hrs, mins })
    else
        try std.fmt.allocPrint(c.arena, "{d}h {d}m {d}s", .{ hrs, mins, secs });

    const tasks_detail = try std.fmt.allocPrint(c.arena, "{d} processes", .{m.procs_total});

    const swap_value = if (m.swap_total_kb == 0)
        "none"
    else
        try std.fmt.allocPrint(c.arena, "{s} free", .{try fmtBytes(c, m.swap_free_kb * 1024)});
    const swap_detail = if (m.swap_total_kb == 0)
        "no swap configured"
    else
        try std.fmt.allocPrint(c.arena, "of {s} total", .{try fmtBytes(c, m.swap_total_kb * 1024)});

    const html = try std.fmt.allocPrint(c.arena,
        \\{s}
        \\{s}
        \\{s}
        \\<div class="card">
        \\  <div class="label">Uptime</div>
        \\  <div class="value-sm">{s}</div>
        \\  <div class="detail">{s}</div>
        \\</div>
        \\<div class="card">
        \\  <div class="label">Swap</div>
        \\  <div class="value-sm">{s}</div>
        \\  <div class="detail">{s}</div>
        \\</div>
        \\<div class="card">
        \\  <div class="label">Host</div>
        \\  <div class="value-sm">{s}</div>
        \\  <div class="detail">{s} {s}</div>
        \\</div>
    , .{
        try gauge(c, "CPU", m.cpu_pct, cpu_detail),
        try gauge(c, "Memory", mem_pct, mem_detail),
        try gauge(c, "Disk", disk_pct, disk_detail),
        uptime,
        tasks_detail,
        swap_value,
        swap_detail,
        m.hostname,
        os_name,
        m.kernel,
    });
    return c.html(html, .{});
}
