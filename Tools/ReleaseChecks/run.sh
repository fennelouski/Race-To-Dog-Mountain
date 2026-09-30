#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
output=$(mktemp -d)
trap 'rm -rf "$output"' EXIT
xcrun swiftc -parse-as-library -D DOGMOUNTAIN_CHECKS "Race to Dog Mountain/MountainGame.swift" -o "$output/check"
"$output/check"
python3 Tools/ReleaseChecks/check-computer-turn.py
xcrun swiftc -parse-as-library "Race to Dog Mountain/MountainGame.swift" Watch/WatchMatch.swift Tools/ReleaseChecks/watch-match-check.swift -o "$output/watch-check"
"$output/watch-check"
