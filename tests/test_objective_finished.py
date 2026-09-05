#!/usr/bin/env python3
"""Keep in sync with QuestLogCache objective completion helpers."""

from __future__ import annotations

import re


def parse_objective_progress(text: str | None) -> tuple[int | None, int | None]:
    if not text:
        return None, None
    match = re.search(r"(\d+)\s*/\s*(\d+)", text)
    if not match:
        return None, None
    return int(match.group(1)), int(match.group(2))


def objective_is_finished(
    done,
    text: str | None,
    num_fulfilled: int | None,
    num_required: int | None,
) -> bool:
    if done:
        return True
    current = num_fulfilled
    required = num_required
    if current is None or required is None:
        current, required = parse_objective_progress(text)
    if current is not None and required is not None and required > 0 and current >= required:
        return True
    return False


def test_parse_objective_progress() -> None:
    assert parse_objective_progress("Young Nightsaber slain: 3/10") == (3, 10)
    assert parse_objective_progress("0/1 Item collected") == (0, 1)
    assert parse_objective_progress("No counts here") == (None, None)
    assert parse_objective_progress(None) == (None, None)


def test_objective_is_finished_uses_done_flag() -> None:
    assert objective_is_finished(1, "Foo: 10/10", None, None) is True
    assert objective_is_finished(True, "Foo: 0/10", None, None) is True
    assert objective_is_finished(None, "Foo: 0/10", None, None) is False


def test_objective_is_finished_uses_numeric_progress() -> None:
    assert objective_is_finished(None, "Foo: 10/10", None, None) is True
    assert objective_is_finished(False, "Foo: 5/10", None, None) is False
    assert objective_is_finished(False, "Foo: 10/10", 10, 10) is True
    assert objective_is_finished(False, "Foo: 0/10", 0, 10) is False


def main() -> None:
    test_parse_objective_progress()
    test_objective_is_finished_uses_done_flag()
    test_objective_is_finished_uses_numeric_progress()
    print("ok")


if __name__ == "__main__":
    main()
