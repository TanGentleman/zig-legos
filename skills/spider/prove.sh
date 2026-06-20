#!/usr/bin/env bash
# prove.sh — zero-to-demo lifecycle for a spider + HTMX app.
#
#   1. setup     — ensure a spider-capable Zig (0.17.0-dev) + uv (and, for the
#                  demo, rodney + showboat + a headless Chrome)
#   2. scaffold  — copy this spider skill's template into <target> (if absent)
#   3. build/run — zig build, boot the server on :3000, wait for /up
#   4. photo     — rodney (headless Chrome) drives the page and screenshots it
#   5. demo      — showboat captures a concise, real-output demo + the screenshot
#
#   skills/spider/prove.sh [--no-demo] [target-dir]
#                                        (default target: ./spider-app-demo)
#
#   --no-demo stops after build/run — no screenshot, demo, Chrome, rodney, or
#   showboat — for a fast, browser-free "just scaffold and build it" loop.
#
# Tools already on PATH are reused; anything missing is pulled from the repo's
# pinned `ci-tools` release (the same one the examples use) and checksum-verified
# into <target>/.tools/ (gitignored). The only installs outside the target are
# `uv tool install` for rodney and showboat (both pinned), used by the demo.
# Needs: bash, curl, git, python3, shasum, tar, unzip — stock on macOS and Ubuntu.
set -euo pipefail

do_demo=true
target=""
for arg in "$@"; do
  case "$arg" in
    --no-demo)  do_demo=false ;;
    -h|--help)  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)         echo "unknown flag: $arg (try --no-demo, --help)" >&2; exit 1 ;;
    *)          target=$arg ;;
  esac
done

skill_dir=$(cd "$(dirname "$0")" && pwd)
repo=$(git -C "$skill_dir" rev-parse --show-toplevel 2>/dev/null) || repo=$(cd "$skill_dir/../.." && pwd)
template="$skill_dir/templates/app"
lock="$repo/scaffolding/ci/tools.lock"

target=${target:-spider-app-demo}
mkdir -p "$target"
target=$(cd "$target" && pwd)
tools="$target/.tools"
mkdir -p "$tools"

[ -d "$template" ] || { echo "spider template missing at $template" >&2; exit 1; }
[ -f "$lock" ]     || { echo "tools lock missing at $lock" >&2; exit 1; }

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) plat=linux-x86_64 ;;
  Darwin-arm64) plat=macos-aarch64 ;;
  *) echo "unsupported platform $(uname -s)-$(uname -m) (supports linux-x86_64, macos-aarch64)" >&2; exit 1 ;;
esac

