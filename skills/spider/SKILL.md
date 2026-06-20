---
name: spider
description: Build and prove web servers in Zig using the spider framework — HTTP services, JSON APIs, or HTMX UIs. Covers the toolchain gate, scaffolding from a known-good template, the spider v0.6.7 API, the one-command build-and-prove lifecycle (prove.sh), and proving the result with showboat/rodney.
---

# Building (and proving) systems with spider — the Zig web framework

Verified against **spider v0.6.7** on **Zig 0.17.0-dev.813** (2026-06). If you use a
different spider tag, re-verify against its source — the API moves fast.

Read `references/cheatsheet.md` and `references/gotchas.md` BEFORE writing any code.

## Fast path: one command

For a running, screenshot-proven starter, run the lifecycle and jump to "Extend
it" once it's up:

```sh
skills/spider/prove.sh [--no-demo] [target-dir]   # default: ./spider-app-demo
```

Five steps, stopping at the first hard failure:

1. **setup** — reuse a 0.17.0-dev Zig + uv if on PATH, else fetch the pinned ones
   (checksum-verified) into `<target>/.tools/`; for the demo, `uv tool install`
   pinned rodney + showboat and resolve a Chrome for `ROD_CHROME_BIN`.
2. **scaffold** — copy this skill's `templates/app` into `<target>` *only if absent*
   (idempotent — re-runs reuse your edited app).
3. **build & run** — `zig build`, boot `./zig-out/bin/app`, wait for `/up`.
4. **screenshot** — rodney drives the page and captures `<target>/demo/shot.png`.
5. **demo** — showboat writes a concise `<target>/demo/demo.md`.

`--no-demo` stops after step 3 — a fast, browser-free "just scaffold and build it"
loop that pulls no Chrome (~250MB). All tool versions are pinned in
`scaffolding/ci/tools.lock`. Afterwards, `source <target>/.tools/env` puts the
same tools on your PATH.

The rest of this skill is what `prove.sh` automates — read it when you edit the
app or the script can't cover your case.

## 1. Toolchain gate (do this first, it blocks everything)

spider v0.6.7 requires Zig `0.17.0-dev` >= dev.667. The repo's pinned toolchain
already satisfies that floor; if your PATH zig is older, fetch a project-local nightly:

```sh
zig version   # if it prints 0.17.0-dev.NNN with NNN >= 667, skip the rest
curl -sL https://ziglang.org/download/index.json -o /tmp/zigdl.json
# read .master."x86_64-linux".tarball from it, then:
curl -sL -o /tmp/zig.tar.xz <tarball-url> && tar xf /tmp/zig.tar.xz -C /tmp
export ZIG=/tmp/zig-x86_64-linux-<version>/zig   # use $ZIG everywhere below
```

## 2. Scaffold from the template (don't hand-roll)

```sh
cp -r <this-skill-dir>/templates/app <target-dir>   # only if target absent (idempotent)
cd <target-dir> && $ZIG build && ./zig-out/bin/app
```

The template is a complete, previously-green app: pinned spider dep (with hash, so no
network fetch needed), an HTMX page, a vendored htmx under `src/vendor/`, an
atomic-counter handler, and a `spider.config.zig` (wired in `build.zig`) so it boots
without spider's `views_dir`/`No spider.config.zig` warnings. Smoke-test before
changing anything:

```sh
curl -s localhost:3000/      # the page
curl -s localhost:3000/up    # spider's built-in health route
```

If `$ZIG build` complains about the fingerprint, replace it with the exact value the
error message prints — that is the expected flow, not a failure.

## 3. Extend it

Routes, handlers, JSON, HTMX detection, outbound HTTP: all in `references/cheatsheet.md`,
every signature verified against v0.6.7 source. Rules of thumb:

- spider runs many worker threads — any shared mutable state must be `std.atomic.Value`.
- Allocate per-request memory from `c.arena`; it is freed after the response.
- New dependency pins: `$ZIG fetch --save 'git+https://github.com/llllOllOOll/spider#v0.6.7'`.
- When the cheatsheet doesn't cover an API, do NOT trust memory (0.16/0.17 drift):
  clone spider guarded (`[ -d temp/spider ] || git clone --depth 1 --branch v0.6.7
  https://github.com/llllOllOOll/spider temp/spider`) and grep `src/core/context.zig`,
  `src/core/app.zig`, and the README. zigpeek is for stdlib only.

## 4. Prove it (the deliverable is evidence, not claims)

Run `uvx showboat --help` and `uvx rodney --help` first; take flags from the help text,
not memory. Then the loop:

```sh
uvx rodney start                                   # once; reuse the session
uvx rodney open http://127.0.0.1:3000/ && uvx rodney waitidle
uvx rodney click <selector> ; uvx rodney text <selector>   # drive + assert the UI
uvx rodney screenshot -w 800 -h 460 /tmp/shot.png
uvx showboat init  demo.md "Title"
uvx showboat exec  demo.md bash "curl -s localhost:3000/..."   # captures real output
uvx showboat image demo.md '![alt](/tmp/shot.png)'
```

Restart the server before captures so counters in the demo start clean. If something
cannot pass, write what failed into `demo.md` and stop — never fabricate a screenshot.

**Make the demo about *your* app, not the starter.** The probes must hit the routes you
actually built — never ship the template's `/up` + `/clicked` probes for an app that no
longer serves `/clicked`. After you change routes, re-author `demo/demo.md`: `showboat
note` a one-line lead, `showboat exec` the real requests your UI makes (e.g.
`curl -s -X POST localhost:3000/recipe --data 'ingredients=tomato, basil'`), and drive
rodney's `input`/`click` for your form before the screenshot. `prove.sh` auto-skips the
starter probe on a custom app, but the high-caliber demo is the one you author.

**The concise demo standard:** a one-line lead plus the *minimum* evidence that proves
it — `/up` + one HTMX fragment + the screenshot. Don't pad with every route.

**rodney needs a browser.** A fresh box has no Chrome, so `rodney start` fails unless
`ROD_CHROME_BIN` points at one. The full `prove.sh` fetches the pinned Chrome and sets
it; driving rodney by hand, `export ROD_CHROME_BIN=<chrome>` first (e.g. the
`<target>/.tools/chrome-linux64/chrome` the lifecycle already downloaded).
