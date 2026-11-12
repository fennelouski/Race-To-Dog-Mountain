#!/bin/bash
# Captures the 30 marketing scenes from the Debug Mac app at 1280 × 800 points (2560 × 1600 pixels).
# Usage: bash Tools/Screenshots/capture-mac.sh <output folder>
set -euo pipefail
cd "$(dirname "$0")/../.."
out="$1"; mkdir -p "$out"
app="build/mac-eval/Build/Products/Debug/Tally Tangle Mac.app/Contents/MacOS/Tally Tangle Mac"
helper=$(mktemp -d)/winid
xcrun swiftc Tools/Screenshots/window-id.swift -o "$helper"
for n in ${SCENES:-$(seq 1 30)}; do
  "$app" -MountainUITests -MountainTestSession "$(uuidgen)" -MountainMarketingCapture -MountainShowcase "$n" >/dev/null 2>&1 &
  pid=$!
  sleep 8
  id=$("$helper" "$pid")
  screencapture -x -o -l"$id" "$out/raw.png"
  kill "$pid"; wait "$pid" 2>/dev/null || true
  # Drop the title bar so the image is exactly the 1280 × 800 content area.
  python3 - "$out/raw.png" "$out/$(printf %02d "$n").png" <<'P'
import sys
from PIL import Image
im = Image.open(sys.argv[1]); w, h = im.size
im.crop((0, h - 1600, 2560, h)).save(sys.argv[2]) if w == 2560 and h >= 1600 else sys.exit(f'unexpected window size {w}x{h}')
P
  rm "$out/raw.png"
done
