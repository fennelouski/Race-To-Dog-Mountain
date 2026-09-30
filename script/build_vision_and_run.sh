#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TASK_ROOT"
TASK_VISION_DEVICE="${TASK_VISION_DEVICE:-$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); a=[v for k,vs in d["devices"].items() if "xrOS" in k for v in vs if v["isAvailable"]]; assert a,"Install a visionOS simulator runtime in Xcode"; print(next((v for v in a if v["state"]=="Booted"), a[-1])["udid"])')}"
mkdir -p build/vision
if ! xcodebuild -project 'Race to Dog Mountain.xcodeproj' -scheme 'Race to Dog Mountain Vision' -configuration Debug -destination "platform=visionOS Simulator,id=$TASK_VISION_DEVICE" -derivedDataPath build/vision build > build/vision/build.log 2>&1; then
    tail -60 build/vision/build.log >&2
    exit 1
fi
TASK_DEVICE_STATE="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; uid=sys.argv[1]; print(next(v["state"] for vs in json.load(sys.stdin)["devices"].values() for v in vs if v["udid"]==uid))' "$TASK_VISION_DEVICE")"
if [[ "$TASK_DEVICE_STATE" != Booted ]]; then xcrun simctl boot "$TASK_VISION_DEVICE"; fi
xcrun simctl bootstatus "$TASK_VISION_DEVICE" -b
xcrun simctl terminate "$TASK_VISION_DEVICE" com.nathanfennel.RacetoDogMountain >/dev/null 2>&1 || true
xcrun simctl install "$TASK_VISION_DEVICE" "$TASK_ROOT/build/vision/Build/Products/Debug-xrsimulator/Race to Dog Mountain Vision.app"
xcrun simctl launch "$TASK_VISION_DEVICE" com.nathanfennel.RacetoDogMountain
open -a Simulator --args -CurrentDeviceUDID "$TASK_VISION_DEVICE"
