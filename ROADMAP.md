# zig-legos roadmap

zig-legos is a kit for shipping small Zig web apps on
[spider](https://github.com/llllOllOOll/spider) + HTMX: a Claude Code skill
(`skills/spider`: template, API cheatsheet, gotchas, `prove.sh`), one worked
example (`examples/sysdiag`, a live system dashboard), and pinned tooling
(`scaffolding/ci/tools.lock` plus a checksum-verified `ci-tools` release that CI
and the scripts download from). For someone (or an agent) who wants a running,
screenshot-proven spider app in one command, without re-deriving a toolchain.

## Status (upstream main 9be30bb, checked 2026-11-08)

- Last CI run on upstream: green on 2026-06-20. None of `-1`..`-5` has run on GitHub.
- The pinned Zig `0.17.0-dev.813` is gone from ziglang.org (404). It still exists
  in the repo's own `ci-tools` release, with uv 0.11.20 and Chrome 149.
- spider v0.6.7 does not build on Zig 0.17.1 (`app.zig:567: no field named
  'Debug' in enum 'lang.Optimize'`). v0.8.0+ needs a Zig 0.17 release; `-5` uses
  v0.12.0 (2026-11-07), the latest tag.
- On `-5`, with Zig 0.17.1, uv 0.13.7 and Chrome 157 on PATH (Linux x86_64):
  `zig fmt --check`, `prove.sh` (with and without demo), `quickstart.sh` and
  `zig build test` for the template and sysdiag pass in a fresh clone.

## Signal vs noise

Keep: the template, the cheatsheet and gotchas (re-verified per spider tag),
`prove.sh`, sysdiag, `tools.lock` and the mirror. Cut: spin-out notes, docs
that pin numbers to an old nightly, dead tracers links. Still noise, not cut:
the setup code duplicated between `quickstart.sh` and `prove.sh`.

## Stack

- `zig-legos-1`: import, fix the dead tracers download URL, drop spin-out notes, this file.
- `zig-legos-2`: `zig build test` with unit tests for sysdiag and the template; CI
  checks `zig fmt`, builds and tests both, and smoke-tests sysdiag's routes.
- `zig-legos-3`: README a stranger can follow, regenerated sysdiag demo, stale doc lines.
- `zig-legos-4`: Zig 0.17.1 + spider v0.11.0, Linux only (see Needs Tan).
- `zig-legos-5`: spider v0.12.0; uv 0.13.7 and Chrome 157 in `tools.lock`; actions
  pinned by SHA; route tests through `spider.testing`; README pins and boundaries;
  skill docs re-checked on v0.12.0; regenerated sysdiag demo.
- `zig-legos-6`: README cut to 29 words; details moved to IMPLEMENTATION.md.

## Needs Tan

- `-4`/`-5` or not: they trade macOS (spider >= v0.8, v0.12.0 included, doesn't
  compile for macOS on Zig 0.17: `health.zig` uses `std.os.linux.clock_gettime`,
  `vdso.zig:8:49: error: struct 'elf.AT__struct_1547' has no member named
  'SYSINFO_EHDR'`) for an official Zig. Without them the stack stays on the
  mirrored nightly, which still works on both OSes.
- After merging `-5`: run the `seed-ci-tools` workflow so `ci-tools` matches
  `tools.lock`; until then CI and the scripts (without the tools on PATH) fail at
  setup. `seed.sh` deletes and recreates the release, so the `0.17.0-dev.813`
  assets go with it: seed only after the merge, or `-1`..`-3` fail at setup too.
- The first upstream CI run is the real check for every CI change in the stack.
