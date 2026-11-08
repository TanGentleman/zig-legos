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
- No tests: neither `build.zig` has a `test` step. CI builds only sysdiag; the
  skill's template is never built in CI.
- `MIGRATION.md` described the tracers spin-out, already done (cut on `-1`).

## Signal vs noise

Keep: the template, the cheatsheet and gotchas (re-verified per spider tag),
`prove.sh`, sysdiag, `tools.lock` and the mirror. Cut: spin-out notes, docs
that pin numbers to an old nightly, the setup code duplicated between
`quickstart.sh` and `prove.sh`.

## Stack

- `zig-legos-1`: import, fix the dead tracers download URL, drop spin-out notes, this file.

## Apply a branch upstream

```bash
# in kranti-sandbox: everything after the import commit
base=$(git log -1 --format=%H --grep='^Import zig-legos upstream' zig-legos-1)
git format-patch --relative=zig-legos "$base"..zig-legos-1 -o /tmp/zig-legos-1
# in a clean upstream clone at 9be30bb
git clone https://github.com/TanGentleman/zig-legos && cd zig-legos
git am /tmp/zig-legos-1/*.patch
skills/spider/prove.sh --no-demo /tmp/spider-app
```

For a stacked branch, use the previous branch as the base: `zig-legos-1..zig-legos-2`.

## Needs Tan
