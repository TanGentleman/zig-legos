const std = @import("std");
const spider = @import("spider");

var clicks = std.atomic.Value(u32).init(0); // shared across spider's worker threads

pub fn main() void {
    serve() catch {};
}

fn serve() !void {
    var server = spider.app(.{});
    defer server.deinit();
    try server
        .get("/", index, .{})
        .get("/htmx.js", htmxJs, .{}) // vendored htmx 2.0.4, embedded in the binary
        .get("/clicked", clicked, .{})
        .listen(.{ .port = 3000 });
}

fn index(c: *spider.Ctx) !spider.Response {
    return c.html(@embedFile("index.html"), .{});
}

fn htmxJs(_: *spider.Ctx) !spider.Response {
    return .{ .body = @embedFile("vendor/htmx.min.js"), .content_type = "text/javascript" };
}

// HTMX fragment: swapped into #out on each button click
fn clicked(c: *spider.Ctx) !spider.Response {
    const n = clicks.fetchAdd(1, .monotonic) + 1;
    return c.html(try std.fmt.allocPrint(c.arena, "<b>Server says: {d} click(s)!</b>", .{n}), .{});
}

// spider.testing.start runs serve() on a free 127.0.0.1 port, once per test binary.
test "routes" {
    const app = try spider.testing.start(serve);
    const cases = [_]struct { path: []const u8, contains: []const u8, content_type: []const u8 }{
        .{ .path = "/", .contains = "hx-get=\"/clicked\"", .content_type = "text/html" },
        .{ .path = "/htmx.js", .contains = "htmx", .content_type = "text/javascript" },
        .{ .path = "/clicked", .contains = "click(s)!</b>", .content_type = "text/html" },
    };
    for (cases) |case| {
        var res = try app.get(case.path);
        defer res.deinit();
        try res.expectStatus(200);
        try res.expectContains(case.contains);
        try std.testing.expect(std.mem.startsWith(u8, res.header("content-type") orelse "", case.content_type));
    }
    var missing = try app.get("/nope");
    defer missing.deinit();
    try missing.expectStatus(404);
}

test "clicked counts up" {
    const app = try spider.testing.start(serve);
    var first = try app.get("/clicked");
    defer first.deinit();
    var second = try app.get("/clicked");
    defer second.deinit();
    const a = try std.fmt.parseInt(u32, between(first.body, "says: ", " click").?, 10);
    const b = try std.fmt.parseInt(u32, between(second.body, "says: ", " click").?, 10);
    try std.testing.expectEqual(a + 1, b);
}

fn between(s: []const u8, start: []const u8, end: []const u8) ?[]const u8 {
    const i = (std.mem.indexOf(u8, s, start) orelse return null) + start.len;
    const j = std.mem.indexOfPos(u8, s, i, end) orelse return null;
    return s[i..j];
}
