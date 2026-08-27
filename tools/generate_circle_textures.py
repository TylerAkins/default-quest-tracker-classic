#!/usr/bin/env python3
"""Generate only the tintable world-map objective-area textures.

Numbered POIs deliberately use Blizzard's UI-QuestPoi-NumberIcons directly.
"""

from __future__ import annotations

import math
import struct
from pathlib import Path

WASH_SIZE = 128


def write_tga(path: Path, width: int, height: int, pixels: list[tuple[int, int, int, int]]) -> None:
    header = bytearray(18)
    header[2] = 2
    header[12:14] = struct.pack("<H", width)
    header[14:16] = struct.pack("<H", height)
    header[16] = 32
    header[17] = 0x28
    body = bytearray()
    for r, g, b, a in pixels:
        body.extend((b, g, r, a))
    path.write_bytes(bytes(header) + body)


def alpha_edge(dist: float, inner: float, outer: float) -> int:
    if dist <= inner:
        return 255
    if dist >= outer:
        return 0
    return int(255 * (outer - dist) / (outer - inner) + 0.5)


def filled_circle(size: int) -> list[tuple[int, int, int, int]]:
    cx = cy = (size - 1) / 2.0
    outer = size / 2.0 - 0.5
    inner = outer - 1.25
    pixels = []
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy)
            pixels.append((255, 255, 255, alpha_edge(d, inner, outer)))
    return pixels


def ring(size: int, inner_r: float, outer_r: float) -> list[tuple[int, int, int, int]]:
    cx = cy = (size - 1) / 2.0
    pixels = []
    feather = 1.1
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy)
            outer_a = alpha_edge(d, outer_r - feather, outer_r)
            hole = alpha_edge(d, inner_r, inner_r + feather)
            pixels.append((255, 255, 255, int(outer_a * (255 - hole) / 255)))
    return pixels


def main() -> None:
    root = Path(__file__).resolve().parents[1] / "Media"
    root.mkdir(exist_ok=True)
    write_tga(root / "FilledCircle.tga", WASH_SIZE, WASH_SIZE, filled_circle(WASH_SIZE))
    write_tga(root / "ThinRing.tga", WASH_SIZE, WASH_SIZE, ring(WASH_SIZE, WASH_SIZE / 2.0 - 4.0, WASH_SIZE / 2.0 - 0.5))
    print(f"Wrote objective-area textures in {root}")


if __name__ == "__main__":
    main()
