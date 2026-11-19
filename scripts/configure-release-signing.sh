#!/bin/bash
set -euo pipefail
for name in APPLE_CERTIFICATE_BASE64 APPLE_CERTIFICATE_PASSWORD APPLE_TEAM_ID; do
  if [[ -z "${!name:-}" ]]; then
    echo "::error::Missing signing configuration: $name. Configure this repository secret."
    exit 1
  fi
done
keychain="$RUNNER_TEMP/nameplate-signing.keychain-db"
certificate="$RUNNER_TEMP/nameplate-signing.p12"
umask 077
trap 'rm -f "$certificate"' EXIT
password=$(openssl rand -hex 32)
echo "::add-mask::$password"
printf '%s' "$APPLE_CERTIFICATE_BASE64" | base64 --decode > "$certificate"
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$certificate" -k "$keychain" -P "$APPLE_CERTIFICATE_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" >/dev/null
identity=$(security find-identity -v -p codesigning "$keychain" | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p')
if [[ -z "$identity" || "$identity" == *$'\n'* || "$identity" != *"($APPLE_TEAM_ID)" ]]; then
  echo '::error::Expected one valid Developer ID Application identity matching APPLE_TEAM_ID.'
  exit 1
fi
{
  echo "SIGNING_IDENTITY=$identity"
  echo "SIGNING_KEYCHAIN=$keychain"
} >> "$GITHUB_ENV"
