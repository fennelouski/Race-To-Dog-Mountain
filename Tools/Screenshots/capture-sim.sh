#!/bin/bash
# Captures the 30 marketing scenes on a simulator.
# Usage: [DISPLAY_ID=n] [WAIT=s] bash Tools/Screenshots/capture-sim.sh <simulator udid> <app bundle path> <bundle id> <output folder>
set -euo pipefail
udid="$1"; app="$2"; bundle="$3"; out="$4"
mkdir -p "$out"
xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b >/dev/null
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 2>/dev/null || true
xcrun simctl install "$udid" "$app"
launch_scene() {
  # tvOS can return to SpringBoard after --terminate-running-process races activation.
  xcrun simctl terminate "$udid" "$bundle" >/dev/null 2>&1 || true
  sleep "${RELAUNCH_GAP:-1}"
  xcrun simctl launch "$udid" "$bundle" -MountainUITests -MountainTestSession "$(uuidgen)" -MountainMarketingCapture -MountainShowcase "$1" >/dev/null
}
# Warm-up launch: the first launch after install can still be compiling shaders when it's captured.
launch_scene 4
sleep 15
for n in ${SCENES:-$(seq 1 30)}; do
  launch_scene "$n"
  sleep "${WAIT:-9}"
  # DISPLAY picks a screen on multi-display devices: iPhone Duo's outer screen is 1, its inner screen 3.
  xcrun simctl io "$udid" screenshot ${DISPLAY_ID:+--display=$DISPLAY_ID} "$out/$(printf %02d "$n").png" >/dev/null 2>&1
done
xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true
