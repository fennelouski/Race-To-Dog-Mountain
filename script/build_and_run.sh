#!/usr/bin/env bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TASK_ROOT"
MODE="${1:-run}"
APP_NAME="Race to Dog Mountain Mac"
APP_BUNDLE="$TASK_ROOT/build/mac/Build/Products/Debug/$APP_NAME.app"
case "$MODE" in run|--verify|--debug|--logs|--telemetry) ;; *) echo "Usage: $0 [--verify|--debug|--logs|--telemetry]" >&2; exit 2;; esac
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
mkdir -p build/mac
if ! xcodebuild -project 'Race to Dog Mountain.xcodeproj' -scheme "$APP_NAME" -configuration Debug -destination 'platform=macOS' -derivedDataPath build/mac build > build/mac/build.log 2>&1; then
    tail -60 build/mac/build.log >&2
    exit 1
fi
if [[ "$MODE" == --debug ]]; then
    exec lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
fi
/usr/bin/open -n "$APP_BUNDLE"
case "$MODE" in
    --verify) sleep 2; pgrep -x "$APP_NAME" >/dev/null ;;
    --logs) exec /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"" ;;
    --telemetry) exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.nathanfennel.RacetoDogMountain"' ;;
esac
echo "Built and opened $APP_BUNDLE"
