# Agent guide — zig-legos

A small kit of reusable Zig + spider building blocks: Claude skills, pinned
toolchain scaffolding, and worked examples. Keep each piece self-contained and
provable on its own.

## Where things live

```text
skills/        # the spider skill: build spider apps + prove.sh (one-command lifecycle)
scaffolding/   # dependency pinning: ci/ (tools.lock + seed.sh), the setup action, CI templates
plugins/       # spider-bundle: pack the spider skill for sharing without a checkout
examples/      # sysdiag — a full spider+HTMX app wired to the scaffolding
```

## Rules of thumb

- Read `skills/spider/references/cheatsheet.md` and `gotchas.md` **before**
  writing or editing any spider code — the spider/Zig 0.17-dev API moves fast,
  so verify against source, never memory.
- All tool versions are pinned in `scaffolding/ci/tools.lock`. Don't hardcode a
  Zig/Chrome/uv version anywhere else; bump the lock and re-seed (see
  `scaffolding/ci/README.md`).
- Every example must stay runnable end-to-end from a fresh clone via its
  `quickstart.sh`, and prove itself with a screenshot/demo.
- Keep scripts repo-root-relative so a piece works the same whether run here or
  after it's bundled (`plugins/spider-bundle/pack.sh`).

## Provenance

These blocks were factored out of the [tracers](https://github.com/TanGentleman/tracers)
monorepo. If something here still assumes a tracers path, that's a migration
bug — see `MIGRATION.md`.
