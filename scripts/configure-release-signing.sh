#!/bin/bash
set -euo pipefail
for name in CERTIFICATE_BASE64 CERTIFICATE_PASSWORD APPLE_API_KEY APPLE_API_KEY_ID APPLE_API_ISSUER APPLE_TEAM_ID; do
  if [[ -z "${!name:-}" ]]; then
    echo "::error::Missing signing configuration: $name. See RELEASING.md."
    exit 1
  fi
done
keychain="$RUNNER_TEMP/nameplate-signing.keychain-db"
certificate="$RUNNER_TEMP/nameplate-signing.p12"
api_key="$RUNNER_TEMP/nameplate-notary.p8"
umask 077
trap 'rm -f "$certificate" "$api_key"' EXIT
password=$(openssl rand -hex 32)
echo "::add-mask::$password"
printf '%s' "$CERTIFICATE_BASE64" | base64 --decode > "$certificate"
printf '%s' "$APPLE_API_KEY" > "$api_key"
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$certificate" -k "$keychain" -P "$CERTIFICATE_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" >/dev/null
identity=$(security find-identity -v -p codesigning "$keychain" | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p')
if [[ -z "$identity" || "$identity" == *$'\n'* || "$identity" != *"($APPLE_TEAM_ID)" ]]; then
  echo '::error::Expected one valid Developer ID Application identity matching APPLE_TEAM_ID.'
  exit 1
fi
xcrun notarytool store-credentials nameplate-release --keychain "$keychain" \
  --key "$api_key" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER"
{
  echo "SIGNING_IDENTITY=$identity"
  echo "SIGNING_KEYCHAIN=$keychain"
  echo 'NOTARY_KEYCHAIN_PROFILE=nameplate-release'
} >> "$GITHUB_ENV"
