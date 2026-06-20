# spider v0.6.7 API cheatsheet (verified against source, 2026-06)

## App and routes

```zig
const spider = @import("spider");

pub fn main() void {
    var server = spider.app(.{});
    defer server.deinit();
    server
        .get("/", index)            // also .post/.put/.patch/.delete
        .get("/users/:id", show)    // :params via trie router
        .listen(.{ .port = 3000 }) catch {};   // .host = "0.0.0.0" also accepted
}
```

Handlers are `fn (c: *spider.Ctx) !spider.Response`. `/up` health route is built in.
The template ships a `spider.config.zig` (registered in `build.zig` via
`spider_mod.addImport("spider_config", cfg_mod)`) so the server boots without the
`No spider.config.zig` / `views_dir not found` warnings. Its `views_dir = null`
declares this app embeds its assets and uses no runtime template engine.

## Ctx — the request

```zig
c.arena                          // per-request allocator, freed after the response
c.params.get("id")               // ?[]const u8, from :id in the route
                                 //   (README shows c.param("id") — that method does
                                 //    NOT exist in v0.6.7; use the params hashmap)
c.query("q")                     // ?[]const u8
c.header("x-thing")              // ?[]const u8
c.isHtmx()                       // true if HX-Request header present
c.cookie("session")              // ?[]const u8
c.body                           // ?[]const u8 raw body (also c.getBody())
const j = try c.bodyJson(struct { name: []const u8 });   // returns T directly
const f = try c.parseForm(struct { name: []const u8 });  // urlencoded or multipart
```

## Response

```zig
return c.json(.{ .id = 1 }, .{});                            // application/json
return c.json(.{ .detail = "nope" }, .{ .status = .too_many_requests });
return c.html("<h1>hi</h1>", .{});                           // text/html
return c.html(@embedFile("index.html"), .{});                // embed a page
return c.text("hi", .{});                                    // text/plain
return c.redirect("/dashboard");
return c.json(.{ .ok = true }, .{ .headers = &.{.{ "X-Foo", "bar" }} });
```

`spider.Response` is a plain struct — return it directly for full control
(this is how you serve a vendored JS file with the right MIME type):

```zig
return .{ .body = @embedFile("vendor/htmx.min.js"), .content_type = "text/javascript" };
```

Fields: `status` (std.http.Status, default .ok), `body`, `content_type`,
`headers: []const [2][]const u8`, `cookies`, `raw: bool`.

## Outbound HTTP (spider.http_client, the bundled `pacman` client)

```zig
var res = try spider.http_client.post(c._io, c.arena, "http://127.0.0.1:8001/job", .{
    .body = .{ .json = "{\"build\":\"beta\"}" },   // pre-serialized; .form and .raw exist
});
const parsed = try res.json(struct { ok: bool, result: []const u8 });
// parsed.value.result; res.status; res.text() for the raw body
```

Note `c._io` — the handler's `std.Io` lives on Ctx as `_io`. Also:
`.get/.put/.patch/.delete/.head`, options `.headers`, `.query`, `.timeout_ms`.

## Filesystem reads inside a handler

`std.fs` file APIs moved to `std.Io.Dir` in 0.17-dev; they all take an `Io` — use the
handler's `c._io`. Absolute paths work with `cwd()` (openat semantics):

```zig
var buf: [1 << 16]u8 = undefined;
const s = try std.Io.Dir.cwd().readFile(c._io, "/proc/meminfo", &buf);
const owned = try c.arena.dupe(u8, s);   // buf is stack-local; dupe to keep it
```

Do NOT use `readFileAlloc` on `/proc` — size-0 files return `""` (see gotchas).

## Shared state across requests

spider spawns ~12 worker threads. Globals must be atomic:

```zig
var hits = std.atomic.Value(u32).init(0);
const n = hits.fetchAdd(1, .monotonic) + 1;
```

## build.zig wiring (see templates/app/ for the whole thing)

```zig
const spider_dep = b.dependency("spider", .{ .target = target });
// then add .{ .name = "spider", .module = spider_dep.module("spider") } to imports
```
