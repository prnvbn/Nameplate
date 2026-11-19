#!/bin/bash
set -euo pipefail

operation=${1:?Usage: notarize-release.sh submit|finalize DMG SUBMISSION_JSON}
archive=${2:?Set the DMG path}
submission_file=${3:?Set the submission JSON path}
case "$operation" in
  submit|finalize) ;;
  *) echo "Unknown operation: $operation" >&2; exit 1 ;;
esac
for name in APPLE_API_KEY APPLE_API_KEY_ID APPLE_API_ISSUER; do
  if [[ -z "${!name:-}" ]]; then
    echo "Missing notarization configuration: $name" >&2
    exit 1
  fi
done
umask 077
credentials=$(mktemp -d)
trap 'rm -rf "$credentials"' EXIT
printf '%s' "$APPLE_API_KEY" > "$credentials/notary.p8"
args=(--key "$credentials/notary.p8" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER")

if [[ "$operation" == submit ]]; then
  # No --wait: Apple processes the submission after this job exits.
  xcrun notarytool submit "$archive" "${args[@]}" --output-format json > "$submission_file"
  /usr/bin/plutil -extract id raw "$submission_file"
  (cd "$(dirname "$archive")" && shasum -a 256 "$(basename "$archive")" > "$(basename "$archive").sha256")
  exit 0
fi

# Check the original bytes before stapling modifies the DMG.
(cd "$(dirname "$archive")" && shasum -a 256 -c "$(basename "$archive").sha256")
submission=$(/usr/bin/plutil -extract id raw "$submission_file")
[[ "$submission" =~ ^[0-9a-fA-F-]{36}$ ]] || { echo 'Invalid submission ID' >&2; exit 1; }
xcrun notarytool info "$submission" "${args[@]}" --output-format json > "$credentials/status.json"
status=$(/usr/bin/plutil -extract status raw "$credentials/status.json")
case "$status" in
  Accepted) ;;
  'In Progress')
    echo 'Apple is still processing. Re-run failed jobs later; do not rebuild or resubmit.' >&2
    exit 1
    ;;
  *)
    xcrun notarytool log "$submission" "${args[@]}" || true
    echo "Notarization failed: $status" >&2
    exit 1
    ;;
esac
xcrun stapler staple "$archive"
xcrun stapler validate "$archive"
codesign --verify --strict --verbose "$archive"
hdiutil verify "$archive"
spctl --assess --type open --context context:primary-signature --verbose "$archive"
