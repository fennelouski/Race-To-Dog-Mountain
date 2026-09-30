#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TASK_ROOT"
TASK_WATCH_DEVICE="${TASK_WATCH_DEVICE:-$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); a=[v for k,vs in d["devices"].items() if "watchOS" in k for v in vs if v["isAvailable"]]; assert a,"Install a watchOS simulator runtime in Xcode"; print(next((v for v in a if v["state"]=="Booted"), next((v for v in a if "42mm" in v["name"]), a[-1]))["udid"])')}"
mkdir -p build/watch
if ! xcodebuild -project 'Race to Dog Mountain.xcodeproj' -scheme 'Race to Dog Mountain Watch' -configuration Debug -destination "platform=watchOS Simulator,id=$TASK_WATCH_DEVICE" -derivedDataPath build/watch build > build/watch/build.log 2>&1; then
    tail -60 build/watch/build.log >&2
    exit 1
fi
TASK_DEVICE_STATE="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; uid=sys.argv[1]; print(next(v["state"] for vs in json.load(sys.stdin)["devices"].values() for v in vs if v["udid"]==uid))' "$TASK_WATCH_DEVICE")"
if [[ "$TASK_DEVICE_STATE" != Booted ]]; then xcrun simctl boot "$TASK_WATCH_DEVICE"; fi
xcrun simctl bootstatus "$TASK_WATCH_DEVICE" -b
xcrun simctl terminate "$TASK_WATCH_DEVICE" com.nathanfennel.RacetoDogMountain.watchkitapp >/dev/null 2>&1 || true
xcrun simctl install "$TASK_WATCH_DEVICE" "$TASK_ROOT/build/watch/Build/Products/Debug-watchsimulator/Race to Dog Mountain Watch.app"
xcrun simctl launch "$TASK_WATCH_DEVICE" com.nathanfennel.RacetoDogMountain.watchkitapp
open -a Simulator --args -CurrentDeviceUDID "$TASK_WATCH_DEVICE"
