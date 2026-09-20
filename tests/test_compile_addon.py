#!/usr/bin/env python3
"""Tests for the local addon compiler."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "compile_addon.py"
SPEC = importlib.util.spec_from_file_location("compile_addon", SCRIPT)
assert SPEC and SPEC.loader
COMPILE_ADDON = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COMPILE_ADDON)


class CompileAddonTests(unittest.TestCase):
    def test_build_is_clean_installable_and_versioned(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "DefaultQuestTrackerClassic"
            stale = output / "stale.txt"
            stale.parent.mkdir(parents=True)
            stale.write_text("remove me", encoding="utf-8")

            with mock.patch.object(
                COMPILE_ADDON, "project_version", return_value="v1.2.1-local"
            ):
                built = COMPILE_ADDON.compile_addon(output)

            self.assertFalse(stale.exists())
            self.assertIn(output / "DefaultQuestTrackerClassic.toc", built)
            for required in (
                "Core.lua",
                "Database/Classic/Quests.lua",
                "Libs/LibStub.lua",
                "Localization/enUS.lua",
                "Media/FilledCircle.tga",
                "Modules/Loader.lua",
                "RELEASE_NOTES.md",
            ):
                self.assertTrue((output / required).is_file(), required)

            for excluded in (
                "VERSION",
                ".pkgmeta",
                "CURSEFORGE_DESCRIPTION.md",
                "tests/test_compile_addon.py",
                "tools/compile_addon.py",
                ".github/workflows/release.yml",
            ):
                self.assertFalse((output / excluded).exists(), excluded)

            toc = (output / "DefaultQuestTrackerClassic.toc").read_text(
                encoding="utf-8"
            )
            self.assertIn("## Version: v1.2.1-local", toc)
            self.assertNotIn("@project-version@", toc)

    def test_dry_run_does_not_replace_existing_output(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "DefaultQuestTrackerClassic"
            stale = output / "stale.txt"
            stale.parent.mkdir(parents=True)
            stale.write_text("keep me", encoding="utf-8")

            built = COMPILE_ADDON.compile_addon(output, dry_run=True)

            self.assertTrue(stale.exists())
            self.assertIn(output / "DefaultQuestTrackerClassic.toc", built)


if __name__ == "__main__":
    unittest.main()
