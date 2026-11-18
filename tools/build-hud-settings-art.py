"""Draw the nav tape and aura timeline glyphs for the settings tree.

Standard-library only, so it runs without Pillow. The look matches
build-settings-art.py: 2.8-unit rounded strokes on a 32-unit grid, exported at
64 px in light gray with coverage alpha (8x8 samples per pixel). Output is a
standard RLE-compressed 32-bit TGA with 8-bit alpha, bottom-left origin.
"""
from pathlib import Path
import hashlib
import json
import math
import struct

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'JiberishIcons/Media/Settings'
FIXTURE = ROOT / 'tests/fixtures/hud-settings-textures.json'
SIZE, GRID, SAMPLES, STROKE = 64, 32, 8, 2.8
COLOR = (242, 245, 250)


def segment_distance(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    length = dx * dx + dy * dy
    t = 0 if length == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def inside_polygon(px, py, points):
    hit = False
    for index, (ax, ay) in enumerate(points):
        bx, by = points[index - 1]
        if (ay > py) != (by > py) and px < (bx - ax) * (py - ay) / (by - ay) + ax:
            hit = not hit
    return hit


def shapes(name):
    """(strokes, polygons, discs) in grid units."""
    if name == 'navtape':
        strokes = [[(4, 25), (28, 25)], [(5, 25), (5, 19)], [(10.5, 25), (10.5, 21)],
                   [(21.5, 25), (21.5, 21)], [(27, 25), (27, 19)], [(16, 25), (16, 13)]]
        return strokes, [[(10.5, 4), (21.5, 4), (16, 10.5)]], []
    if name == 'timeline':
        def box(x0, y0, x1, y1):
            return [(x0, y0), (x1, y0), (x1, y1), (x0, y1), (x0, y0)]
        strokes = [[(5, 27), (29, 27)], box(6, 4, 14, 12), [(10, 12), (10, 27)],
                   box(18, 10, 26, 18), [(22, 18), (22, 27)]]
        return strokes, [], [(4, 27, 3.2)]
    raise ValueError(name)


def render(name):
    strokes, polygons, discs = shapes(name)
    segments = [(a[0], a[1], b[0], b[1]) for line in strokes for a, b in zip(line, line[1:])]
    radius = STROKE / 2
    unit = GRID / SIZE
    rows = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            hits = 0
            for sy in range(SAMPLES):
                gy = (y + (sy + 0.5) / SAMPLES) * unit
                for sx in range(SAMPLES):
                    gx = (x + (sx + 0.5) / SAMPLES) * unit
                    if (any(segment_distance(gx, gy, *s) <= radius for s in segments)
                            or any(inside_polygon(gx, gy, p) for p in polygons)
                            or any(math.hypot(gx - cx, gy - cy) <= r for cx, cy, r in discs)):
                        hits += 1
            row.append(round(255 * hits / (SAMPLES * SAMPLES)))
        rows.append(row)
    return rows  # alpha, top row first


def rgba_bytes(alpha):
    return b''.join(bytes((*COLOR, a)) for row in alpha for a in row)


def encode_tga(alpha):
    header = bytearray(18)
    header[2] = 10
    struct.pack_into('<HH', header, 12, SIZE, SIZE)
    header[16], header[17] = 32, 8
    body = bytearray()
    for row in reversed(alpha):  # bottom-left origin
        pixels = [bytes((COLOR[2], COLOR[1], COLOR[0], a)) for a in row]
        index = 0
        while index < len(pixels):
            run = 1
            while index + run < len(pixels) and run < 128 and pixels[index + run] == pixels[index]:
                run += 1
            if run > 1:
                body.append(0x80 | (run - 1)); body.extend(pixels[index])
                index += run
                continue
            # A raw packet runs until the next repeated pair (or 128 pixels).
            start, index = index, index + 1
            while index < len(pixels) and index - start < 128 and not (
                    index + 1 < len(pixels) and pixels[index] == pixels[index + 1]):
                index += 1
            body.append(index - start - 1)
            for pixel in pixels[start:index]:
                body.extend(pixel)
    return bytes(header + body)


def decode_tga(data):
    """Independent reader for the files this tool writes: RGBA rows, top first."""
    assert data[2] == 10 and data[16] == 32 and data[17] & 15 == 8
    width, height = struct.unpack_from('<HH', data, 12)
    offset, raw = 18 + data[0], bytearray()
    while len(raw) < width * height * 4:
        packet = data[offset]; offset += 1
        count = (packet & 127) + 1
        if packet & 128:
            raw.extend(data[offset:offset + 4] * count); offset += 4
        else:
            raw.extend(data[offset:offset + count * 4]); offset += count * 4
    rows = [raw[i * width * 4:(i + 1) * width * 4] for i in range(height)]
    if not data[17] & 32:
        rows.reverse()
    out = bytearray()
    for row in rows:
        for i in range(0, len(row), 4):
            b, g, r, a = row[i:i + 4]
            out.extend((r, g, b, a))
    return width, height, bytes(out)


NAMES = ('navtape', 'timeline')


def build():
    records = []
    for name in NAMES:
        alpha = render(name)
        data = encode_tga(alpha)
        assert decode_tga(data) == (SIZE, SIZE, rgba_bytes(alpha)), 'lossless encoding failed'
        path = FOLDER / (name + '.tga')
        path.write_bytes(data)
        records.append({'path': path.relative_to(ROOT / 'JiberishIcons').as_posix(), 'size': [SIZE, SIZE],
                        'sha256': hashlib.sha256(data).hexdigest(),
                        'rgbaSha256': hashlib.sha256(rgba_bytes(alpha)).hexdigest()})
    FIXTURE.write_text(json.dumps({'textures': records}, indent=2) + '\n')
    print(f'Built {len(records)} settings glyphs')


if __name__ == '__main__':
    build()
