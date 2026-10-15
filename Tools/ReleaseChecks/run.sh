#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
output=$(mktemp -d)
trap 'rm -rf "$output"' EXIT
xcrun swiftc -parse-as-library -D DOGMOUNTAIN_CHECKS "Race to Dog Mountain/MountainGame.swift" -o "$output/check"
"$output/check"
python3 Tools/ReleaseChecks/check-computer-turn.py
python3 Tools/ReleaseChecks/check-move-feedback.py
xcrun swiftc -parse-as-library "Race to Dog Mountain/MountainGame.swift" Tools/ReleaseChecks/avatar-motion-check.swift -o "$output/avatar-motion-check"
"$output/avatar-motion-check"
xcrun swiftc -parse-as-library "Race to Dog Mountain/MountainGame.swift" Watch/WatchMatch.swift Tools/ReleaseChecks/watch-match-check.swift -o "$output/watch-check"
"$output/watch-check"
xcrun swiftc -parse-as-library -target "$(uname -m)-apple-macos14.0" "Race to Dog Mountain/MountainGame.swift" "Race to Dog Mountain/MountainMatches.swift" "Race to Dog Mountain/MountainLibrary.swift" Tools/ReleaseChecks/social-match-check.swift -o "$output/social-check"
"$output/social-check"
xcrun swiftc -parse-as-library -target "$(uname -m)-apple-macos14.0" "Race to Dog Mountain/MountainGame.swift" "Race to Dog Mountain/MountainMatches.swift" "Race to Dog Mountain/MountainLibrary.swift" Tools/ReleaseChecks/adaptive-check.swift -o "$output/adaptive-check"
"$output/adaptive-check"
xcrun swiftc -parse-as-library "Race to Dog Mountain/MountainGame.swift" Tools/ReleaseChecks/board-layout-check.swift -o "$output/board-check"
"$output/board-check"
xcrun swiftc -parse-as-library -D DEBUG -target "$(uname -m)-apple-macos14.0" "Race to Dog Mountain/MountainGame.swift" "Race to Dog Mountain/MountainMatches.swift" Tools/ReleaseChecks/native-finish-check.swift -o "$output/native-finish-check"
"$output/native-finish-check" -MountainUITests -MountainTestSession "$(uuidgen)"
python3 Tools/ReleaseChecks/check-pinned-layout.py

xcrun swiftc -parse-as-library "Race to Dog Mountain/MountainGame.swift" "Race to Dog Mountain/MountainMatches.swift" Tools/ReleaseChecks/experience-check.swift -o "$output/experience-check"
"$output/experience-check"

xcrun swiftc -parse-as-library "Race to Dog Mountain/MountainGame.swift" "Race to Dog Mountain/MountainFonster.swift" "Race to Dog Mountain/MountainFuzzyPortrait.swift" "Race to Dog Mountain/MountainScenery.swift" Tools/ReleaseChecks/avatar-photo-check.swift -o "$output/avatar-photo-check"
"$output/avatar-photo-check" "$output/avatars.png"
xcrun swiftc -parse-as-library "Race to Dog Mountain/MountainGame.swift" "Race to Dog Mountain/MountainFonster.swift" "Race to Dog Mountain/MountainFuzzyPortrait.swift" "Race to Dog Mountain/MountainScenery.swift" Tools/ReleaseChecks/avatar-live-render-check.swift -o "$output/avatar-live-check"
"$output/avatar-live-check" "$output"
