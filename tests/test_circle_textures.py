#!/usr/bin/env python3
"""Guard: custom objective-area TGAs must remain circular."""

from __future__ import annotations

import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "Media"


def read_tga(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    w, h = struct.unpack_from("<HH", data, 12)
    bpp = data[16]
    desc = data[17]
    assert bpp == 32, path
    assert desc & 0x20, f"expected top-left origin: {path}"
    return w, h, data[18 : 18 + w * h * 4]


def px(raw: bytes, w: int, x: int, y: int) -> tuple[int, int, int, int]:
    i = (y * w + x) * 4
    b, g, r, a = raw[i], raw[i + 1], raw[i + 2], raw[i + 3]
    return r, g, b, a


def test_circle_textures() -> None:
    wash = ROOT / "FilledCircle.tga"
    w, h, raw = read_tga(wash)
    assert w == h == 128
    assert px(raw, w, 0, 0)[3] == 0
    assert px(raw, w, w // 2, h // 2)[3] > 240

    outline = ROOT / "ThinRing.tga"
    w, h, raw = read_tga(outline)
    assert w == h == 128
    assert px(raw, w, 0, 0)[3] == 0
    assert px(raw, w, w // 2, h // 2)[3] == 0
    assert px(raw, w, w // 2, 2)[3] > 100


if __name__ == "__main__":
    test_circle_textures()
    print("ok")
