#!/bin/bash
# Captures the 30 marketing scenes from the Debug Mac app at 1280 × 800 points (2560 × 1600 pixels).
# Usage: bash Tools/Screenshots/capture-mac.sh <output folder>
set -euo pipefail
cd "$(dirname "$0")/../.."
out="$1"; mkdir -p "$out"
app="${MAC_APP_BUNDLE:-build/mac/Build/Products/Debug/Tally Tangle Mac.app}"
python="${PYTHON_BIN:-python3}"
test -d "$app" || { echo "Build the Debug Mac app with script/build_and_run.sh or set MAC_APP_BUNDLE." >&2; exit 1; }
"$python" -c 'from PIL import Image' || { echo "Set PYTHON_BIN to a Python installation with Pillow." >&2; exit 1; }
helper=$(mktemp -d)/winid
xcrun swiftc Tools/Screenshots/window-id.swift -o "$helper"
for n in ${SCENES:-$(seq 1 30)}; do
  session=$(uuidgen)
  open -n "$app" --args -MountainUITests -MountainTestSession "$session" -MountainMarketingCapture -MountainShowcase "$n"
  sleep 8
  pid=$(pgrep -nf "MountainTestSession $session" || true)
  test -n "$pid" || { echo "The private Mac capture app did not launch." >&2; exit 1; }
  id=$("$helper" "$pid")
  screencapture -x -o -l"$id" "$out/raw.png"
  kill "$pid"; wait "$pid" 2>/dev/null || true
  # Drop the title bar so the image is exactly the 1280 × 800 content area.
  "$python" - "$out/raw.png" "$out/$(printf %02d "$n").png" <<'P'
import sys
from PIL import Image
im = Image.open(sys.argv[1]); w, h = im.size
im.crop((0, h - 1600, 2560, h)).save(sys.argv[2]) if w == 2560 and h >= 1600 else sys.exit(f'unexpected window size {w}x{h}')
P
  rm "$out/raw.png"
done
