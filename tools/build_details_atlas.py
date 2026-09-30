"""Build Details' fixed-layout atlas from approved icons; no generated art inputs."""
import hashlib
import json
from PIL import Image
from addon_files import ROOT, ADDON
from texture_utils import load_tga

SOURCE = 'Media/Spec/fabledspecializations.tga'
OUTPUT = 'Media/Spec/spec_fabledspecializations.tga'


def compose(source, source_record, layout):
    size, cell = source.width, source_record['cellSize']
    scale = size // layout['referenceSize']
    icons = {str(icon['specId']): icon for icon in source_record['icons']}
    assert set(icons) == set(layout['coordinates'])
    image = Image.new('RGBA', source.size)
    records = []
    for spec_id, crop in list(layout['coordinates'].items()) + list(layout['retailOverrides'].items()):
        left, right, top, bottom = [value * scale for value in crop]
        x, y = left // cell, top // cell
        assert right == (x + 1) * cell and bottom == (y + 1) * cell and top == y * cell
        icon = icons[spec_id]
        sx, sy = icon['cell']
        tile = source.crop((sx*cell, sy*cell, (sx+1)*cell, (sy+1)*cell))
        # Details slightly trims Arcane, Retribution and Shadow's left edges.
        # Recenter within those crops by translation only; preserve every inked pixel.
        inset = left - x*cell
        assert inset % 2 == 0
        offset = inset // 2
        bounds = tile.getchannel('A').getbbox()
        margin = source_record['margin']
        assert bounds[0] + offset >= inset + margin and bounds[2] + offset <= cell - margin, spec_id
        translated = Image.new('RGBA', (cell, cell))
        translated.paste(tile, (offset, 0))
        image.paste(translated, (x*cell, y*cell))
        records.append({**icon, 'id': icon['id'] + f'-details-{x}-{y}', 'cell': [x, y],
                        'rgbaSha256': hashlib.sha256(translated.tobytes()).hexdigest()})
    assert len({tuple(icon['cell']) for icon in records}) == len(records)
    return image, records


def main():
    fixture_path = ROOT / 'tests/fixtures/textures.json'
    fixture = json.loads(fixture_path.read_text())
    record = next(t for t in fixture['textures'] if t['path'] == SOURCE)
    source = load_tga(ADDON / SOURCE)
    assert hashlib.sha256(source.tobytes()).hexdigest() == record['rgbaSha256']
    layout = json.loads((ROOT / 'tests/fixtures/details-spec-layout.json').read_text())
    image, icons = compose(source, record, layout)
    output = ADDON / OUTPUT
    image.save(output, compression='tga_rle')
    details = {**record, 'path': OUTPUT, 'kind': 'DetailsSpec', 'source': SOURCE,
               'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
               'rgbaSha256': hashlib.sha256(image.tobytes()).hexdigest(), 'icons': icons}
    fixture['textures'] = [t for t in fixture['textures'] if t['path'] != OUTPUT] + [details]
    fixture_path.write_text(json.dumps(fixture, indent=2) + '\n')
    print(f'{output}: {len(icons)} cells for all 40 specs and both Rogue layouts')


if __name__ == '__main__':
    main()
