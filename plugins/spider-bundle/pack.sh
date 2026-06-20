#!/usr/bin/env bash
# pack.sh — assemble a self-contained "spider-bundle" (the spider skill + a
# vendored tools.lock) to share the workflow with friends who lack this repo.
#
#   plugins/spider-bundle/pack.sh [out-dir]      (default: ./spider-bundle)
#
# Nothing in the bundle points back here; pinned binaries still come from the
# public `ci-tools` release (network, not a checkout). See README.md for detail.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=$(git -C "$here" rev-parse --show-toplevel)
skills="$repo/skills"
lock="$repo/scaffolding/ci/tools.lock"
out=${1:-"$PWD/spider-bundle"}

for p in "$skills/spider" "$lock"; do
  [ -e "$p" ] || { echo "missing source: $p" >&2; exit 1; }
done

rm -rf "$out"
mkdir -p "$out"
cp -r "$skills/spider" "$out/spider"

# Vendor the pinned versions inside the skill and repoint the lookup at them, so
# the bundle never reaches back into this repo's scaffolding/ tree.
cp "$lock" "$out/spider/tools.lock"
tmp=$(mktemp)
sed 's#^lock=.*#lock="$skill_dir/tools.lock"#' "$out/spider/prove.sh" > "$tmp"
mv "$tmp" "$out/spider/prove.sh"
chmod +x "$out/spider/prove.sh"

cat > "$out/README.md" <<'EOF'
# spider-bundle

Build, run, and prove a [spider](https://github.com/llllOllOOll/spider) + HTMX
web app in Zig — from nothing to a screenshotted demo — with one command. No
manual toolchain setup.

## Install

Copy the skill into your Claude Code skills dir:

```sh
cp -r spider ~/.claude/skills/
```

Then run it directly to prove the toolchain works end-to-end:

```sh
~/.claude/skills/spider/prove.sh            # full demo (builds + screenshots)
~/.claude/skills/spider/prove.sh --no-demo  # fast: just scaffold + build
```

## Build your own app

With the skill installed, just tell Claude what you want — e.g. *"build a recipe
generator web app with spider"*. Claude scaffolds from the known-good template,
writes your routes in Zig, and **re-authors the demo against your endpoints**
(rodney screenshots the live page, showboat captures your real requests into a
`demo/demo.md`). You read the README, run one command, and ask for an app.

## What you need

`bash, curl, git, python3, tar, unzip` (stock on macOS and Ubuntu), plus
network — the pinned Zig/uv/Chrome are fetched and checksum-verified on first
run and cached in `<target>/.tools/`. Supports linux-x86_64 and macOS arm64.

The pinned versions live in `spider/tools.lock`; see `spider/SKILL.md` for the
full playbook (API cheatsheet, gotchas, and the prove-it lifecycle).
EOF

if command -v zip >/dev/null; then
  ( cd "$(dirname "$out")" && zip -qr "$(basename "$out").zip" "$(basename "$out")" )
  echo "bundle: $out  (+ $out.zip)"
else
  echo "bundle: $out  (install zip for a shareable archive)"
fi
