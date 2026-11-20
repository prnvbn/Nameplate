#!/bin/bash
set -euo pipefail
app=${1:?Set the app bundle path}
identity=${SIGNING_IDENTITY:--}
args=(--force --sign "$identity")
if [[ "$identity" != - ]]; then
  args+=(--options runtime --timestamp)
  if [[ -n "${SIGNING_KEYCHAIN:-}" ]]; then args+=(--keychain "$SIGNING_KEYCHAIN"); fi
fi
framework="$app/Contents/Frameworks/Sparkle.framework"
# Sign nested code inside out, preserving framework symlinks.
for component in \
  Versions/B/XPCServices/Downloader.xpc \
  Versions/B/XPCServices/Installer.xpc \
  Versions/B/Autoupdate \
  Versions/B/Updater.app; do
  codesign "${args[@]}" "$framework/$component"
done
codesign "${args[@]}" "$framework"
codesign "${args[@]}" "$app"
codesign --verify --deep --strict "$app"
