#!/usr/bin/env python3
"""Generate circular TGA art for map/tracker pins (QuestHelper-style discs).

TempPortraitAlphaMask is a *mask*, not a fill. Using it as SetTexture() draws a
square (its RGB) which is what the ugly numbered boxes were. These textures are
white with a circular alpha so SetVertexColor can tint them.
"""

from __future__ import annotations

import math
import struct
from pathlib import Path

SIZE = 128


def write_tga(path: Path, pixels: list[tuple[int, int, int, int]]) -> None:
    w = h = SIZE
    header = bytearray(18)
    header[2] = 2  # uncompressed true-color
    header[12:14] = struct.pack("<H", w)
    header[14:16] = struct.pack("<H", h)
    header[16] = 32
    header[17] = 0x28  # origin top-left, 8-bit alpha
    body = bytearray()
    for r, g, b, a in pixels:
        body.extend((b, g, r, a))
    path.write_bytes(bytes(header) + body)


def alpha_edge(dist: float, inner: float, outer: float) -> int:
    if dist <= inner:
        return 255
    if dist >= outer:
        return 0
    t = (outer - dist) / (outer - inner)
    return int(255 * t + 0.5)


def filled_circle() -> list[tuple[int, int, int, int]]:
    cx = cy = (SIZE - 1) / 2.0
    outer = SIZE / 2.0 - 0.5
    inner = outer - 1.25
    pixels = []
    for y in range(SIZE):
        for x in range(SIZE):
            d = math.hypot(x - cx, y - cy)
            a = alpha_edge(d, inner, outer)
            pixels.append((255, 255, 255, a))
    return pixels


def ring(inner_r: float, outer_r: float) -> list[tuple[int, int, int, int]]:
    cx = cy = (SIZE - 1) / 2.0
    pixels = []
    feather = 1.1
    for y in range(SIZE):
        for x in range(SIZE):
            d = math.hypot(x - cx, y - cy)
            outer_a = alpha_edge(d, outer_r - feather, outer_r)
            hole = alpha_edge(d, inner_r, inner_r + feather)
            a = int(outer_a * (255 - hole) / 255)
            pixels.append((255, 255, 255, a))
    return pixels


def main() -> None:
    root = Path(__file__).resolve().parents[1] / "Media"
    root.mkdir(exist_ok=True)
    # Disc fill for POI and hover wash
    write_tga(root / "FilledCircle.tga", filled_circle())
    # ~2px gold rim when the pin is ~22px
    write_tga(root / "PinRing.tga", ring(SIZE / 2.0 - 12.5, SIZE / 2.0 - 0.5))
    # Thin black outline when the wash is ~80px
    write_tga(root / "ThinRing.tga", ring(SIZE / 2.0 - 4.0, SIZE / 2.0 - 0.5))
    print(f"Wrote circle textures in {root}")


if __name__ == "__main__":
    main()
