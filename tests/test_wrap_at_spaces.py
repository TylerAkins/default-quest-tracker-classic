#!/usr/bin/env python3
"""Keep in sync with TrackerLines.WrapAtSpaces in Modules/Tracker/TrackerLines.lua."""

from __future__ import annotations


def wrap_at_spaces(text: str, width: float, measure, hang: str = "") -> str:
    if not text:
        return text
    if measure(text) <= width:
        return text
    lines: list[str] = []
    rest = text
    first = True
    while rest:
        prefix = "" if first else hang
        if measure(prefix + rest) <= width:
            lines.append(prefix + rest)
            break
        best_end = None
        search_from = 0
        while True:
            space_at = rest.find(" ", search_from)
            if space_at < 0:
                break
            candidate = rest[:space_at]
            if candidate and measure(prefix + candidate) <= width:
                best_end = space_at
                search_from = space_at + 1
            else:
                break
        if best_end is None:
            lines.append(prefix + rest)
            break
        lines.append(prefix + rest[:best_end])
        rest = rest[best_end + 1 :].lstrip(" ")
        first = False
    return "\n".join(lines)


def measure_chars(s: str) -> int:
    return len(s)


OBJECTIVE = "- Stonesplinter Bonesnapper slain: 0/10"
HANG = "  "


def test_fits_on_one_line() -> None:
    assert wrap_at_spaces(OBJECTIVE, len(OBJECTIVE), measure_chars) == OBJECTIVE


def test_count_moves_together_not_split_on_slash() -> None:
    wrapped = wrap_at_spaces(OBJECTIVE, 36, measure_chars)
    assert wrapped == "- Stonesplinter Bonesnapper slain:\n0/10"
    assert "0/\n10" not in wrapped


def test_hanging_indent_lines_up_after_dash() -> None:
    wrapped = wrap_at_spaces(OBJECTIVE, 36, measure_chars, HANG)
    assert wrapped == "- Stonesplinter Bonesnapper slain:\n  0/10"
    assert wrapped.split("\n")[1].startswith(HANG)


def test_wraps_earlier_space_still_keeps_count() -> None:
    wrapped = wrap_at_spaces(OBJECTIVE, 30, measure_chars, HANG)
    assert wrapped == "- Stonesplinter Bonesnapper\n  slain: 0/10"
    assert "0/\n10" not in wrapped


def test_never_splits_progress_count() -> None:
    for width in range(8, len(OBJECTIVE) + 2):
        wrapped = wrap_at_spaces(OBJECTIVE, width, measure_chars, HANG)
        assert "0/\n10" not in wrapped, width
        assert "0/10" in wrapped.replace("\n", " ")


def test_unbroken_token_is_not_split() -> None:
    assert wrap_at_spaces("0/10", 2, measure_chars) == "0/10"


def main() -> None:
    test_fits_on_one_line()
    test_count_moves_together_not_split_on_slash()
    test_hanging_indent_lines_up_after_dash()
    test_wraps_earlier_space_still_keeps_count()
    test_never_splits_progress_count()
    test_unbroken_token_is_not_split()
    print("ok")


if __name__ == "__main__":
    main()
