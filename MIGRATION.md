# zig-legos spin-out — migration plan

Goal: **two repos, each with one clear audience.**

- **`tracers`** — the product (CLI + `scanner` + `tracers-web` dashboard +
  `benchmarks`). "Find, review, and safely share rough Claude Code sessions."
- **`zig-legos`** — the reusable kit (skills + pinned scaffolding + examples).
  "Building blocks for shipping Zig + spider + HTMX apps."

This folder is the **staged contents of `zig-legos`**, assembled inside `tracers`
the same way launchpad was prepped (#85) before being lifted out and
decommissioned (#86). Nothing here is wired into tracers' build or CI, so this
PR is purely additive and breaks nothing.

## What was moved here (and from where)

| In `zig-legos/` | Copied from `tracers/` |
|---|---|
| `skills/spider/` (spider-app + shippers, merged) | `.claude/skills/{spider-app,shippers}/` |
| `plugins/spider-bundle/` | `plugins/spider-shipper/` |
| `scaffolding/ci/` | `sysdiag/ci/` (the canonical pinning home now) |
| `scaffolding/setup-mirrored-tools/` | `.github/actions/setup-mirrored-tools/` |
| `scaffolding/workflows/*` | `.github/workflows/{seed-ci-tools,sysdiag-ci}.yml` (templated) |
| `examples/sysdiag/` | `sysdiag/` (its `ci/` dropped — it now consumes `scaffolding/ci/`) |

## Reference repoints already applied to the copies

So the scripts are correct **once this folder is the repo root**:

- `skills/spider/prove.sh`, `plugins/spider-bundle/pack.sh` → lock at
  `$repo/scaffolding/ci/tools.lock`; skill at `$repo/skills/spider`.
- `scaffolding/setup-mirrored-tools/action.yml` → `$GITHUB_WORKSPACE/scaffolding/ci/tools.lock`.
- `examples/sysdiag/quickstart.sh` + `README.md` → `../../scaffolding/ci/…`.
- `scaffolding/ci/{README,seed}.sh` → self-references under `scaffolding/`.

The `spider-app` + `shippers` skills were **merged into one `spider` skill**
(`shippers/lifecycle.sh` → `skills/spider/prove.sh`); the bundler plugin was
renamed `spider-shipper` → `spider-bundle`. Only the `~/.claude/skills/` paths in
`plugins/spider-bundle` are intentionally left — those are install instructions
for a bundle recipient.

## Lift-out steps (I can't do these — they need a second repo)

My GitHub access is scoped to `tangentleman/tracers`, so creating `zig-legos` and
pushing to it is a human step:

1. **Create** the `zig-legos` repo.
2. **Move** this folder to the new repo root. To carry history:
   `git filter-repo --path zig-legos/ --path-rename zig-legos/:` then push;
   or just copy the tree for a clean start.
3. **Activate CI:** move `scaffolding/workflows/*.yml` → `.github/workflows/`
   (the composite action stays at `scaffolding/setup-mirrored-tools/`, referenced
   as `uses: ./scaffolding/setup-mirrored-tools`).
4. **Seed the release:** `GH_TOKEN=$(gh auth token) bash scaffolding/ci/seed.sh`
   to create `zig-legos`'s own `ci-tools` release (self-contained pinning — it no
   longer borrows tracers').
5. **Verify:** `cd examples/sysdiag && ./quickstart.sh` shows the dashboard;
   `zig build test` is green; the seed + sysdiag workflows pass on a PR.

## Decommission checklist on the `tracers` side (follow-up PR)

After `zig-legos` exists and is green, remove the moved pieces from `tracers`.
The catch: `tracers-web` and the quickstarts still need the **pinning**, so
relocate it to a tracers-owned home first (decision: self-contained pinning in
both repos).

1. **Relocate pinning:** `git mv sysdiag/ci ci` (top-level, tracers-owned) and
   repoint every reference — currently in:
   - `.github/actions/setup-mirrored-tools/action.yml` (the tracers copy)
   - `.github/workflows/{tracers-ci,tracers-macos-ci,tracers-web-ci,seed-ci-tools}.yml`
   - `tracers-web/quickstart.sh`, `tracers-web/README.md`
   - `tracers/README.md`, `tracers/demo/viewer-shot.sh`, `docs/zig.md`
2. **Delete** the spun-out trees: `sysdiag/`, `.claude/skills/{spider-app,shippers}/`,
   `plugins/spider-shipper/`.
3. **Delete** the now-orphaned workflows: `.github/workflows/{sysdiag-ci,shippers-ci}.yml`
   (and drop their badges from the root `README.md`).
4. **Repoint docs:** `docs/spider.md` and `AGENTS.md` should link to the
   `zig-legos` repo for the spider skills instead of `.claude/skills/`.
5. **Re-seed** tracers' own `ci-tools` release from the relocated `ci/tools.lock`.

## Out of scope (noted, not done here)

- `scanner/src/scan.zig` uses `std.mem.trim(u8, raw, "\r\n")` where
  `std.mem.trimEnd(u8, raw, "\r")` matches the stated "strip delimiter + trailing
  CR" intent and the repo's own idiom (`digest.zig`, `root.zig`, `inbox.zig` all
  do exactly this). Verified against Zig master via zigpeek — `trimRight` was
  renamed to `trimEnd`. Applied in a companion `tracers` PR.
