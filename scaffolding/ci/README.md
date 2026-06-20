# CI tool mirror

CI and the example apps pull their build tools — Zig nightly, uv, Chrome for
Testing — from a single rolling `ci-tools` release **this repo owns**, instead of
third-party CDNs. Runs are reproducible (every byte is checksum-pinned) and
network-isolated (the only CDN traffic happens at seed time, not in CI).

> **After spin-out:** the `ci-tools` release must be (re)seeded under the
> `zig-legos` repo so this pinning is self-contained — run `seed.sh` once there
> (see [`../../MIGRATION.md`](../../MIGRATION.md)). Until then the lock's URLs
> still resolve from upstream CDNs at seed time.

## Pieces

- **`tools.lock`** — JSON manifest, the single source of truth: per-tool
  version, per-platform upstream URL + mirrored asset name + provenance hint.
  Platform keys are `linux-x86_64` and `macos-aarch64`.
- **`seed.sh`** — downloads the locked artifacts from upstream, verifies
  provenance, and (re)creates the `ci-tools` release with the assets plus a
  generated `SHA256SUMS`. The only code that talks to upstream CDNs.
- **`.github/workflows/seed-ci-tools.yml`** — manual (`workflow_dispatch`)
  wrapper over `seed.sh`. Runnable locally too:
  `GH_TOKEN=$(gh auth token) bash scaffolding/ci/seed.sh`.
- **`scaffolding/setup-mirrored-tools/action.yml`** — composite action CI
  calls instead of four `setup-*` actions: downloads the pinned assets for the
  runner's OS/arch, verifies each against `SHA256SUMS`, extracts, and exports
  PATH entries plus `ROD_CHROME_BIN`. Also installs rodney from PyPI at the
  version pinned in `tools.lock`.

The mirror isn't CI-only: `examples/sysdiag/quickstart.sh` consumes the same release
(via plain `curl`, verified against `SHA256SUMS`) to set up a fresh
contributor machine.

## Bumping a tool

1. Edit the version (and URLs/asset names/hashes) in `tools.lock`.
2. Run the **seed ci-tools** workflow from the Actions tab (or `seed.sh`
   locally). It replaces the release wholesale.
3. Open a PR — the examples' CI consumes the new assets and proves them live.

## Provenance shapes

`seed.sh` verifies each download one of three ways, recorded in `tools.lock`:
`sha256` (hardcoded expected hash — Zig), `sha256_url` (upstream-published
hash fetched at seed time — uv), or neither (trust-on-first-use: the hash is
recorded into `SHA256SUMS` at seed time — Chrome, which Google publishes no
per-file checksum for). Whatever the shape, CI re-verifies every asset against
`SHA256SUMS` before extracting.

## Known boundary

The Linux leg still installs Chrome's shared libraries from the Ubuntu apt
mirror, and rodney comes from PyPI (pinned). Both are deliberate: apt and PyPI
are infrastructure we already trust elsewhere; the mirror exists to remove the
unpinned tarball-over-CDN downloads.
