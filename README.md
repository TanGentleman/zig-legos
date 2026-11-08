# zig-legos

A kit for small Zig web apps on [spider](https://github.com/llllOllOOll/spider)
v0.12.0 + HTMX: a Claude Code skill with an app template, one worked example,
and pinned, checksum-verified tooling.

| Piece | What it is |
| --- | --- |
| [`skills/spider/`](skills/spider/SKILL.md) | Claude Code skill: app template, API cheatsheet, gotchas, and `prove.sh`. |
| [`examples/sysdiag/`](examples/sysdiag/README.md) | Live CPU, memory and disk dashboard; `./quickstart.sh` builds and screenshots it. |
| [`scaffolding/ci/`](scaffolding/ci/README.md) | `tools.lock` and `seed.sh`, which mirrors the pinned tools into this repo's `ci-tools` release. |
| [`scaffolding/setup-mirrored-tools/`](scaffolding/setup-mirrored-tools/action.yml) | GitHub Action that installs the pinned tools and checks every checksum. |
| [`plugins/spider-bundle/`](plugins/spider-bundle/README.md) | `pack.sh` bundles the skill and its lock for use without this repo. |

## Quick start

Linux x86_64 only: spider v0.12.0 does not compile for macOS on Zig 0.17 (see
[gotchas](skills/spider/references/gotchas.md)). Needs bash, curl, git, python3,
tar and unzip.

```sh
git clone https://github.com/TanGentleman/zig-legos && cd zig-legos
skills/spider/prove.sh --no-demo /tmp/my-app   # scaffold, build, serve, curl /up
source /tmp/my-app/.tools/env                  # the tools prove.sh used
(cd /tmp/my-app && zig build test)
skills/spider/prove.sh /tmp/my-app             # adds a headless-Chrome screenshot and demo.md
```

`prove.sh` and `quickstart.sh` reuse a Zig 0.17.x and uv already on PATH, and
Chrome from `ROD_CHROME_BIN` or `/usr/bin/google-chrome`, `chromium` or
`chromium-browser` (not PATH). Anything missing comes from the `ci-tools`
release and lands in `<target>/.tools/`. Until that release is reseeded with
`tools.lock`, put [Zig 0.17.1](https://ziglang.org/download/) on PATH and set
`ROD_CHROME_BIN` yourself (see Boundaries).

## Pins

| Tool | Version | Pinned in |
| --- | --- | --- |
| Zig | 0.17.1 | `tools.lock` (sha256 from ziglang.org) |
| spider | v0.12.0 (`ee554ad`) | each `build.zig.zon` (commit and hash) |
| uv | 0.13.7 | `tools.lock` (sha256 from the uv release) |
| Chrome for Testing | 157.0.8103.38 | `tools.lock` (hash recorded at seed time) |
| rodney | 0.4.0 | `tools.lock` (PyPI) |
| showboat | 0.6.1 | `tools.lock` (PyPI) |

`tools.lock` is the source of truth; this table only mirrors it. To bump a tool,
edit `tools.lock` and reseed; see
[`scaffolding/ci/README.md`](scaffolding/ci/README.md).

## Develop

```sh
zig fmt --check examples skills
skills/spider/prove.sh --no-demo /tmp/spider-app && (cd /tmp/spider-app && zig build test)
cd examples/sysdiag && zig build test && zig build && ./zig-out/bin/sysdiag   # http://127.0.0.1:3000
```

`zig build test` in the template and in sysdiag starts the app with
`spider.testing` on a free local port and requests every route. CI
([`sysdiag-ci.yml`](.github/workflows/sysdiag-ci.yml)) runs the commands above
on ubuntu-24.04, then curls sysdiag's routes and uploads a dashboard screenshot.

## Boundaries

- CI and the scripts download tools only from this repo's `ci-tools` release;
  rodney and showboat come from PyPI and Chrome's shared libraries from apt.
  `seed.sh` is the only code that contacts the upstream CDNs.
- The `ci-tools` release still holds Zig `0.17.0-dev.813`, uv 0.11.20 and Chrome
  149, not the versions above. Until someone with write access runs the
  `seed-ci-tools` workflow, CI fails at setup, and so do the scripts on a machine
  without these tools.
- Checked on Linux x86_64 with the tools on PATH. CI has not run on these
  changes; macOS is not supported.
