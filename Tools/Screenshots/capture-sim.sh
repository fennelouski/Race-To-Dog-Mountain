#!/bin/bash
# Captures the 30 marketing scenes on a simulator.
# Usage: bash Tools/Screenshots/capture-sim.sh <simulator udid> <app bundle path> <bundle id> <output folder>
set -euo pipefail
udid="$1"; app="$2"; bundle="$3"; out="$4"
mkdir -p "$out"
xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b >/dev/null
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 2>/dev/null || true
xcrun simctl install "$udid" "$app"
# Warm-up launch: the first launch after install can still be compiling shaders when it's captured.
xcrun simctl launch --terminate-running-process "$udid" "$bundle" -MountainUITests -MountainTestSession "$(uuidgen)" -MountainMarketingCapture -MountainShowcase 4 >/dev/null
sleep 15
for n in ${SCENES:-$(seq 1 30)}; do
  xcrun simctl launch --terminate-running-process "$udid" "$bundle" \
    -MountainUITests -MountainTestSession "$(uuidgen)" -MountainMarketingCapture -MountainShowcase "$n" >/dev/null
  sleep "${WAIT:-9}"
  xcrun simctl io "$udid" screenshot "$out/$(printf %02d "$n").png" >/dev/null 2>&1
done
xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true
