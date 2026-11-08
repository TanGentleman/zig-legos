# zig-legos

[![CI](https://github.com/TanGentleman/zig-legos/actions/workflows/sysdiag-ci.yml/badge.svg)](https://github.com/TanGentleman/zig-legos/actions/workflows/sysdiag-ci.yml)

Get a running, screenshot-proven Zig web app on
[spider](https://github.com/llllOllOOll/spider) + HTMX in one command, with
every tool version pinned and checksum-verified.

```sh
git clone https://github.com/TanGentleman/zig-legos && cd zig-legos
skills/spider/prove.sh my-app   # fetch pinned tools, scaffold, build, serve, screenshot
```

`my-app/` is a working spider app (HTMX page, vendored htmx, `zig build test`),
`my-app/demo/demo.md` holds real `curl` output plus a headless-Chrome screenshot.
`--no-demo` skips the browser and just scaffolds, builds and serves.
Linux x86_64 and macOS arm64. Needs bash, curl, git, python3, tar, unzip.

## What's here

| Piece | What it is |
|---|---|
| [`skills/spider/`](skills/spider/SKILL.md) | A Claude Code skill: app template, spider v0.6.7 API cheatsheet and gotchas, and `prove.sh`. |
| [`examples/sysdiag/`](examples/sysdiag/README.md) | A live system dashboard (CPU, memory, disk) on spider + HTMX. `./quickstart.sh` builds it and screenshots it. |
| [`scaffolding/ci/`](scaffolding/ci/README.md) | `tools.lock` (Zig, uv, Chrome for Testing, rodney, showboat) and `seed.sh`, which mirrors them into this repo's `ci-tools` release. |
| [`scaffolding/setup-mirrored-tools/`](scaffolding/setup-mirrored-tools/action.yml) | GitHub Action that installs the pinned tools and verifies every checksum. |
| [`plugins/spider-bundle/`](plugins/spider-bundle/README.md) | `pack.sh` bundles the skill and its lock so it works without this repo. |

## Pinning

All tool versions live in [`scaffolding/ci/tools.lock`](scaffolding/ci/tools.lock).
CI, `prove.sh` and `quickstart.sh` download them from the repo's `ci-tools`
release and check them against its `SHA256SUMS`, so a fresh clone and CI get the
same bytes. The spider dependency is pinned by commit and hash in each
`build.zig.zon`. To bump a tool, see [`scaffolding/ci/README.md`](scaffolding/ci/README.md).

## Develop

```sh
cd examples/sysdiag && source .tools/env   # after one quickstart.sh run
zig build test && zig build && ./zig-out/bin/sysdiag   # http://127.0.0.1:3000
```

CI ([`sysdiag-ci.yml`](.github/workflows/sysdiag-ci.yml)) runs `zig fmt --check`,
builds and tests the template and sysdiag on Linux and macOS, and uploads a
dashboard screenshot per OS.

Factored out of Tan's tracers monorepo; same spirit as
[zigpeek](https://github.com/TanGentleman/zigpeek).
