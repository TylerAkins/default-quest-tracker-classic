#!/usr/bin/env python3
"""Generate circular TGA art for map/tracker pins.

QuestHelper used a 32px circular icon atlas with the digit *in the art*.
We bake idle/active badges plus 1-20 and ? so Friz metrics cannot off-center
the "1", and so the gold rim cannot be covered by a fill layer.
"""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

WASH_SIZE = 128
HI_SIZE = 64
CELL = 32
ATLAS_COLS = 8
ATLAS_ROWS = 8
ATLAS = CELL * ATLAS_COLS  # 256
FONT_PATH = Path("/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf")

# Atlas: 0-19 idle 1-20, 20 idle ?, 21-40 active 1-20, 41 active ?


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


def write_png(path: Path, width: int, height: int, pixels: list[tuple[int, int, int, int]]) -> None:
    raw = b""
    i = 0
    for _y in range(height):
        raw += b"\x00"
        for _x in range(width):
            r, g, b, a = pixels[i]
            raw += bytes((r, g, b, a))
            i += 1

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return (
        int(a[0] + (b[0] - a[0]) * t + 0.5),
        int(a[1] + (b[1] - a[1]) * t + 0.5),
        int(a[2] + (b[2] - a[2]) * t + 0.5),
    )


def sample_badge(x: float, y: float, size: int, fill: tuple[int, int, int], rim: tuple[int, int, int], outline: tuple[int, int, int]) -> tuple[int, int, int, int]:
    cx = cy = (size - 1) / 2.0
    d = math.hypot(x - cx, y - cy)
    r_out = size / 2.0 - 0.75
    r_black = r_out - 1.6
    r_gold = r_black - 5.4
    if d >= r_out + 0.55:
        return (0, 0, 0, 0)
    if d >= r_out:
        a = int(255 * (r_out + 0.55 - d) / 0.55 + 0.5)
        return (*outline, max(0, min(255, a)))
    if d >= r_black:
        t = (d - r_black) / (r_out - r_black)
        return (*mix(rim, outline, t), 255)
    if d >= r_gold:
        # Solid gold stroke, tiny blend at the fill edge
        edge = (d - r_gold) / (r_black - r_gold)
        if edge < 0.12:
            return (*mix(fill, rim, edge / 0.12), 255)
        return (*rim, 255)
    shade = 1.0 - 0.12 * (d / max(r_gold, 1))
    col = (int(fill[0] * shade), int(fill[1] * shade), int(fill[2] * shade))
    return (*col, 255)


def render_badge(size: int, fill: tuple[int, int, int], rim: tuple[int, int, int], outline: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            acc = [0, 0, 0, 0]
            for oy in (0.25, 0.75):
                for ox in (0.25, 0.75):
                    r, g, b, a = sample_badge(x + ox, y + oy, size, fill, rim, outline)
                    acc[0] += r * a
                    acc[1] += g * a
                    acc[2] += b * a
                    acc[3] += a
            a = acc[3] // 4
            if a == 0:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (acc[0] // acc[3], acc[1] // acc[3], acc[2] // acc[3], a)
    return img


def glyph_centroid(img: Image.Image) -> tuple[float, float, int]:
    px = img.load()
    w, h = img.size
    xs = 0.0
    ys = 0.0
    n = 0
    for y in range(h):
        for x in range(w):
            a = px[x, y][3]
            if a > 32:
                xs += x * a
                ys += y * a
                n += a
    if n == 0:
        return (w / 2, h / 2, 0)
    return (xs / n, ys / n, n)


def draw_label(base: Image.Image, text: str, fill: tuple[int, int, int], outline: tuple[int, int, int]) -> Image.Image:
    size = base.size[0]
    font_size = 36 if len(text) == 1 else 28
    font = ImageFont.truetype(str(FONT_PATH), font_size)
    scratch = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(scratch)
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (size - tw) / 2 - bbox[0]
    y = (size - th) / 2 - bbox[1]
    draw.text((x, y), text, font=font, fill=(255, 255, 255, 255))
    mx, my, _ = glyph_centroid(scratch)
    x += (size - 1) / 2.0 - mx
    y += (size - 1) / 2.0 - my

    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1)):
        draw.text((x + dx, y + dy), text, font=font, fill=(*outline, 255))
    draw.text((x, y), text, font=font, fill=(*fill, 255))
    return Image.alpha_composite(base, overlay)


def image_pixels(img: Image.Image) -> list[tuple[int, int, int, int]]:
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    return [px[x, y] for y in range(h) for x in range(w)]


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


def pack_atlas(cells: list[Image.Image]) -> Image.Image:
    atlas = Image.new("RGBA", (ATLAS, ATLAS), (0, 0, 0, 0))
    for i, cell in enumerate(cells):
        col = i % ATLAS_COLS
        row = i // ATLAS_COLS
        atlas.paste(cell, (col * CELL, row * CELL), cell)
    return atlas


def main() -> None:
    root = Path(__file__).resolve().parents[1] / "Media"
    root.mkdir(exist_ok=True)

    idle_bg = render_badge(HI_SIZE, (48, 28, 12), (255, 210, 52), (12, 8, 2))
    active_bg = render_badge(HI_SIZE, (255, 214, 48), (22, 14, 6), (8, 6, 2))
    gold = (255, 220, 90)
    black = (18, 12, 6)

    def cell(img: Image.Image) -> Image.Image:
        return img.resize((CELL, CELL), Image.Resampling.LANCZOS)

    cells: list[Image.Image] = []
    for n in range(1, 21):
        cells.append(cell(draw_label(idle_bg, str(n), gold, black)))
    cells.append(cell(draw_label(idle_bg, "?", gold, black)))
    for n in range(1, 21):
        cells.append(cell(draw_label(active_bg, str(n), black, (255, 220, 80))))
    cells.append(cell(draw_label(active_bg, "?", black, (255, 220, 80))))

    atlas = pack_atlas(cells)
    write_tga(root / "PoiAtlas.tga", ATLAS, ATLAS, image_pixels(atlas))
    atlas.save("/tmp/PoiAtlas.png")
    cells[0].save("/tmp/PoiBadge1.png")
    cells[20].save("/tmp/PoiBadgeQ.png")
    cells[21].save("/tmp/PoiBadge1Active.png")

    write_tga(root / "PoiBadge.tga", CELL, CELL, image_pixels(cell(idle_bg)))
    write_tga(root / "PoiBadgeActive.tga", CELL, CELL, image_pixels(cell(active_bg)))
    write_tga(root / "FilledCircle.tga", WASH_SIZE, WASH_SIZE, filled_circle(WASH_SIZE))
    write_tga(root / "ThinRing.tga", WASH_SIZE, WASH_SIZE, ring(WASH_SIZE, WASH_SIZE / 2.0 - 4.0, WASH_SIZE / 2.0 - 0.5))
    write_tga(root / "PinRing.tga", CELL, CELL, ring(CELL, CELL / 2.0 - 3.5, CELL / 2.0 - 0.5))
    print(f"Wrote circle textures in {root}")


if __name__ == "__main__":
    main()
