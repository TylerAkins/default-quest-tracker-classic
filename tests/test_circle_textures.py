#!/usr/bin/env python3
"""Guard: pin art TGAs must be circular with a visible gold rim and baked digits."""

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

    atlas = ROOT / "PoiAtlas.tga"
    w, h, raw = read_tga(atlas)
    assert w == h == 256
    # Cell 0 (idle "1"): transparent corner of the atlas, gold on the top of the disc
    assert px(raw, w, 0, 0)[3] == 0
    cr, cg, cb, ca = px(raw, w, 10, 16)
    assert ca > 200 and cr + cg + cb < 220, (cr, cg, cb, ca)
    rr, rg, rb, ra = px(raw, w, 16, 1)
    assert ra > 40 and rr > 140 and rg > 80, (rr, rg, rb, ra)

    badge = ROOT / "PoiBadge.tga"
    w, h, raw = read_tga(badge)
    assert w == h == 32
    assert px(raw, w, 0, 0)[3] == 0
    cr, cg, cb, ca = px(raw, w, w // 2, h // 2)
    assert ca > 200 and cr + cg + cb < 200, (cr, cg, cb, ca)


if __name__ == "__main__":
    test_circle_textures()
    print("ok")
