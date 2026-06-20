const std = @import("std");
const spider = @import("spider");
const Metrics = @import("../metrics.zig").Metrics;

// CPU% needs a delta between two /proc/stat samples; keep the previous one
// here. Benign race across spider's workers: a lost update only skews one poll.
var prev_cpu_total = std.atomic.Value(u64).init(0);
var prev_cpu_idle = std.atomic.Value(u64).init(0);

fn readProc(c: *spider.Ctx, path: []const u8) ![]u8 {
    // /proc files report size 0, which makes Io.Dir.readFileAlloc return "".
    // readFile into a caller buffer does plain read()s and works.
    var buf: [1 << 16]u8 = undefined;
    const s = try std.Io.Dir.cwd().readFile(c._io, path, &buf);
    return c.arena.dupe(u8, s);
}

fn firstToken(line: []const u8) []const u8 {
    var it = std.mem.tokenizeAny(u8, line, " \t");
    return it.next() orelse "";
}

/// Count running processes: each top-level numeric /proc/<pid> dir is a
/// thread-group leader, i.e. one process (threads live under <pid>/task). This
/// matches macOS's proc_listpids count. Best-effort: 0 if /proc can't be read.
fn countProcs(c: *spider.Ctx) u64 {
    var dir = std.Io.Dir.cwd().openDir(c._io, "/proc", .{ .iterate = true }) catch return 0;
    defer dir.close(c._io);
    var count: u64 = 0;
    var it = dir.iterate();
    while (it.next(c._io) catch null) |entry| {
        for (entry.name) |ch| {
            if (!std.ascii.isDigit(ch)) break;
        } else if (entry.name.len > 0) count += 1; // all-digit name → a pid
    }
    return count;
}

/// Value of a `Key:  12345 kB` line in /proc/meminfo, or 0 if absent.
fn meminfoValue(text: []const u8, key: []const u8) u64 {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, key)) continue;
        var it = std.mem.tokenizeAny(u8, line[key.len..], " \t");
        const num = it.next() orelse return 0;
        return std.fmt.parseInt(u64, num, 10) catch 0;
    }
    return 0;
}

// Linux x86-64 struct statfs (all __fsword_t fields are 8 bytes).
const Statfs = extern struct {
    f_type: i64,
    f_bsize: i64,
    f_blocks: u64,
    f_bfree: u64,
    f_bavail: u64,
    f_files: u64,
    f_ffree: u64,
    f_fsid: [2]i32,
    f_namelen: i64,
    f_frsize: i64,
    f_flags: i64,
    f_spare: [4]i64,
};

pub fn collect(c: *spider.Ctx) !Metrics {
    var m: Metrics = undefined;

    m.hostname = std.mem.trimEnd(u8, try readProc(c, "/proc/sys/kernel/hostname"), "\n");
    m.kernel = std.mem.trimEnd(u8, try readProc(c, "/proc/sys/kernel/osrelease"), "\n");

    const uptime = try readProc(c, "/proc/uptime");
    m.uptime_secs = @intFromFloat(try std.fmt.parseFloat(f64, firstToken(uptime)));

    // "0.52 0.58 0.59 1/267 12345" — we take the three load averages; the 4th
    // field counts tasks (threads), so for a real process count we walk /proc.
    const loadavg = try readProc(c, "/proc/loadavg");
    var lit = std.mem.tokenizeAny(u8, loadavg, " \n");
    m.load1 = try std.fmt.parseFloat(f64, lit.next() orelse "0");
    m.load5 = try std.fmt.parseFloat(f64, lit.next() orelse "0");
    m.load15 = try std.fmt.parseFloat(f64, lit.next() orelse "0");
    m.procs_total = countProcs(c);

    const stat = try readProc(c, "/proc/stat");
    m.cores = 0;
    m.cpu_pct = 0;
    var slines = std.mem.splitScalar(u8, stat, '\n');
    while (slines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "cpu")) continue;
        if (line.len > 3 and std.ascii.isDigit(line[3])) {
            m.cores += 1;
            continue;
        }
        // Aggregate "cpu" line: user nice system idle iowait irq softirq steal ...
        var it = std.mem.tokenizeAny(u8, line[3..], " ");
        var total: u64 = 0;
        var idle: u64 = 0;
        var i: usize = 0;
        while (it.next()) |f| : (i += 1) {
            const v = std.fmt.parseInt(u64, f, 10) catch 0;
            total += v;
            if (i == 3 or i == 4) idle += v; // idle + iowait
        }
        const pt = prev_cpu_total.swap(total, .monotonic);
        const pi = prev_cpu_idle.swap(idle, .monotonic);
        if (total > pt and idle >= pi) {
            const dt: f64 = @floatFromInt(total - pt);
            const di: f64 = @floatFromInt(idle - pi);
            m.cpu_pct = 100.0 * (dt - di) / dt;
        }
    }

    const meminfo = try readProc(c, "/proc/meminfo");
    m.mem_total_kb = meminfoValue(meminfo, "MemTotal:");
    m.mem_avail_kb = meminfoValue(meminfo, "MemAvailable:");
    m.swap_total_kb = meminfoValue(meminfo, "SwapTotal:");
    m.swap_free_kb = meminfoValue(meminfo, "SwapFree:");

    m.disk_total_b = 0;
    m.disk_avail_b = 0;
    var st: Statfs = undefined;
    if (std.os.linux.syscall2(.statfs, @intFromPtr("/"), @intFromPtr(&st)) == 0) {
        const bsize: u64 = @intCast(st.f_bsize);
        m.disk_total_b = st.f_blocks * bsize;
        m.disk_avail_b = st.f_bavail * bsize;
    }

    return m;
}
