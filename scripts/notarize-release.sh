#!/bin/bash
set -euo pipefail

archive=$1
app=$2
: "${NOTARY_KEYCHAIN_PROFILE:?Set NOTARY_KEYCHAIN_PROFILE}"
args=(--keychain-profile "$NOTARY_KEYCHAIN_PROFILE")
if [[ -n "${SIGNING_KEYCHAIN:-}" ]]; then
  args+=(--keychain "$SIGNING_KEYCHAIN")
fi
result=$(mktemp)
trap 'rm -f "$result"' EXIT
xcrun notarytool submit "$archive" "${args[@]}" --wait --output-format json > "$result"
status=$(/usr/bin/plutil -extract status raw "$result")
if [[ "$status" != Accepted ]]; then
  submission=$(/usr/bin/plutil -extract id raw "$result")
  xcrun notarytool log "$submission" "${args[@]}" || true
  echo "Notarization failed: $status" >&2
  exit 1
fi
xcrun stapler staple "$app"
xcrun stapler validate "$app"
