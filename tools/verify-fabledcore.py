"""Check Fabled Core's export, cell mapping, and the unchanged texture sheets."""
import hashlib
import json
import re
import struct
from pathlib import Path

from PIL import Image

root = Path(__file__).resolve().parents[1]
art = root / 'artwork/fabledcore'
addon = root / 'ElvUI_JiberishIcons'
manifest = json.loads((art / 'manifest.json').read_text())
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
source_path = art / 'originals/fabledcore.tga'
output_path = addon / 'Media/Class/fabledcore.tga'
assert sha(source_path) == manifest['source_sha256']
assert sha(output_path) == manifest['output_sha256']
source = Image.open(source_path)
assert source.size == (1024, 1024) and source.mode == 'RGBA'
assert source.tobytes() == Image.open(art / 'originals/fabledcore.png').tobytes()

# Decode BGRA/RLE independently of the Pillow encoder. Both origin bits matter.
data = output_path.read_bytes()
width, height = struct.unpack_from('<HH', data, 12)
assert data[1:3] == bytes([0, 10]) and data[16] == 32 and data[17] & 15 == 8
assert (width, height) == (2048, 2048)
assert manifest['canvas'] == [width, height] and manifest['cell'] == [256, 256]
assert width & (width - 1) == 0
offset = 18 + data[0]
raw = bytearray()
while len(raw) < width * height * 4:
    packet = data[offset]
    offset += 1
    count = (packet & 127) + 1
    length = 4 if packet & 128 else count * 4
    assert offset + length <= len(data)
    payload = data[offset:offset + length]
    raw.extend(payload * count if packet & 128 else payload)
    offset += length
assert len(raw) == width * height * 4
decoded = Image.frombytes('RGBA', (width, height), bytes(raw), 'raw', 'BGRA')
if not data[17] & 32:
    decoded = decoded.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
if data[17] & 16:
    decoded = decoded.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
assert decoded.tobytes() == Image.open(art / 'fabledcore.png').tobytes()
assert decoded.tobytes() == Image.open(output_path).tobytes()

registry = (addon / 'Core/Core.lua').read_text()
block = re.search(r'fabledcore\s*=\s*\{([^}]+)', registry)[1]
assert re.search(r'textureSize\s*=\s*2048\b', block)
api = (addon / 'Core/API.lua').read_text()
assert len(manifest['assets']) == 13
used = set()
for asset in manifest['assets']:
    col, row = asset['cell']
    assert (col, row) not in used
    used.add((col, row))
    token = asset['name'].replace(' ', '').upper()
    block = re.search(r'\b' + token + r'\s*=\s*\{\s*texString\s*=\s*\x27([^\x27]+)', api)
    assert block and block[1] == f'{col*128}:{(col+1)*128}:{row*128}:{(row+1)*128}'
    cell = decoded.crop((col*256, row*256, (col+1)*256, (row+1)*256))
    icon_path = art / 'icons' / (token.lower() + '.png')
    assert sha(icon_path) == asset['icon_sha256']
    assert cell.tobytes() == Image.open(icon_path).tobytes()
    bounds = cell.getchannel('A').getbbox()
    assert bounds and min(bounds[:2]) >= 2 and max(bounds[2:]) <= 254
    # No recentering, trimming, or layout shifts; allow the resampling kernel's
    # three-pixel support to widen very faint edges after enlargement.
    old_bounds = source.crop((col*128, row*128, (col+1)*128, (row+1)*128)).getchannel('A').getbbox()
    assert all(abs(a - b*2) <= 6 for a, b in zip(bounds, old_bounds))
for row in range(8):
    for col in range(8):
        if (col, row) not in used:
            assert decoded.crop((col*256, row*256, (col+1)*256, (row+1)*256)).getchannel('A').getbbox() is None
preserved = json.loads((art / 'unchanged-textures.json').read_text())
for relative, expected in preserved.items():
    assert sha(addon / relative) == expected, f'Unexpected texture change: {relative}'
print(f'PASS Fabled Core: 13 cells, independent RLE decode, exact PNG match, alpha margins, preserved placement and Lua mapping')
print(f'PASS {len(preserved)} other textures byte-identical to rc.3, including all eight other legacy sets')
