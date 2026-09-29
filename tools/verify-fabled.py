"""Validate exported artwork with Pillow, independently of the Sharp exporter."""
import hashlib
import json
import re
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
art = root / 'artwork/fabled'
manifest = json.loads((art / 'manifest.json').read_text())
atlas_size, cell_size, margin = 2048, 256, 4
assert manifest['canvas'] == [atlas_size, atlas_size]
assert manifest['cell'] == [cell_size, cell_size]
assert atlas_size & (atlas_size - 1) == 0 and cell_size & (cell_size - 1) == 0
registry = (root / 'ElvUI_JiberishIcons/Core/Core.lua').read_text()
for style in ['fabledregalia', 'fabledazeroth']:
    block = re.search(style + r'\s*=\s*\{([^}]+)', registry)[1]
    assert re.search(r'textureSize\s*=\s*2048\b', block)
api = (root / 'ElvUI_JiberishIcons/Core/API.lua').read_text()
race_block = api.split('JI.dataHelper.raceOrder = {', 1)[1].split('\n}', 1)[0]
race_tokens = re.findall(r"\{\s*'([A-Z]+)'", race_block)
assert len(race_tokens) == 26
assert len(manifest['assets']) == 39

for pack, kind, count in [('fabledregalia', 'Class', 13), ('fabledazeroth', 'Race', 26)]:
    tga = Image.open(root / f'ElvUI_JiberishIcons/Media/{kind}/{pack}.tga')
    png = Image.open(art / f'{pack}.png')
    realm = Image.open(root / 'ElvUI_JiberishIcons/Media/Class/fabledrealm.tga')
    assert tga.mode == png.mode == realm.mode == 'RGBA'
    assert tga.size == png.size == (atlas_size, atlas_size)
    assert realm.size == (1024, 1024)
    assert tga.tobytes() == png.tobytes(), 'TGA channel order/orientation mismatch'
    assets = [a for a in manifest['assets'] if a['pack'] == pack]
    assert len(assets) == count
    used = set()
    for index, asset in enumerate(assets):
        col, row = asset['cell']
        assert (col, row) not in used
        used.add((col, row))
        icon_path = art / 'icons' / (asset['id'] + '.png')
        icon = Image.open(icon_path)
        assert icon.mode == 'RGBA' and icon.size == (cell_size, cell_size)
        assert hashlib.sha256(icon_path.read_bytes()).hexdigest() == asset['icon_sha256']
        master = art / 'transparent' / (asset['id'] + '.png')
        assert hashlib.sha256(master.read_bytes()).hexdigest() == asset['source_sha256']
        bounds = icon.getchannel('A').getbbox()
        assert bounds and bounds[0] >= margin and bounds[1] >= margin and bounds[2] <= cell_size-margin and bounds[3] <= cell_size-margin
        cell = tga.crop((col * cell_size, row * cell_size, (col + 1) * cell_size, (row + 1) * cell_size))
        assert cell.tobytes() == icon.tobytes(), 'Atlas cell differs from individual icon'
        if kind == 'Race':
            assert asset['id'][5:].upper() == race_tokens[index]
            assert [col, row] == [index % 8, index // 8]
        else:
            token = asset['id'][6:].upper()
            block = re.search(r'\b' + token + r'\s*=\s*\{\s*texString\s*=\s*\x27([^\x27]+)', api)
            assert block and block[1] == f'{col*128}:{(col+1)*128}:{row*128}:{(row+1)*128}'
    for row in range(8):
        for col in range(8):
            if (col, row) not in used:
                assert tga.crop((col*cell_size, row*cell_size, (col+1)*cell_size, (row+1)*cell_size)).getchannel('A').getbbox() is None
    print(f'PASS {pack}: {count} cells, exact TGA/PNG match, real alpha, clear margins, correct Lua mapping')
