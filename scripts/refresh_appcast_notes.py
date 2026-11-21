"""Refresh embedded notes for every version in a published release's appcast."""

import argparse
import html
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


def version_key(version):
    return tuple(map(int, version.split(".")))


def render_markdown(notes):
    return subprocess.check_output(
        ["gh", "api", "markdown", "--method", "POST", "--input", "-"],
        input=json.dumps({"text": notes, "mode": "gfm", "context": os.environ["GH_REPO"]}),
        text=True,
    )


def release_history():
    pages = json.loads(gh("api", "--paginate", "--slurp", "repos/{owner}/{repo}/releases"))
    return {
        entry["tag_name"][1:]: entry["body"] or ""
        for page in pages for entry in page
        if not entry["draft"] and not entry["prerelease"]
        and re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", entry["tag_name"])
    }


def refresh_notes(feed, load_notes, history=None, render=render_markdown):
    document = minidom.parseString(feed)
    versions = []
    history = dict(history or {})
    items = []
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
        history[version] = notes
        items.append((item, version))
        versions.append(version)
    rendered = {}
    for version, notes in history.items():
        notes = re.sub(
            r"<!-- nameplate-notarization:start -->.*?<!-- nameplate-notarization:end -->\n?",
            "", notes, flags=re.DOTALL,
        ).strip()
        if not notes or "TODO: Add release notes" in notes:
            raise ValueError(f"Release v{version} has empty or placeholder notes")
        # GitHub's generic heading adds no information beneath a version heading.
        notes = re.sub(r"\A#{1,6}\s+release notes\s*\n+", "", notes, flags=re.IGNORECASE)
        rendered[version] = render(notes)
    for item, version in items:
        sections = [
            f'<div data-sparkle-version="{older}"><h2 class="version">{html.escape(older)}</h2>'
            + rendered[older] + '</div>'
            for older in sorted(rendered, key=version_key, reverse=True)
            if version_key(older) <= version_key(version)
        ]
        content = ('<!DOCTYPE html><html><head><meta charset="utf-8"><style>'
                   ':root { color-scheme: light dark; }'
                   'body { margin: 0; padding: 16px 20px; '
                   'font: 13px/1.55 -apple-system, BlinkMacSystemFont, sans-serif; '
                   'overflow-wrap: anywhere; }'
                   'div[data-sparkle-version] + div[data-sparkle-version] '
                   '{ margin-top: 20px; padding-top: 16px; '
                   'border-top: 1px solid rgba(128,128,128,.25); }'
                   'h2.version { font-size: 16px; font-weight: 650; '
                   'letter-spacing: -.2px; margin: 0 0 8px; }'
                   'h1, h2, h3, h4, h5, h6 { font-size: 13px; '
                   'font-weight: 600; margin: 14px 0 6px; }'
                   'p { margin: 6px 0; }'
                   'ul, ol { margin: 6px 0; padding-left: 20px; }'
                   'li { margin: 4px 0; }'
                   'li > p { margin: 0; }'
                   'a { color: LinkText; }'
                   'pre { overflow-x: auto; padding: 10px; '
                   'background: rgba(128,128,128,.12); border-radius: 6px; }'
                   'code { font-size: .92em; }'
                   'img { max-width: 100%; height: auto; }'
                   'blockquote { margin: 10px 0; padding-left: 12px; '
                   'border-left: 2px solid rgba(128,128,128,.4); }'
                   'div.sparkle-installed-version, div.sparkle-installed-version ~ div '
                   '{ display: none; }'
                   '</style></head><body>' + ''.join(sections) + '</body></html>')
        descriptions = item.getElementsByTagName("description")
        if len(descriptions) != 1:
            raise ValueError(f"Expected one description for v{version}")
        description = descriptions[0]
        for node in list(description.childNodes):
            description.removeChild(node)
        if description.hasAttributeNS(SPARKLE_NAMESPACE, "format"):
            description.removeAttributeNS(SPARKLE_NAMESPACE, "format")
        description.appendChild(document.createTextNode(content))
    if not versions:
        raise ValueError("Appcast contains no releases")
    return document.toxml(encoding="utf-8"), versions


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", default="", help="Defaults to the latest stable release")
    parser.add_argument("--feed", type=Path, help="Update a local feed without uploading")
    parser.add_argument("--dry-run", action="store_true", help="Validate without uploading")
    arguments = parser.parse_args()
    history = release_history()
    if arguments.feed:
        updated, _ = refresh_notes(arguments.feed.read_bytes(),
                                   lambda tag: release(tag)["body"], history)
        if not arguments.dry_run:
            arguments.feed.write_bytes(updated)
        return
    target = release(arguments.tag)
    if target["isDraft"] or target["isPrerelease"]:
        raise ValueError("Choose a published stable release")
    tag = target["tagName"]
    with tempfile.TemporaryDirectory(prefix="nameplate-appcast-") as directory:
        gh("release", "download", tag, "--pattern", "appcast.xml", "--dir", directory)
        path = Path(directory) / "appcast.xml"
        updated, versions = refresh_notes(path.read_bytes(), lambda tag: release(tag)["body"], history)
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
