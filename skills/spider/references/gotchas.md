# Gotchas — one scar per line

All observed on spider v0.6.7 + Zig 0.17.0-dev.813, Linux, 2026-06. Re-check on other versions.

- **Toolchain gate**: every spider tag back to v0.4.0 sets `minimum_zig_version` to a
  0.17.0-dev build. Older PATH zigs hard-error before compiling anything.
- **Bodyless POST kills the worker**: `curl -X POST` with no `-d` (no Content-Length at
  all) trips `std.http.Server` assert in `discardBody` → thread panic. Always send a
  body in tests; htmx and browsers send `Content-Length: 0`, which is fine.
- **README drift**: README's `c.param("id")` doesn't exist in v0.6.7 — use
  `c.params.get("id")`. When README and source disagree, the source wins; grep
  `src/core/context.zig` first.
- **`@embedFile` cannot escape the module root**: vendored assets must live under
  `src/` (e.g. `src/vendor/htmx.min.js`), not next to it.
- **CDNs may be blocked** in sandboxed environments (unpkg/jsdelivr → 403) while
  github.com works. Vendor JS (raw.githubusercontent.com fetch) and serve it from the
  binary with a custom `content_type` Response.
- **Fingerprint dance**: any new/renamed `build.zig.zon` package fails with
  "invalid fingerprint; use this value: 0x...". Paste the suggested value. Expected.
- **Worker threads**: spider starts ~12 workers; non-atomic shared globals are a data
  race. `std.atomic.Value` + `fetchAdd(..., .monotonic)`.
- **htmx swallows non-2xx**: by default htmx does not swap a 4xx/5xx response into the
  page. If a button "does nothing", check the response status before debugging the UI
  (and remember in-memory counters persist until the server restarts).
- **Boot clean — register a `spider.config.zig`**: spider warns "No spider.config.zig
  found" / "views_dir not found" whenever the `spider_config` import is its built-in
  default. The template ships a `spider.config.zig` (`views_dir = null`, since assets
  are embedded) and `build.zig` registers it on the spider module
  (`spider_mod.addImport("spider_config", cfg_mod)`) — that override is what silences
  both warnings. Hand-rolling a build.zig without it falls back to the default and
  warns. One informational line remains — `[spider] runtime templates: N loaded from
  "src"` (spider always indexes the `src` fallback); it's stdout, not a `warning:`.
- **`.env` gitignore nag**: spider warns if a `.gitignore` exists without a `.env`
  entry. The template's `.gitignore` lists `.env`; add it to any app that trips this.
- **`zig build run` may buffer/hold the terminal** — run the built binary in the
  background instead: `./zig-out/bin/<name> > /tmp/server.log 2>&1 &`, then curl.
- **showboat output fences**: command output with no trailing newline glues the closing
  fence (renders broken). End exec commands with `; echo` when output may lack `\n`.
- **procfs reads come back empty**: `/proc` files stat as size 0, and both
  `std.Io.Dir.readFileAlloc` and `File.Reader`'s `allocRemaining` trust that size →
  they return `""` with no error. Use `Dir.readFile(io, path, &buf)` into a caller
  buffer (plain read()s until EOF) and `arena.dupe` the slice if it must outlive it.
- **A local named `main` won't compile**: `const main = ...` inside a handler errors with
  "local constant shadows declaration of 'main'" (the top-level `fn main`). Name
  request-scoped locals something else (`first`, `primary`, …).
- **rodney needs a browser**: a fresh box has no system Chrome, so `rodney start` fails
  unless `ROD_CHROME_BIN` points at one. The full `prove.sh` fetches the pinned
  Chrome and exports it; driving rodney by hand, set `ROD_CHROME_BIN` first.
- **stdlib drift in 0.17-dev**: `std.fs.Dir` is now `std.Io.Dir` (every call takes the
  `io` — in a handler that's `c._io`); `std.mem.trimRight/trimLeft` are now
  `trimEnd/trimStart`. No `statfs` wrapper exists in std — define the x86-64
  `struct statfs` yourself and call `std.os.linux.syscall2(.statfs, ...)`.
