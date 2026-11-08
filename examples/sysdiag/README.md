# sysdiag

A single-binary local web dashboard for basic system usage diagnostics, built on
[spider](https://github.com/llllOllOOll/spider) v0.12.0 with HTMX.

![sysdiag dashboard](demo/09552cf2-2026-11-08.png)

## What it shows

- **CPU %** — live delta of cumulative CPU ticks, plus core count and load averages
- **Memory %** — used vs. available physical memory
- **Disk %** — `statfs(2)` on `/`, with free/total
- **Uptime**, process count, **swap**, hostname and kernel version

Runs on **Linux** (metrics from `/proc` + Linux `statfs`) and **macOS** (`sysctl`,
mach `host_statistics`, BSD `statfs`); the backend is selected at compile time and
the macOS backend does not build on spider v0.12.0 (see the skill's gotchas).

The page polls a server-rendered HTMX fragment (`GET /metrics`) every 2 seconds.
`GET /api/metrics` returns the same data as JSON. Gauge bars shift from teal to
amber (≥60%) to red (≥85%). Everything — page, htmx, CSS — is embedded in the binary.

## Quick start

Linux x86_64. Reuses Zig 0.17.x and uv from PATH, Chrome from `ROD_CHROME_BIN` or
`/usr/bin/google-chrome`/`chromium`, and
downloads anything missing from the [`ci-tools` release](../../scaffolding/ci/README.md)
into `.tools/` (gitignored).

```sh
git clone https://github.com/TanGentleman/zig-legos
cd zig-legos/examples/sysdiag
./quickstart.sh       # setup, zig build, run on :3000, rodney screenshot to quickstart.png
source .tools/env     # put the same tools on your shell's PATH
```

## Run it

```sh
zig build test        # unit tests plus every route through spider.testing
zig build
./zig-out/bin/sysdiag # http://127.0.0.1:3000
```

## Proof

[`demo/demo.md`](demo/demo.md) is a [showboat](https://pypi.org/project/showboat/)
document: captured `curl` output from the live server plus a
[rodney](https://pypi.org/project/rodney/) (headless Chrome) screenshot of the page.

CI (`.github/workflows/sysdiag-ci.yml`) builds and tests on Linux, runs the server,
smoke-tests the routes, and uploads a live dashboard screenshot.
Chrome comes from the pinned `ci-tools` release (`ROD_CHROME_BIN`), so rodney
downloads no browser.
