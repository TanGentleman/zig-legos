const std = @import("std");
const spider = @import("spider");
const Metrics = @import("../metrics.zig").Metrics;

// macOS has no /proc; everything here comes from sysctl(3), mach host_statistics,
// and a BSD statfs(2). All via libSystem (build links libc).

// CPU% is a delta of cumulative tick counters between two polls, same shape as
// the Linux /proc/stat path. Benign cross-worker race: a lost update skews one
// poll. See [[metrics-linux]] for the symmetric procfs version.
var prev_cpu_total = std.atomic.Value(u64).init(0);
var prev_cpu_idle = std.atomic.Value(u64).init(0);

extern "c" fn sysctlbyname(
    name: [*:0]const u8,
    oldp: ?*anyopaque,
    oldlenp: ?*usize,
    newp: ?*const anyopaque,
    newlen: usize,
) c_int;
extern "c" fn statfs(path: [*:0]const u8, buf: *Statfs) c_int;
extern "c" fn getloadavg(loadavg: [*]f64, nelem: c_int) c_int;
extern "c" fn proc_listpids(typ: u32, typeinfo: u32, buffer: ?*anyopaque, buffersize: c_int) c_int;
extern "c" fn mach_host_self() c_uint;
extern "c" fn host_statistics(host: c_uint, flavor: c_int, info: *anyopaque, count: *c_uint) c_int;
extern "c" fn host_statistics64(host: c_uint, flavor: c_int, info: *anyopaque, count: *c_uint) c_int;
extern "c" fn host_page_size(host: c_uint, out: *usize) c_int;
extern "c" fn time(out: ?*i64) i64; // wall-clock unix seconds

const HOST_CPU_LOAD_INFO = 3;
const HOST_VM_INFO64 = 4;
const PROC_ALL_PIDS = 1;

// mach/processor_info.h: host_cpu_load_info { natural_t cpu_ticks[CPU_STATE_MAX] }.
const CpuLoad = extern struct { ticks: [4]u32 }; // user, system, idle, nice

// mach/vm_statistics.h: full vm_statistics64 so @sizeOf >= HOST_VM_INFO64_COUNT.
const VmStat64 = extern struct {
    free_count: u32,
    active_count: u32,
    inactive_count: u32,
    wire_count: u32,
    zero_fill_count: u64,
    reactivations: u64,
    pageins: u64,
    pageouts: u64,
    faults: u64,
    cow_faults: u64,
    lookups: u64,
    hits: u64,
    purges: u64,
    purgeable_count: u32,
    speculative_count: u32,
    decompressions: u64,
    compressions: u64,
    swapins: u64,
    swapouts: u64,
    compressor_page_count: u32,
    throttled_count: u32,
    external_page_count: u32,
    internal_page_count: u32,
    total_uncompressed_pages_in_compressor: u64,
};

// sys/sysctl.h: struct xsw_usage (vm.swapusage).
const XswUsage = extern struct {
    total: u64,
    avail: u64,
    used: u64,
    pagesize: u32,
    encrypted: i32,
};

const Timeval = extern struct { sec: i64, usec: i32 };

// sys/mount.h: the 64-bit-inode struct statfs (the only one on arm64).
const Statfs = extern struct {
    f_bsize: u32,
    f_iosize: i32,
    f_blocks: u64,
    f_bfree: u64,
    f_bavail: u64,
    f_files: u64,
    f_ffree: u64,
    f_fsid: [2]i32,
    f_owner: u32,
    f_type: u32,
    f_flags: u32,
    f_fssubtype: u32,
    f_fstypename: [16]u8,
    f_mntonname: [1024]u8,
    f_mntfromname: [1024]u8,
    f_flags_ext: u32,
    f_reserved: [7]u32,
};

