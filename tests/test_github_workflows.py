#!/usr/bin/env python3
"""Guardrails for GitHub Actions workflow conventions."""

from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class GithubWorkflowTests(unittest.TestCase):
    def test_classic_era_update_pr_assigns_maintainer(self) -> None:
        workflow = (ROOT / ".github/workflows/update-classic-era.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("assignees: TylerAkins", workflow)
        self.assertIn(
            "@TylerAkins — automated Classic Era compatibility update.",
            workflow,
        )


if __name__ == "__main__":
    unittest.main()
