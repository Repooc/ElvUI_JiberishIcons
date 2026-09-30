"""Lay out the approved spec icons without repainting or adding text."""
import argparse
import json
from pathlib import Path
from PIL import Image
from addon_files import ROOT, ADDON


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--masters', type=Path, help='Optional high-resolution transparent cutouts')
    parser.add_argument('--background', default='#17191c', help='Solid background color (default: dark gray)')
    args = parser.parse_args()
    textures = json.loads((ROOT / 'tests/fixtures/textures.json').read_text())['textures']
    texture = next(t for t in textures if t['style'] == 'fabledspecializations')
    atlas = Image.open(ADDON / texture['path']).convert('RGBA')
    board = Image.new('RGBA', (3200, 2000), args.background)
    for index, item in enumerate(texture['icons']):
        if args.masters:
            art = Image.open(args.masters / (item['id'] + '.png')).convert('RGBA')
        else:
            x, y = item['cell']; cell = texture['cellSize']
            art = atlas.crop((x*cell, y*cell, (x+1)*cell, (y+1)*cell))
        art = art.crop(art.getchannel('A').getbbox())
        art.thumbnail((328, 328), Image.Resampling.LANCZOS)
        x, y = (index % 8)*400, (index // 8)*400
        board.alpha_composite(art, (x+(400-art.width)//2, y+(400-art.height)//2))
    output = ROOT / 'images/FabledSpecializationsSocial.png'
    board.convert('RGB').save(output, optimize=True)
    print(f'Created {output}: all 40 icons, 3200 × 2000, background {args.background}, no text')


if __name__ == '__main__':
    main()
