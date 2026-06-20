# zig-legos

Reusable building blocks for shipping **Zig + spider + HTMX** apps, fast and
proven — the skills, the pinned toolchain scaffolding, and worked examples,
factored out of [tracers](https://github.com/TanGentleman/tracers) so they stand
on their own.

If you've used [zigpeek](https://github.com/TanGentleman/zigpeek), this is the
same spirit: small, single-purpose, **offline-capable, version-pinned** tooling
that doubles as a Claude Code skill. Each "lego" is a skill *plus* the
scaffolding it needs *plus* a worked example you can run end-to-end.

> **Staging note:** this folder currently lives inside the `tracers` repo as the
> prep step for a standalone spin-out (the same playbook launchpad used). Paths
> in the scripts assume **this folder is the repo root** — they're correct once
> it's lifted out. See [`MIGRATION.md`](MIGRATION.md) for the move + the
> decommission checklist on the tracers side.

## What's here

| Piece | What it gives you |
|---|---|
| [`skills/spider/`](skills/spider/SKILL.md) | Build *and* prove Zig HTTP, JSON, and HTMX services on spider v0.6.7 — a known-good app template, the API cheatsheet + gotchas, and `prove.sh`, the one-command scaffold → build → screenshot → [showboat](https://pypi.org/project/showboat/) demo lifecycle. |
| [`scaffolding/ci/`](scaffolding/ci/README.md) | The dependency-pinning core: `tools.lock` (Zig/uv/Chrome, checksum-pinned), `seed.sh` (mirror them into a `ci-tools` release), and the story behind it. |
| [`scaffolding/setup-mirrored-tools/`](scaffolding/setup-mirrored-tools/action.yml) | A composite GitHub Action that fetches the pinned tools for the runner and verifies every byte — drop-in for any app's CI. |
| [`scaffolding/workflows/`](scaffolding/workflows/) | Copy-paste CI workflow templates (seed the release; build + screenshot an app). |
| [`plugins/spider-bundle/`](plugins/spider-bundle/README.md) | `pack.sh` bundles the `spider` skill + a vendored `tools.lock` into something you can hand to anyone — no checkout required. |
| [`examples/sysdiag/`](examples/sysdiag/README.md) | A complete spider + HTMX app (a live system-usage dashboard) wired to the scaffolding above — the reference every new app is modeled on. |

## The pinning principle

Every tool version (Zig nightly, uv, Chrome for Testing, rodney, showboat) is
pinned in one place — [`scaffolding/ci/tools.lock`](scaffolding/ci/tools.lock) —
and served from a single checksum-verified `ci-tools` release. CI and the
quickstarts pull from the same release, so a fresh clone and a CI run get byte-
identical tools, and the only CDN traffic happens at seed time. New apps reuse
this instead of re-deriving a toolchain. See
[`scaffolding/ci/README.md`](scaffolding/ci/README.md).

## Quickstart (the worked example)

```sh
cd examples/sysdiag
./quickstart.sh   # pinned tools → zig build → run → headless-Chrome screenshot
```

When `quickstart.png` shows your machine's numbers, the whole chain works. To
scaffold a *new* app instead, drive the `spider` skill:

```sh
skills/spider/prove.sh my-app   # scaffold + build + prove a fresh spider app
```
