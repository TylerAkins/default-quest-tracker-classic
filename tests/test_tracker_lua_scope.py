#!/usr/bin/env python3
"""Lua local functions are not visible above their declaration."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRACKER_LINES = ROOT / "Modules" / "Tracker" / "TrackerLines.lua"


def _function_body(src: str, header: str) -> tuple[int, str]:
    start = src.index(header)
    nxt = src.find("\nfunction ", start + 1)
    if nxt < 0:
        nxt = len(src)
    return start, src[start:nxt]


def test_initialize_does_not_call_later_locals() -> None:
    src = TRACKER_LINES.read_text(encoding="utf-8")
    start, body = _function_body(src, "function TrackerLines:Initialize")
    if "EnsureMeasureFS(" not in body:
        return
    def_at = src.index("local function EnsureMeasureFS")
    assert def_at < start, (
        "TrackerLines:Initialize calls EnsureMeasureFS before that local exists"
    )


def main() -> None:
    test_initialize_does_not_call_later_locals()
    print("ok")


if __name__ == "__main__":
    main()
