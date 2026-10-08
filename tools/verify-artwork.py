"""Verify shipped textures and Lua mappings without keeping draft art in Git."""
import hashlib
import json
import re
from addon_files import ROOT, ADDON, required_files
from texture_utils import load_tga
from PIL import Image
from build_details_atlas import compose


def main():
    sha = lambda data: hashlib.sha256(data).hexdigest()
    fixtures = json.loads((ROOT / 'tests/fixtures/textures.json').read_text())['textures']
    api = (ADDON / 'Core/API.lua').read_text()
    core = (ADDON / 'Core/Core.lua').read_text()
    spec_code = (ADDON / 'Core/Specializations.lua').read_text()
    specs = re.findall(r"\{(\d+), '([^']+)', '([A-Z]+)'\}", spec_code)
    assert len(specs) == 40 and len({s[0] for s in specs}) == 40
    races = re.findall(r"\{\s*'([A-Z]+)'", api.split('JI.dataHelper.raceOrder = {', 1)[1].split('\n}', 1)[0])
    assert len(races) == 26
    cell_count = 0
    for texture in fixtures:
        path = ADDON / texture['path']
        assert sha(path.read_bytes()) == texture['sha256'], path
        im = load_tga(path)
        assert im.mode == 'RGBA' and list(im.size) == texture['size'], path
        assert sha(im.tobytes()) == texture['rgbaSha256'], path
        if texture['kind'] == 'Logo':
            continue
        style, cell = texture['style'], texture['cellSize']
        block = re.search(r'\b' + style + r'\s*=\s*\{([^}]+)', core)[1]
        declared = re.search(r'textureSize\s*=\s*(\d+)', block)
        assert (int(declared[1]) if declared else 1024) == im.width
        if texture['kind'] == 'DetailsSpec':
            layout = json.loads((ROOT / 'tests/fixtures/details-spec-layout.json').read_text())
            source_record = next(t for t in fixtures if t['path'] == texture['source'])
            expected, records = compose(load_tga(ADDON / texture['source']), source_record, layout)
            assert im.tobytes() == expected.tobytes() and texture['icons'] == records
            file_name = re.search(r"detailsFileName\s*=\s*'([^']+)'", block)[1]
            assert path.stem == file_name
        used = set()
        for index, icon in enumerate(texture['icons']):
            x, y = icon['cell']; used.add((x, y))
            tile = im.crop((x*cell, y*cell, (x+1)*cell, (y+1)*cell))
            assert sha(tile.tobytes()) == icon['rgbaSha256'], icon['id']
            margin = texture.get('margin')
            if margin:
                bounds = tile.getchannel('A').getbbox()
                assert bounds and min(bounds[:2]) >= margin and max(bounds[2:]) <= cell-margin, icon['id']
            if texture['kind'] == 'Class':
                match = re.search(r'\b' + icon['class'] + r"\s*=\s*\{\s*texString\s*=\s*'([^']+)'", api)
                assert match[1] == f'{x*128}:{(x+1)*128}:{y*128}:{(y+1)*128}'
            elif texture['kind'] == 'Race':
                assert icon['id'][5:].upper() == races[index] and [x, y] == [index % 8, index // 8]
            elif texture['kind'] == 'Spec':
                entry = specs[y*8+x]
                assert [int(entry[0]), entry[1], entry[2]] == [icon['specId'], icon['label'], icon['class']]
            cell_count += 1
        assert len(used) == len(texture['icons'])
        if texture.get('emptyUnusedCells'):
            for y in range(8):
                for x in range(8):
                    if (x, y) not in used:
                        assert im.crop((x*cell, y*cell, (x+1)*cell, (y+1)*cell)).getchannel('A').getbbox() is None
    toc = (ADDON / 'JiberishIcons.toc').read_text()
    portraits = json.loads((ROOT / 'tests/fixtures/portrait-textures.json').read_text())['textures']
    for texture in portraits:
        path = ADDON / texture['path']
        assert sha(path.read_bytes()) == texture['sha256'], path
        im = load_tga(path)
        assert list(im.size) == texture['size'] and im.width == im.height, path
        assert im.width in (32, 64, 128, 256, 512, 1024), path
        assert sha(im.tobytes()) == texture['rgbaSha256'], path
        assert Image.open(path).convert('RGBA').tobytes() == im.tobytes(), path
        alpha_min, alpha_max = im.getchannel('A').getextrema()
        assert alpha_min == 0 and alpha_max > 0, path
        data = path.read_bytes()
        assert data[1:3] == bytes((0, 2)) and data[16] == 32 and data[17] & 15 == 8, path
        assert any(0 < value < 255 for value in im.getchannel('A').tobytes()), path
    families = {texture['shape'] for texture in portraits}
    assert len(families) == 10 and len(portraits) == 60
    for family in families:
        assert {t['size'][0] for t in portraits if t['shape'] == family} == {32, 64, 128, 256, 512, 1024}
    print(f'PASS {len(portraits)} portrait TGAs, standard decoders, alpha and all six size variants')
    assert '## SavedVariables: JiberishIconsDB' in toc
    assert r'Interface\AddOns\JiberishIcons\Media\Logo\SmallLogo' in toc
    files = required_files()
    print(f'PASS {len(fixtures)} approved textures, {cell_count} cells, all mappings and {len(files)} required addon files')


if __name__ == '__main__':
    main()
