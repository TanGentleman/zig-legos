# zig-legos roadmap

zig-legos is a kit for shipping small Zig web apps on
[spider](https://github.com/llllOllOOll/spider) + HTMX: a Claude Code skill
(`skills/spider`: template, API cheatsheet, gotchas, `prove.sh`), one worked
example (`examples/sysdiag`, a live system dashboard), and pinned tooling
(`scaffolding/ci/tools.lock` plus a checksum-verified `ci-tools` release that CI
and the scripts download from). For someone (or an agent) who wants a running,
screenshot-proven spider app in one command, without re-deriving a toolchain.

## Status (upstream main 9be30bb, checked 2026-11-08)

- Last CI run on upstream: green on 2026-06-20 (`gh run list -R TanGentleman/zig-legos`).
- The pinned Zig `0.17.0-dev.813` is gone from ziglang.org (404). It still exists
  in the repo's own `ci-tools` release (`gh release view ci-tools`).
- `quickstart.sh` and `prove.sh` downloaded from `TanGentleman/tracers/releases`,
  which 404s, so setup failed on any machine without a 0.17.0-dev zig. Fixed on
  `-1`; after the fix `prove.sh --no-demo` (fresh clone, no zig on PATH) and the
  full `quickstart.sh` (build, run, headless-Chrome screenshot) pass on Linux.
- Zig 0.17.1 is the current release. spider v0.6.7 does not build on it
  (`app.zig:567: no field named 'Debug' in enum 'lang.Optimize'`). spider v0.8.0+
  targets Zig 0.17.0 releases; latest tags are v0.11.0 (2026-10-18) and v0.12.0
  (2026-11-07).
- No tests: neither `build.zig` had a `test` step and CI never built the
  skill's template (`-2` adds both).
- `MIGRATION.md` described the tracers spin-out, already done (cut on `-1`).

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
- `zig-legos-4` (optional, see Needs Tan): Zig 0.17.1 + spider v0.11.0, Linux only.

## Apply upstream

```bash
# in kranti-sandbox; N = the last branch you want (1..4)
base=$(git log -1 --format=%H --grep='^Import zig-legos upstream' origin/zig-legos-1)
git format-patch --relative=zig-legos "$base"..origin/zig-legos-N -o /tmp/zig-legos-N
# in a clean upstream clone at 9be30bb
git clone https://github.com/TanGentleman/zig-legos && cd zig-legos
git am /tmp/zig-legos-N/*.patch
zig fmt --check examples skills
skills/spider/prove.sh --no-demo /tmp/spider-app && (cd /tmp/spider-app && zig build test)
(cd examples/sysdiag && ./quickstart.sh && zig build test)   # from -2 on
```

One branch at a time: `origin/zig-legos-1..origin/zig-legos-2`, and so on. With `-4`, put Zig
0.17.1 on PATH or run the seed workflow first (see below).

## Needs Tan

- `-4` or not: it trades macOS (spider >= v0.8 doesn't compile for macOS on Zig
  0.17, `health.zig` uses `std.os.linux.clock_gettime`) for an official Zig. Without
  it the stack stays on the mirrored nightly, which still works on both OSes.
- After `-4`: run the `seed-ci-tools` workflow so the `ci-tools` release has Zig
  0.17.1; until then CI and `prove.sh` (without a 0.17.x zig on PATH) fail at setup.
  `seed.sh` deletes and recreates the release, so the `0.17.0-dev.813` assets
  go with it: seed only once `-4` is merged, or `-1`..`-3` fail at setup too.
- None of the CI changes has run on GitHub; the first upstream run is the real
  check, the macOS jobs on `-2`/`-3` most of all (only cross-compiled here).
- spider v0.12.0 (2026-11-07) is untested.