read -r tag zig_asset uv_asset chrome_asset rodney_ver showboat_ver < <(python3 -c "
import json
d = json.load(open('$lock')); t = d['tools']
print(d['release_tag'], *[t[k]['platforms']['$plat']['asset'] for k in ('zig', 'uv', 'chrome')], t['rodney']['version'], t['showboat']['version'])
")
base="https://github.com/TanGentleman/tracers/releases/download/$tag"

# Demo runs 5 steps; --no-demo stops after build/run (3 steps).
total=5; $do_demo || total=3

# Download a release asset into .tools/ (once) and verify against SHA256SUMS.
fetch() { # fetch <asset>
  local asset=$1
  [ -f "$tools/SHA256SUMS" ] || curl -fsSL "$base/SHA256SUMS" -o "$tools/SHA256SUMS"
  if [ ! -f "$tools/$asset" ]; then
    echo ">> downloading $asset" >&2
    curl -fL --progress-bar "$base/$asset" -o "$tools/$asset.part"
    mv "$tools/$asset.part" "$tools/$asset"
  fi
  local exp act
  exp=$(awk -v f="$asset" '$2 == f {print $1}' "$tools/SHA256SUMS")
  [ -n "$exp" ] || { echo "no checksum for $asset in SHA256SUMS" >&2; exit 1; }
  act=$(shasum -a 256 "$tools/$asset" | awk '{print $1}')
  [ "$exp" = "$act" ] || { echo "checksum mismatch for $asset ($exp != $act)" >&2; exit 1; }
  echo "   verified $asset" >&2
}

# Fetch + extract a tool tarball (top-level dir name varies) into .tools/ under a
# dir named after the asset; prints that dir. Cached after the first run.
install_tarball() { # install_tarball <asset> <ext>
  local asset=$1 ext=$2
  local dir="$tools/${asset%$ext}"
  if [ ! -d "$dir" ]; then
    fetch "$asset"
    tar -xf "$tools/$asset" -C "$tools"
    mv "$(find "$tools" -maxdepth 1 -type d -name "${asset%%-*}-*" ! -name "$(basename "$dir")" | head -n1)" "$dir"
  fi
  echo "$dir"
}

echo "== 1/$total setup =="

# Zig: any 0.17.0-dev on PATH clears spider's floor; otherwise use the pinned nightly.
if zig version 2>/dev/null | grep -q '^0\.17\.0-dev'; then
  echo ">> using zig $(zig version) from PATH"
else
  zig_dir=$(install_tarball "$zig_asset" .tar.xz)
  export PATH="$zig_dir:$PATH"
  echo ">> using pinned zig $(zig version)"
fi

# uv: reuse if present; otherwise use the pinned one.
if ! command -v uv >/dev/null; then
  uv_dir=$(install_tarball "$uv_asset" .tar.gz)
  export PATH="$uv_dir:$PATH"
fi
echo ">> uv $(uv --version | awk '{print $2}')"
export PATH="$HOME/.local/bin:$PATH"

if $do_demo; then
  # rodney + showboat (both pinned): uv tool install is a no-op when present.
  command -v rodney   >/dev/null || uv tool install "rodney==$rodney_ver"
  command -v showboat >/dev/null || uv tool install "showboat==$showboat_ver"
  echo ">> rodney $(rodney --version 2>/dev/null || echo installed) · showboat $(showboat --version 2>/dev/null || echo installed)"

  # Chrome: respect ROD_CHROME_BIN, then a system Chrome, then the pinned one.
  if [ -z "${ROD_CHROME_BIN:-}" ]; then
    for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
             /usr/bin/google-chrome /usr/bin/chromium /usr/bin/chromium-browser; do
      [ -x "$c" ] && export ROD_CHROME_BIN="$c" && break
    done
  fi
  if [ -z "${ROD_CHROME_BIN:-}" ]; then
    if [ "$plat" = linux-x86_64 ]; then
      chrome_bin="$tools/chrome-linux64/chrome"
    else
      chrome_bin="$tools/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing"
    fi
    if [ ! -x "$chrome_bin" ]; then
      fetch "$chrome_asset"
      unzip -q "$tools/$chrome_asset" -d "$tools"
    fi
    export ROD_CHROME_BIN="$chrome_bin"
  fi
  echo ">> chrome: $ROD_CHROME_BIN"
fi

# Persist the env so the same tools work in an interactive shell afterwards.
{
  if [ -n "${zig_dir:-}" ]; then echo "export PATH=\"$zig_dir:\$PATH\""; fi
  if [ -n "${uv_dir:-}" ];  then echo "export PATH=\"$uv_dir:\$PATH\""; fi
  echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
  if $do_demo; then echo "export ROD_CHROME_BIN=\"$ROD_CHROME_BIN\""; fi
} > "$tools/env"

echo "== 2/$total scaffold =="
# Idempotent: only lay down the known-good template if the app is absent.
if [ -e "$target/build.zig" ]; then
  echo ">> reusing existing app at $target"
else
  cp -r "$template/." "$target/"
  echo ">> scaffolded spider + HTMX starter into $target"
fi
# Keep the heavy/transient artifacts out of version control so a default run in
# the repo stays clean. Written only if absent — never clobbers a real project's.
[ -e "$target/.gitignore" ] || cat > "$target/.gitignore" <<'EOF'
.tools/
.rodney/
zig-out/
.zig-cache/
.env
EOF
cd "$target"

echo "== 3/$total build & run =="
zig build

./zig-out/bin/app > "$tools/server.log" 2>&1 &
server_pid=$!
cleanup() { kill "$server_pid" 2>/dev/null || true; rodney stop 2>/dev/null || true; }
trap cleanup EXIT

for _ in $(seq 1 40); do
  curl -sf http://127.0.0.1:3000/up >/dev/null && break
  sleep 0.5
done
curl -sf http://127.0.0.1:3000/up >/dev/null || { echo "server did not come up:"; cat "$tools/server.log"; exit 1; }
echo ">> server up on http://127.0.0.1:3000"

if ! $do_demo; then
  echo
  echo "OK — built and serving on http://127.0.0.1:3000 (--no-demo: skipped screenshot + demo)"
  echo "Put the same tools on your PATH:  source $tools/env"
  echo "Then iterate: zig build && ./zig-out/bin/app, and open http://127.0.0.1:3000"
  exit 0
fi

echo "== 4/$total screenshot =="
mkdir -p "$target/demo"
shot="$target/demo/shot.png"
# Directory-scoped, fresh-each-run browser session: isolated from any global state.
rm -rf "$target/.rodney"
rodney start --local
rodney open http://127.0.0.1:3000/
rodney waitidle
# Exercise an HTMX round-trip before the capture *if* the page has a button — the
# starter does; a custom app may not, and a missing one must not abort the run.
if [ -n "$(rodney html 'button' 2>/dev/null)" ]; then
  rodney click "button"
  rodney waitidle
fi
rodney screenshot -w 800 -h 460 "$shot"
rodney stop

echo "== 5/$total demo =="
# The health probe always holds; /clicked is the starter's route, so include it
# only while the app still serves it. For a custom app, re-author these probes
# against your own endpoints — see this skill's SKILL.md "Prove it".
demo="$target/demo/demo.md"
rm -f "$demo"
showboat init "$demo" "spider + HTMX app — proven live"
showboat exec "$demo" bash "curl -s localhost:3000/up; echo"
if curl -sf -o /dev/null localhost:3000/clicked; then
  showboat exec "$demo" bash "curl -s localhost:3000/clicked; echo"
fi
showboat image "$demo" "![spider + HTMX app]($shot)"   # absolute: showboat resolves from its CWD, then copies next to demo.md

echo
echo "OK — demo at $demo, screenshot at $shot"
echo "This demo proves the starter routes. Building your own app? Re-author"
echo "$demo against your endpoints — see this skill's \"Prove it\" section."
echo "Put the same tools on your PATH:  source $tools/env"
echo "Then iterate: zig build && ./zig-out/bin/app, and open http://127.0.0.1:3000"
