"""Resample only Fabled Core's original artwork; requires Pillow, no generation."""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'artwork/fabledcore'
SOURCE = ART / 'originals/fabledcore.tga'
OUTPUT = ROOT / 'ElvUI_JiberishIcons/Media/Class/fabledcore.tga'
CELLS = {
    'Warrior': (0, 0), 'Mage': (1, 0), 'Rogue': (2, 0),
    'Druid': (3, 0), 'Evoker': (4, 0), 'Hunter': (0, 1),
    'Shaman': (1, 1), 'Priest': (2, 1), 'Warlock': (3, 1),
    'Paladin': (0, 2), 'Death Knight': (1, 2), 'Monk': (2, 2),
    'Demon Hunter': (3, 2),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    original = Image.open(SOURCE)
    assert original.mode == 'RGBA' and original.size == (1024, 1024)
    atlas = Image.new('RGBA', (2048, 2048))
    (ART / 'icons').mkdir(exist_ok=True)
    assets = []
    preview = Image.new('RGB', (1120, 7 * 292 + 75), '#181e27')
    draw = ImageDraw.Draw(preview)
    draw.text((20, 12), 'Fabled Core: original artwork, 128px cells exported at 256px', fill='#f2d5a2')
    draw.text((20, 32), 'Each pair: old enlarged with bilinear filtering / new export. Simulated comparison, not an in-game capture.', fill='#bbc6d4')
    for index, (name, (col, row)) in enumerate(CELLS.items()):
        source = original.crop((col * 128, row * 128, (col + 1) * 128, (row + 1) * 128))
        # Pillow resizes RGBA in premultiplied-alpha space. Isolating each cell
        # prevents the interpolation kernel from sampling an adjacent icon.
        scaled = source.resize((256, 256), Image.Resampling.LANCZOS)
        tile = scaled.convert('RGB').filter(ImageFilter.UnsharpMask(radius=0.8, percent=45, threshold=3))
        tile.putalpha(scaled.getchannel('A'))
        # Paste without a mask: copy alpha exactly, without compositing twice.
        atlas.paste(tile, (col * 256, row * 256))
        icon_path = ART / 'icons' / (name.lower().replace(' ', '') + '.png')
        tile.save(icon_path)
        assets.append({'name': name, 'cell': [col, row], 'icon_sha256': sha(icon_path)})
        x, y = (index % 2) * 560, (index // 2) * 292 + 75
        draw.text((x + 12, y), name + ' — old / new', fill='white')
        preview.paste(source.resize((256, 256), Image.Resampling.BILINEAR), (x + 12, y + 20),
                      source.resize((256, 256), Image.Resampling.BILINEAR))
        preview.paste(tile, (x + 286, y + 20), tile)
    atlas.save(ART / 'fabledcore.png')
    # Lossless RLE, BGRA32 with 8-bit alpha. RLE was also used by the original
    # Core sheet; it reduces file size without quantization or extra GPU savings.
    atlas.save(OUTPUT, compression='tga_rle')
    preview.save(ART / 'comparison.png')
    manifest = {
        'canvas': [2048, 2048], 'cell': [256, 256],
        'source_canvas': [1024, 1024], 'source_cell': [128, 128],
        'source_sha256': sha(SOURCE), 'output_sha256': sha(OUTPUT),
        'method': 'Per-cell alpha-aware Lanczos; RGB unsharp radius 0.8, percent 45, threshold 3; unchanged placement',
        'format': 'Lossless RLE 32-bit TGA with 8-bit alpha', 'assets': assets,
    }
    (ART / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Fabled Core: {len(assets)} unchanged designs, 256px cells, 2048px atlas, {OUTPUT.stat().st_size:,} bytes')


if __name__ == '__main__':
    main()
