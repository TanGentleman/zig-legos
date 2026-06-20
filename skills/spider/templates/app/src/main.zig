const std = @import("std");
const spider = @import("spider");

var clicks = std.atomic.Value(u32).init(0); // shared across spider's worker threads

pub fn main() void {
    var server = spider.app(.{});
    defer server.deinit();
    server
        .get("/", index)
        .get("/htmx.js", htmxJs) // vendored htmx 2.0.4, embedded in the binary
        .get("/clicked", clicked)
        .listen(.{ .port = 3000 }) catch {};
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
