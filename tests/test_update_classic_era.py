#!/usr/bin/env python3
"""Tests for Classic Era compatibility release preparation."""

from __future__ import annotations

import tempfile
import unittest
from datetime import date
from pathlib import Path

from tools import update_classic_era

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tests" / "fixtures" / "classic_era_versions.txt"


class ClassicEraUpdateTests(unittest.TestCase):
    def write_release_files(
        self, root: Path, *, interface: str = "11508, 11509"
    ) -> None:
        (root / "DefaultQuestTrackerClassic.toc").write_text(
            f"## Interface: {interface}\n## Version: @project-version@\n",
            encoding="utf-8",
        )
        (root / "VERSION").write_text("1.2.1\n", encoding="utf-8")
        (root / "CHANGELOG.md").write_text(
            "# Changelog\n\n## [1.2.1] - 2026-09-05\n",
            encoding="utf-8",
        )
        (root / "RELEASE_NOTES.md").write_text(
            "# Default Quest Tracker Classic\n\n"
            "## [1.2.1] - 2026-09-05\n",
            encoding="utf-8",
        )

    def test_parses_blizzard_fixture(self) -> None:
        build = update_classic_era.parse_versions(
            FIXTURE.read_text(encoding="utf-8")
        )

        self.assertEqual("1.15.9.69722", build.version)
        self.assertEqual(69722, build.build_id)
        self.assertEqual(11509, build.interface)

    def test_interface_from_version_rejects_malformed_value(self) -> None:
        with self.assertRaisesRegex(ValueError, "Invalid Classic Era"):
            update_classic_era.interface_from_version("1.15.9")

    def test_parse_rejects_malformed_feed(self) -> None:
        with self.assertRaisesRegex(ValueError, "missing required columns"):
            update_classic_era.parse_versions("Region!STRING:0|BuildId!DEC:4\n")

    def test_new_interface_prepares_patch_release(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_release_files(root)
            build = update_classic_era.GameBuild("1.15.10.70123", 70123, 11510)

            result = update_classic_era.prepare_update(
                build, root=root, today=date(2026, 9, 21)
            )

            self.assertTrue(result.changed)
            self.assertEqual("1.2.2", result.addon_version)
            self.assertIn(
                "## Interface: 11510",
                (root / "DefaultQuestTrackerClassic.toc").read_text(
                    encoding="utf-8"
                ),
            )
            self.assertEqual(
                "1.2.2\n", (root / "VERSION").read_text(encoding="utf-8")
            )
            changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
            self.assertIn("## [1.2.2] - 2026-09-21", changelog)
            self.assertIn("1.15.10.70123 (Interface 11510)", changelog)
            release_notes = (root / "RELEASE_NOTES.md").read_text(
                encoding="utf-8"
            )
            self.assertIn("## [1.2.2] - 2026-09-21", release_notes)
            self.assertIn("1.15.10.70123 (Interface 11510)", release_notes)
            self.assertNotIn("1.2.1", release_notes)

            second = update_classic_era.prepare_update(build, root=root)
            self.assertFalse(second.changed)

    def test_build_only_change_is_no_op(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_release_files(root)
            build = update_classic_era.GameBuild("1.15.9.70000", 70000, 11509)

            result = update_classic_era.prepare_update(build, root=root)

            self.assertFalse(result.changed)
            self.assertEqual(
                "1.2.1\n", (root / "VERSION").read_text(encoding="utf-8")
            )

    def test_dry_run_reports_without_writing(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_release_files(root)
            before = {
                path.name: path.read_text(encoding="utf-8")
                for path in root.iterdir()
            }
            build = update_classic_era.GameBuild("1.15.10.70123", 70123, 11510)

            result = update_classic_era.prepare_update(
                build, root=root, today=date(2026, 9, 21), dry_run=True
            )

            self.assertTrue(result.changed)
            self.assertEqual(
                before,
                {
                    path.name: path.read_text(encoding="utf-8")
                    for path in root.iterdir()
                },
            )

    def test_refuses_interface_downgrade(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_release_files(root, interface="11510")
            build = update_classic_era.GameBuild("1.15.9.69722", 69722, 11509)

            with self.assertRaisesRegex(ValueError, "Refusing to downgrade"):
                update_classic_era.prepare_update(build, root=root)


if __name__ == "__main__":
    unittest.main()
