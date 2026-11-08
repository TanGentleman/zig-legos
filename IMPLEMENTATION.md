# zig-legos: implementation

## Requirements

- Linux x86_64. spider v0.12.0 does not compile for macOS on Zig 0.17 (see
  [gotchas](skills/spider/references/gotchas.md)).
- bash, curl, git, python3, tar and unzip.
- Pinned tools; `tools.lock` is the source of truth and this table only mirrors
  it. To bump a tool, edit `tools.lock` and reseed; see
  [`scaffolding/ci/README.md`](scaffolding/ci/README.md).

| Tool | Version | Pinned in |
| --- | --- | --- |
| Zig | 0.17.1 | `tools.lock` (sha256 from ziglang.org) |
| spider | v0.12.0 (`ee554ad`) | each `build.zig.zon` (commit and hash) |
| uv | 0.13.7 | `tools.lock` (sha256 from the uv release) |
| Chrome for Testing | 157.0.8103.38 | `tools.lock` (hash recorded at seed time) |
| rodney | 0.4.0 | `tools.lock` (PyPI) |
| showboat | 0.6.1 | `tools.lock` (PyPI) |

## Usage

```sh
skills/spider/prove.sh --no-demo /tmp/my-app   # scaffold, build, serve, curl /up
source /tmp/my-app/.tools/env                  # the tools prove.sh used
(cd /tmp/my-app && zig build test)
skills/spider/prove.sh /tmp/my-app             # adds a headless-Chrome screenshot and demo.md
cd examples/sysdiag && zig build test && zig build && ./zig-out/bin/sysdiag   # http://127.0.0.1:3000
```

`prove.sh` and `quickstart.sh` reuse a Zig 0.17.x and uv already on PATH, and
Chrome from `ROD_CHROME_BIN` or `/usr/bin/google-chrome`, `chromium` or
`chromium-browser` (not PATH). Anything missing comes from the `ci-tools`
release and lands in `<target>/.tools/`. Until that release is reseeded with
`tools.lock`, put Zig 0.17.1 on PATH and set `ROD_CHROME_BIN` yourself (see
Limits).

| Variable | Default | Purpose |
| --- | --- | --- |
| `ROD_CHROME_BIN` | fixed Chrome paths, then the `ci-tools` download | Chrome for the screenshot and demo |

## How it works

| Piece | What it is |
| --- | --- |
| [`skills/spider/`](skills/spider/SKILL.md) | Claude Code skill: app template, API cheatsheet, gotchas, and `prove.sh`. |
| [`examples/sysdiag/`](examples/sysdiag/README.md) | Live CPU, memory and disk dashboard; `./quickstart.sh` builds and screenshots it. |
| [`scaffolding/ci/`](scaffolding/ci/README.md) | `tools.lock` and `seed.sh`, which mirrors the pinned tools into this repo's `ci-tools` release. |
| [`scaffolding/setup-mirrored-tools/`](scaffolding/setup-mirrored-tools/action.yml) | GitHub Action that installs the pinned tools and checks every checksum. |
| [`plugins/spider-bundle/`](plugins/spider-bundle/README.md) | `pack.sh` bundles the skill and its lock for use without this repo. |

CI and the scripts download tools only from this repo's `ci-tools` release;
rodney and showboat come from PyPI and Chrome's shared libraries from apt.
`seed.sh` is the only code that contacts the upstream CDNs.

## Tests

CI ([`sysdiag-ci.yml`](.github/workflows/sysdiag-ci.yml)) on ubuntu-24.04, after
`scaffolding/setup-mirrored-tools` installs the pinned tools. Template job:

```sh
zig fmt --check examples skills
skills/spider/prove.sh --no-demo "$RUNNER_TEMP/app"
(cd "$RUNNER_TEMP/app" && zig build test --summary all)
```

Screenshot job, in `examples/sysdiag`:

```sh
zig build
zig build test --summary all
./zig-out/bin/sysdiag > /tmp/sysdiag.log 2>&1 &
curl -sf http://127.0.0.1:3000/api/metrics | jq -e '.cores > 0 and .mem_total_kb > 0'
curl -sf http://127.0.0.1:3000/metrics | grep -q 'class="card"'
rodney start
rodney open http://127.0.0.1:3000/
rodney waitidle
rodney sleep 3
rodney screenshot -w 1100 -h 680 "/tmp/sysdiag-ubuntu-24.04.png"
rodney stop
```

It then fails if rodney downloaded a browser into its cache, and uploads the
screenshot. `zig build test` in the template and in sysdiag starts the app with
`spider.testing` on a free local port and requests every route.

## Limits

- The `ci-tools` release still holds Zig `0.17.0-dev.813`, uv 0.11.20 and Chrome
  149, not the versions above. Until someone with write access runs the
  `seed-ci-tools` workflow, CI fails at setup, and so do the scripts on a machine
  without these tools.
- Checked on Linux x86_64 with the tools on PATH. CI has not run on these
  changes; macOS is not supported.