/// Read a string sysctl into the request arena; "" on any failure.
fn sysctlStr(c: *spider.Ctx, name: [*:0]const u8) []const u8 {
    var len: usize = 0;
    if (sysctlbyname(name, null, &len, null, 0) != 0 or len == 0) return "";
    const buf = c.arena.alloc(u8, len) catch return "";
    if (sysctlbyname(name, buf.ptr, &len, null, 0) != 0) return "";
    return std.mem.trimEnd(u8, buf[0..len], "\x00\n");
}

/// Read a scalar sysctl of type T; 0 on any failure.
fn sysctlInt(comptime T: type, name: [*:0]const u8) T {
    var v: T = 0;
    var len: usize = @sizeOf(T);
    if (sysctlbyname(name, &v, &len, null, 0) != 0) return 0;
    return v;
}

/// Read a struct sysctl of type T; null on any failure.
fn sysctlStruct(comptime T: type, name: [*:0]const u8) ?T {
    var v: T = undefined;
    var len: usize = @sizeOf(T);
    if (sysctlbyname(name, &v, &len, null, 0) != 0) return null;
    return v;
}

pub fn collect(c: *spider.Ctx) !Metrics {
    var m: Metrics = std.mem.zeroes(Metrics);
    const host = mach_host_self();

    m.hostname = sysctlStr(c, "kern.hostname");
    m.kernel = sysctlStr(c, "kern.osrelease");
    m.cores = @intCast(sysctlInt(i32, "hw.logicalcpu"));
    m.mem_total_kb = sysctlInt(u64, "hw.memsize") / 1024;

    if (sysctlStruct(Timeval, "kern.boottime")) |bt| {
        const now = time(null);
        if (now > bt.sec) m.uptime_secs = @intCast(now - bt.sec);
    }

    var la: [3]f64 = .{ 0, 0, 0 };
    if (getloadavg(&la, 3) == 3) {
        m.load1 = la[0];
        m.load5 = la[1];
        m.load15 = la[2];
    }

    // Total processes: proc_listpids with a null buffer returns the byte size it
    // would fill; each entry is a 4-byte pid_t.
    const bytes = proc_listpids(PROC_ALL_PIDS, 0, null, 0);
    if (bytes > 0) m.procs_total = @as(u64, @intCast(bytes)) / 4;

    // CPU: cumulative ticks (user+system+idle+nice), delta against last poll.
    var cpu: CpuLoad = undefined;
    var cpu_count: c_uint = @sizeOf(CpuLoad) / @sizeOf(u32);
    if (host_statistics(host, HOST_CPU_LOAD_INFO, &cpu, &cpu_count) == 0) {
        const idle = cpu.ticks[2];
        var total: u64 = 0;
        for (cpu.ticks) |t| total += t;
        const pt = prev_cpu_total.swap(total, .monotonic);
        const pi = prev_cpu_idle.swap(idle, .monotonic);
        if (total > pt and idle >= pi) {
            const dt: f64 = @floatFromInt(total - pt);
            const di: f64 = @floatFromInt(idle - pi);
            m.cpu_pct = 100.0 * (dt - di) / dt;
        }
    }

    // Available memory ~ reclaimable pages (free + inactive + speculative + purgeable).
    var vm: VmStat64 = undefined;
    var vm_count: c_uint = @sizeOf(VmStat64) / @sizeOf(u32);
    if (host_statistics64(host, HOST_VM_INFO64, &vm, &vm_count) == 0) {
        var page: usize = 0;
        if (host_page_size(host, &page) != 0) page = 4096;
        const avail_pages: u64 = @as(u64, vm.free_count) +
            vm.inactive_count + vm.speculative_count + vm.purgeable_count;
        m.mem_avail_kb = avail_pages * page / 1024;
    }

    if (sysctlStruct(XswUsage, "vm.swapusage")) |sw| {
        m.swap_total_kb = sw.total / 1024;
        m.swap_free_kb = sw.avail / 1024;
    }

    var st: Statfs = undefined;
    if (statfs("/", &st) == 0) {
        m.disk_total_b = st.f_blocks * st.f_bsize;
        m.disk_avail_b = st.f_bavail * st.f_bsize;
    }

    return m;
}
