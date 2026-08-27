#!/usr/bin/env python3
"""Guard: pin art TGAs must be circular (transparent corners, opaque center)."""

from __future__ import annotations

import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "Media"
FILES = ("FilledCircle.tga", "PinRing.tga", "ThinRing.tga")


def read_tga(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    w, h = struct.unpack_from("<HH", data, 12)
    bpp = data[16]
    desc = data[17]
    assert bpp == 32, path
    assert desc & 0x20, f"expected top-left origin: {path}"
    return w, h, data[18 : 18 + w * h * 4]


def alpha_at(raw: bytes, w: int, x: int, y: int) -> int:
    return raw[(y * w + x) * 4 + 3]


def test_circle_textures() -> None:
    for name in FILES:
        path = ROOT / name
        assert path.is_file(), f"missing {path}"
        w, h, raw = read_tga(path)
        assert w == h == 128, (name, w, h)
        corners = [
            alpha_at(raw, w, 0, 0),
            alpha_at(raw, w, w - 1, 0),
            alpha_at(raw, w, 0, h - 1),
            alpha_at(raw, w, w - 1, h - 1),
        ]
        assert all(a == 0 for a in corners), (name, corners)
        cx = cy = w // 2
        if name == "FilledCircle.tga":
            assert alpha_at(raw, w, cx, cy) > 240
        else:
            # Rings: center hole transparent, mid-radius opaque
            assert alpha_at(raw, w, cx, cy) < 20
            rim = alpha_at(raw, w, cx, 2)
            assert rim > 80, (name, rim)


if __name__ == "__main__":
    test_circle_textures()
    print("ok")
