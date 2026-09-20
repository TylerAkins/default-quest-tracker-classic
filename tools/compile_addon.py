#!/usr/bin/env python3
"""Build a clean, directly installable local addon directory."""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD_ROOT = ROOT / ".compiled"
ADDON_DIR = BUILD_ROOT / "DefaultQuestTrackerClassic"

ROOT_FILES = (
    "ATTRIBUTION.md",
    "CHANGELOG.md",
    "Compat.lua",
    "Config.lua",
    "Core.lua",
    "DefaultQuestTrackerClassic.toc",
    "LICENSE",
    "Options.lua",
    "README.md",
)
DIRECTORIES = ("Database", "Libs", "Localization", "Media", "Modules")
IGNORED_NAMES = {".DS_Store", "Thumbs.db", "__pycache__"}


def project_version() -> str:
    """Return a useful local version without requiring a tagged checkout."""
    result = subprocess.run(
        ["git", "describe", "--tags", "--always", "--dirty"],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    version = result.stdout.strip()
    return version or "local"


def iter_files() -> list[Path]:
    """Return the files included in a local or release build."""
    files = [ROOT / name for name in ROOT_FILES]
    for directory in DIRECTORIES:
        files.extend(
            path
            for path in (ROOT / directory).rglob("*")
            if path.is_file()
            and not any(part in IGNORED_NAMES for part in path.parts)
        )
    return sorted(files)


def compile_addon(output_dir: Path = ADDON_DIR, *, dry_run: bool = False) -> list[Path]:
    """Replace the local build with a clean installable addon tree."""
    files = iter_files()
    destinations = [output_dir / path.relative_to(ROOT) for path in files]
    if dry_run:
        return destinations

    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True)

    for source, destination in zip(files, destinations, strict=True):
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)

    toc = output_dir / "DefaultQuestTrackerClassic.toc"
    toc.write_text(
        toc.read_text(encoding="utf-8").replace(
            "@project-version@", project_version()
        ),
        encoding="utf-8",
    )
    return destinations


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build .compiled/DefaultQuestTrackerClassic for local installation."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="list output files without deleting or copying anything",
    )
    args = parser.parse_args()

    files = compile_addon(dry_run=args.dry_run)
    if args.dry_run:
        for path in files:
            print(path.relative_to(ROOT))
        return
    print(f"Built {len(files)} files in {ADDON_DIR}")


if __name__ == "__main__":
    main()
