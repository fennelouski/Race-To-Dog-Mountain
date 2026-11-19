#!/usr/bin/env bash
# Uses the signed-in Xcode account for automatic distribution signing.
set -euo pipefail
cd "$(dirname "$0")/../.."
if [[ $# -eq 0 ]]; then echo 'Usage: bash Tools/ReleaseChecks/upload-prepared.sh iOS|Mac|Vision|TV [...]' >&2; exit 2; fi
python3 Tools/ReleaseChecks/check-localizations.py
python3 Tools/ReleaseChecks/verify-archives.py
options=$(mktemp -t tally-export-options)
trap 'rm -f "$options"' EXIT
cat > "$options" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>destination</key><string>upload</string>
<key>signingStyle</key><string>automatic</string>
<key>uploadSymbols</key><true/>
<key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
PLIST
for platform in "$@"; do
 case "$platform" in iOS|Mac|Vision|TV) ;; *) echo "Unsupported platform: $platform" >&2; exit 2;; esac
 log_platform=$(printf '%s' "$platform" | tr '[:upper:]' '[:lower:]')
 variant=localized
 if [[ "$platform" == iOS ]]; then variant=watch-gc; fi
 xcodebuild -exportArchive -archivePath "build/release-20261117/Tally-$platform-$variant.xcarchive" \
  -exportPath "build/release-20261117/$platform-$variant-export" -exportOptionsPlist "$options" \
  -allowProvisioningUpdates 2>&1 | tee "build/release-20261117/$log_platform-$variant-upload.log"
done
