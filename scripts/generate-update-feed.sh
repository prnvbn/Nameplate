#!/bin/bash
set -euo pipefail

version=${1:?Set the release version}
notes=${2:?Set the release notes file}
: "${SPARKLE_PRIVATE_KEY:?Set the Sparkle private signing key}"
: "${GH_REPO:?Set the GitHub repository}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid release version' >&2; exit 1; }
archive="Nameplate-$version-macos-arm64.dmg"
tools=.build/artifacts/sparkle/Sparkle/bin
umask 077
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Use a dedicated directory so the unversioned DMG is not included twice.
cp "dist/$archive" "$work/$archive"
cp "$notes" "$work/${archive%.dmg}.md"
# Preserve previous feed entries, including updates for older macOS versions.
# A release without an appcast is expected when introducing Sparkle initially.
previous=$(gh release list --repo "$GH_REPO" --exclude-drafts --exclude-pre-releases \
  --limit 1 --json tagName --jq '.[0].tagName // empty')
if [[ -n "$previous" ]]; then
  assets=$(gh release view "$previous" --repo "$GH_REPO" --json assets --jq '.assets[].name')
  if printf '%s\n' "$assets" | grep -qx appcast.xml; then
    gh release download "$previous" --repo "$GH_REPO" --pattern appcast.xml --dir "$work"
  fi
fi

# Stapling changes the DMG bytes. Sign only the final, stapled archive.
# Supply the secret on stdin, never as a command-line argument or log output.
printf '%s' "$SPARKLE_PRIVATE_KEY" | "$tools/generate_appcast" \
  --ed-key-file - --maximum-deltas 0 --embed-release-notes \
  --download-url-prefix "https://github.com/$GH_REPO/releases/download/v$version/" \
  "$work"
# Do not publish an old feed if Sparkle skipped the new archive.
python3 - "$work/appcast.xml" "$version" "https://github.com/$GH_REPO/releases/download/v$version/$archive" "dist/$archive" <<'PYTHON'
import pathlib, sys, xml.etree.ElementTree as ET
feed, version, url, archive = sys.argv[1:]
namespace = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
for item in ET.parse(feed).findall('channel/item'):
    if item.findtext(namespace + 'version') != version:
        continue
    enclosure = item.find('enclosure')
    if (enclosure is not None and enclosure.get('url') == url
            and enclosure.get(namespace + 'edSignature')
            and enclosure.get('length') == str(pathlib.Path(archive).stat().st_size)):
        break
else:
    raise SystemExit('Appcast is missing the signed release archive; refusing to publish')
PYTHON
cp "$work/appcast.xml" dist/appcast.xml
