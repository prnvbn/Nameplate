"""Refresh embedded notes for every version in a published release's appcast."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
from xml.dom import minidom


SPARKLE_NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"


def gh(*arguments):
    return subprocess.check_output(["gh", *arguments], text=True)


def release(tag):
    arguments = ["release", "view"]
    if tag:
        arguments.append(tag)
    return json.loads(gh(*arguments, "--json", "tagName,body,isDraft,isPrerelease"))


def refresh_notes(feed, load_notes):
    document = minidom.parseString(feed)
    versions = []
    for item in document.getElementsByTagName("item"):
        version_element, = item.getElementsByTagNameNS(SPARKLE_NAMESPACE, "version")
        version = "".join(node.data for node in version_element.childNodes).strip()
        if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
            raise ValueError(f"Unexpected appcast version: {version!r}")
        notes = re.sub(
            r"<!-- nameplate-notarization:start -->.*?<!-- nameplate-notarization:end -->\n?",
            "", load_notes(f"v{version}"), flags=re.DOTALL,
        ).strip()
        if not notes or "TODO: Add release notes" in notes:
            raise ValueError(f"Release v{version} has empty or placeholder notes")
        descriptions = item.getElementsByTagName("description")
        if len(descriptions) != 1:
            raise ValueError(f"Expected one description for v{version}")
        description = descriptions[0]
        for node in list(description.childNodes):
            description.removeChild(node)
        description.setAttributeNS(SPARKLE_NAMESPACE, "sparkle:format", "markdown")
        # XML escaping also handles notes containing CDATA terminators such as ]]>.
        description.appendChild(document.createTextNode("\n" + notes + "\n"))
        versions.append(version)
    if not versions:
        raise ValueError("Appcast contains no releases")
    return document.toxml(encoding="utf-8"), versions


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", default="", help="Defaults to the latest stable release")
    parser.add_argument("--dry-run", action="store_true", help="Validate without uploading")
    arguments = parser.parse_args()
    target = release(arguments.tag)
    if target["isDraft"] or target["isPrerelease"]:
        raise ValueError("Choose a published stable release")
    tag = target["tagName"]
    with tempfile.TemporaryDirectory(prefix="nameplate-appcast-") as directory:
        gh("release", "download", tag, "--pattern", "appcast.xml", "--dir", directory)
        path = Path(directory) / "appcast.xml"
        updated, versions = refresh_notes(path.read_bytes(), lambda tag: release(tag)["body"])
        path.write_bytes(updated)
        if not arguments.dry_run:
            gh("release", "upload", tag, str(path), "--clobber")
    summary = f"{'Validated' if arguments.dry_run else 'Updated'} {tag}/appcast.xml notes for: {', '.join(versions)}"
    print(summary)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as output:
            output.write(summary + "\n")


if __name__ == "__main__":
    main()
