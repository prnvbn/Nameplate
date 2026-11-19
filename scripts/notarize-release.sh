#!/bin/bash
set -euo pipefail

operation=${1:?Usage: notarize-release.sh submit|finalize DMG SUBMISSION_JSON, or status SUBMISSION_JSON}
case "$operation" in
  submit|finalize)
    archive=${2:?Set the DMG path}
    submission_file=${3:?Set the submission JSON path}
    ;;
  status) submission_file=${2:?Set the submission JSON path} ;;
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
  submission=$(/usr/bin/plutil -extract id raw "$submission_file")
  [[ "$submission" =~ ^[0-9a-fA-F-]{36}$ ]] || { echo 'Invalid submission ID' >&2; exit 1; }
  echo "Submission ID: $submission"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "submission_id=$submission" >> "$GITHUB_OUTPUT"
  fi
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo '## Apple notarization submission'
      echo
      echo 'Submission ID:'
      echo '```text'
      echo "$submission"
      echo '```'
      echo
      if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
        echo "[Check notarization](${GITHUB_SERVER_URL:-https://github.com}/$GITHUB_REPOSITORY/actions/workflows/check-notarization.yml) — click **Run workflow** and leave the input empty to check the newest release."
        echo
        echo 'Or check this exact submission from your terminal:'
        echo '```sh'
        echo "gh workflow run check-notarization.yml --repo $GITHUB_REPOSITORY --ref main -f submission_id=$submission"
        echo '```'
      fi
      echo
    } >> "$GITHUB_STEP_SUMMARY"
  fi
  (cd "$(dirname "$archive")" && shasum -a 256 "$(basename "$archive")" > "$(basename "$archive").sha256")
  exit 0
fi

# Check the original bytes before stapling modifies the DMG.
if [[ "$operation" == finalize ]]; then
  (cd "$(dirname "$archive")" && shasum -a 256 -c "$(basename "$archive").sha256")
fi
submission=$(/usr/bin/plutil -extract id raw "$submission_file")
[[ "$submission" =~ ^[0-9a-fA-F-]{36}$ ]] || { echo 'Invalid submission ID' >&2; exit 1; }
xcrun notarytool info "$submission" "${args[@]}" --output-format json > "$credentials/status.json"
status=$(/usr/bin/plutil -extract status raw "$credentials/status.json")
if [[ "$operation" == status ]]; then
  echo "Apple notarization status: $status"
  case "$status" in
    Accepted) next='Ready: approve Finalize release in the original release run.' ;;
    'In Progress') next='Apple is still processing. Run this check again later.' ;;
    *) next='Apple rejected the submission. See the diagnostics in this step.' ;;
  esac
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "## Apple notarization: $status"
      echo
      echo "Submission: \`$submission\`"
      echo
      echo "$next"
    } >> "$GITHUB_STEP_SUMMARY"
  fi
  echo "$next"
  if [[ "$status" != Accepted && "$status" != 'In Progress' ]]; then
    xcrun notarytool log "$submission" "${args[@]}" || true
    exit 1
  fi
  exit 0
fi
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
