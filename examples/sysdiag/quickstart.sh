#!/usr/bin/env bash
# One-shot contributor proof for sysdiag:
#   1. setup  — fetch pinned Zig/uv/Chrome from the `ci-tools` release (see ../../scaffolding/ci/README.md)
#   2. build  — zig build, then boot the server on :3000
#   3. photo  — rodney (headless Chrome) screenshots the live dashboard
#
#   cd sysdiag && ./quickstart.sh
#
# Tools already on PATH are reused; anything missing is downloaded into
# sysdiag/.tools/ (gitignored, ~250 MB first run, cached after). The only
# install outside the repo is `uv tool install rodney` if rodney is absent.
# Needs: bash, curl, python3, shasum, tar, unzip — stock on macOS and Ubuntu.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
cd "$here"
lock="$here/../../scaffolding/ci/tools.lock"
tools="$here/.tools"
mkdir -p "$tools"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)        plat=linux-x86_64 ;;
  Darwin-arm64)        plat=macos-aarch64 ;;
  *) echo "unsupported platform $(uname -s)-$(uname -m) (sysdiag supports linux-x86_64 and macos-aarch64)" >&2; exit 1 ;;
esac

# Read everything we need from the lock in one go (asset names contain no spaces).
read -r tag zig_asset uv_asset chrome_asset rodney_ver < <(python3 -c "
import json
d = json.load(open('$lock')); t = d['tools']
print(d['release_tag'], *[t[k]['platforms']['$plat']['asset'] for k in ('zig', 'uv', 'chrome')], t['rodney']['version'])
")
base="https://github.com/TanGentleman/tracers/releases/download/$tag"

# Download a release asset into .tools/ (once) and verify it against SHA256SUMS.
# Progress goes to stderr: callers capture stdout (see install_tarball).
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

# Fetch + extract a tool tarball (whose top-level dir name varies) into .tools/
# under a dir named after the asset; prints that dir. Cached after the first run.
install_tarball() { # install_tarball <asset> <ext>
  local asset=$1 ext=$2
  local dir="$tools/${asset%$ext}"
  if [ ! -d "$dir" ]; then
    fetch "$asset"
    tar -xf "$tools/$asset" -C "$tools"
    # the tarball's top-level dir name differs from the asset name; normalize it
    mv "$(find "$tools" -maxdepth 1 -type d -name "${asset%%-*}-*" ! -name "$(basename "$dir")" | head -n1)" "$dir"
  fi
  echo "$dir"
}

echo "== 1/3 setup =="

# Zig: any 0.17.0-dev on PATH works (spider's floor); otherwise use the pinned nightly.
if zig version 2>/dev/null | grep -q '^0\.17\.0-dev'; then
  echo ">> using zig $(zig version) from PATH"
else
  zig_dir=$(install_tarball "$zig_asset" .tar.xz)
  export PATH="$zig_dir:$PATH"
  echo ">> using pinned zig $(zig version)"
fi

# uv: reuse if present (brew install uv works fine); otherwise use the pinned one.
if ! command -v uv >/dev/null; then
  uv_dir=$(install_tarball "$uv_asset" .tar.gz)
  export PATH="$uv_dir:$PATH"
fi
echo ">> uv $(uv --version | awk '{print $2}')"

# rodney: pinned install via uv (no-op if already installed).
if ! command -v rodney >/dev/null; then
  uv tool install "rodney==$rodney_ver"
  export PATH="$HOME/.local/bin:$PATH"
fi
echo ">> rodney $(rodney --version 2>/dev/null || echo installed)"

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

# The PATH/env exports above die with this script. Write them to a sourceable
# file so the same tools work in an interactive shell (zig build, rodney, …).
{
  if [ -n "${zig_dir:-}" ]; then echo "export PATH=\"$zig_dir:\$PATH\""; fi
  if [ -n "${uv_dir:-}" ]; then echo "export PATH=\"$uv_dir:\$PATH\""; fi
  echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo "export ROD_CHROME_BIN=\"$ROD_CHROME_BIN\""
} > "$tools/env"

echo "== 2/3 build & run =="
zig build

./zig-out/bin/sysdiag > "$tools/server.log" 2>&1 &
server_pid=$!
cleanup() { kill "$server_pid" 2>/dev/null || true; rodney stop 2>/dev/null || true; }
trap cleanup EXIT

for _ in $(seq 1 40); do
  curl -sf http://127.0.0.1:3000/up >/dev/null && break
  sleep 0.5
done
curl -sf http://127.0.0.1:3000/up >/dev/null || { echo "server did not come up:"; cat "$tools/server.log"; exit 1; }
echo ">> server up on http://127.0.0.1:3000"

echo "== 3/3 screenshot =="
# Directory-scoped, fresh-each-run browser session: immune to (and isolated
# from) any global ~/.rodney state. Commands auto-detect ./.rodney once started.
rm -rf "$here/.rodney"
rodney start --local
rodney open http://127.0.0.1:3000/
rodney waitidle
rodney sleep 3   # let one 2s HTMX poll replace the "Loading…" card
rodney screenshot -w 1100 -h 680 "$here/quickstart.png"
rodney stop

echo
echo "OK — live dashboard captured at sysdiag/quickstart.png"
echo "Put the same tools on your PATH:  source .tools/env"
echo "Then hack away: zig build && ./zig-out/bin/sysdiag, and open http://127.0.0.1:3000"
