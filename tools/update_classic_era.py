#!/usr/bin/env python3
"""Prepare a patch release when Classic Era's TOC interface changes."""

from __future__ import annotations

import argparse
import re
import urllib.request
from dataclasses import dataclass
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSIONS_URL = "https://us.version.battle.net/v2/products/wow_classic_era/versions"
TOC_NAME = "DefaultQuestTrackerClassic.toc"

GAME_VERSION_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)\.(\d+)$")
ADDON_VERSION_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
INTERFACE_LINE_RE = re.compile(r"^## Interface:\s*(.+)$", re.MULTILINE)


@dataclass(frozen=True)
class GameBuild:
    version: str
    build_id: int
    interface: int


@dataclass(frozen=True)
class UpdateResult:
    changed: bool
    game_build: GameBuild
    addon_version: str | None = None


def interface_from_version(version: str) -> int:
    """Convert a game version such as 1.15.9.69722 to Interface 11509."""
    match = GAME_VERSION_RE.fullmatch(version)
    if not match:
        raise ValueError(f"Invalid Classic Era game version: {version}")
    major, minor, patch, _ = (int(part) for part in match.groups())
    return int(f"{major}{minor:02d}{patch:02d}")


def parse_versions(text: str, *, region: str = "us") -> GameBuild:
    """Read one region from Blizzard's pipe-delimited product version feed."""
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if not lines:
        raise ValueError("Blizzard version feed is empty")

    headers = [field.split("!", 1)[0] for field in lines[0].split("|")]
    required = {"Region", "BuildId", "VersionsName"}
    if not required.issubset(headers):
        raise ValueError("Blizzard version feed is missing required columns")

    for line in lines[1:]:
        if line.startswith("##"):
            continue
        values = line.split("|")
        if len(values) != len(headers):
            raise ValueError("Blizzard version feed contains a malformed row")
        row = dict(zip(headers, values, strict=True))
        if row["Region"] != region:
            continue
        try:
            build_id = int(row["BuildId"])
        except ValueError as exc:
            raise ValueError("Blizzard build ID is not numeric") from exc
        version = row["VersionsName"]
        return GameBuild(version, build_id, interface_from_version(version))

    raise ValueError(f"Blizzard version feed has no {region!r} region")


def fetch_versions(url: str = VERSIONS_URL) -> str:
    """Fetch Blizzard's public Classic Era version feed."""
    with urllib.request.urlopen(url, timeout=30) as response:
        return response.read().decode("utf-8")


def bump_patch(version: str) -> str:
    """Increment a strict semantic patch version."""
    match = ADDON_VERSION_RE.fullmatch(version)
    if not match:
        raise ValueError(f"VERSION must contain X.Y.Z, found: {version!r}")
    major, minor, patch = (int(part) for part in match.groups())
    return f"{major}.{minor}.{patch + 1}"


def current_interfaces(toc: str) -> list[int]:
    """Return the numeric interfaces declared by the addon TOC."""
    match = INTERFACE_LINE_RE.search(toc)
    if not match:
        raise ValueError("TOC is missing an Interface line")
    try:
        interfaces = [int(value.strip()) for value in match.group(1).split(",")]
    except ValueError as exc:
        raise ValueError("TOC Interface values must be numeric") from exc
    if not interfaces:
        raise ValueError("TOC has no Interface values")
    return interfaces


def prepare_update(
    game_build: GameBuild,
    *,
    root: Path = ROOT,
    today: date | None = None,
    dry_run: bool = False,
) -> UpdateResult:
    """Prepare release files if the upstream interface is newer."""
    toc_path = root / TOC_NAME
    version_path = root / "VERSION"
    changelog_path = root / "CHANGELOG.md"

    toc = toc_path.read_text(encoding="utf-8")
    interfaces = current_interfaces(toc)
    if game_build.interface in interfaces:
        return UpdateResult(False, game_build)
    if game_build.interface < max(interfaces):
        raise ValueError(
            f"Refusing to downgrade Interface {max(interfaces)} to "
            f"{game_build.interface}"
        )

    current_version = version_path.read_text(encoding="utf-8").strip()
    next_version = bump_patch(current_version)
    changelog = changelog_path.read_text(encoding="utf-8")
    heading = f"## [{next_version}]"
    if heading in changelog:
        raise ValueError(f"CHANGELOG already contains {heading}")

    updated_toc = INTERFACE_LINE_RE.sub(
        f"## Interface: {game_build.interface}", toc, count=1
    )
    release_date = today or date.today()
    entry = (
        f"## [{next_version}] - {release_date.isoformat()}\n\n"
        "### Changed\n\n"
        f"- Updated Classic Era compatibility for game build "
        f"{game_build.version} (Interface {game_build.interface})\n\n"
    )
    marker = "# Changelog\n\n"
    if not changelog.startswith(marker):
        raise ValueError("CHANGELOG must start with '# Changelog'")
    updated_changelog = marker + entry + changelog[len(marker) :]

    if not dry_run:
        toc_path.write_text(updated_toc, encoding="utf-8")
        version_path.write_text(f"{next_version}\n", encoding="utf-8")
        changelog_path.write_text(updated_changelog, encoding="utf-8")

    return UpdateResult(True, game_build, next_version)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Prepare a patch release for a new Classic Era interface."
    )
    parser.add_argument(
        "--versions-file",
        type=Path,
        help="read a saved Blizzard versions response instead of fetching it",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="report the update without changing files",
    )
    args = parser.parse_args()

    versions = (
        args.versions_file.read_text(encoding="utf-8")
        if args.versions_file
        else fetch_versions()
    )
    result = prepare_update(parse_versions(versions), dry_run=args.dry_run)
    if result.changed:
        action = "Would prepare" if args.dry_run else "Prepared"
        print(
            f"{action} v{result.addon_version} for game build "
            f"{result.game_build.version} (Interface {result.game_build.interface})"
        )
    else:
        print(
            f"Interface {result.game_build.interface} is already supported; "
            "no update needed"
        )


if __name__ == "__main__":
    main()
