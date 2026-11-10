"""Build tintable crosshair and hollow GCD geometry as standard 32-bit TGAs."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

from texture_utils import save_tga_rle

ROOT = Path(__file__).resolve().parents[1]
SIZES = (32, 64, 128, 256)
SHAPES = ('plus', 'x', 'splitplus', 'splitx', 'circle', 'diamond', 'square', 'triangle')


def render(size, shape, bold):
    samples = 8
    axis = (np.arange(size * samples, dtype=np.float32) + .5) / (size * samples) - .5
    x, y = np.broadcast_arrays(axis[None, :], axis[:, None])
    width = .065 if bold else .03
    if shape in ('plus', 'x', 'splitplus', 'splitx'):
        if shape in ('x', 'splitx'):
            x, y = (x + y) / np.sqrt(2), (y - x) / np.sqrt(2)
        along, across = np.maximum(np.abs(x), np.abs(y)), np.minimum(np.abs(x), np.abs(y))
        ink = (along <= .44) & (across <= width / 2)
        if shape.startswith('split'):
            ink &= along >= .12
    else:
        # Distance to each convex boundary, positive inside. Subtract an inset
        # of constant perpendicular thickness so corners remain crisp.
        if shape == 'circle':
            inside = .44 - np.sqrt(x*x + y*y)
        elif shape == 'square':
            inside = .43 - np.maximum(np.abs(x), np.abs(y))
        elif shape == 'diamond':
            inside = (.46 - np.abs(x) - np.abs(y)) / np.sqrt(2)
        else:
            # Apex at the top, base at the bottom; origin lies inside the shape
            # so a native radial cooldown sweep reaches the entire outline.
            inside = np.minimum(.40 - y, (.44 * y - .84 * np.abs(x) + .1936) / np.hypot(.44, .84))
        ink = (inside >= 0) & (inside <= width)
    alpha = ink.reshape(size, samples, size, samples).mean(axis=(1, 3))
    rgba = np.full((size, size, 4), 255, dtype=np.uint8)
    rgba[:, :, 3] = np.rint(alpha * 255).astype(np.uint8)
    return Image.fromarray(rgba)


def build():
    folder = ROOT / 'JiberishIcons/Media/Crosshair'
    folder.mkdir(exist_ok=True)
    records = []
    for shape in SHAPES:
        for bold in (False, True):
            for size in SIZES:
                image = render(size, shape, bold)
                path = folder / f'{shape}-{"bold" if bold else "thin"}-{size}.tga'
                save_tga_rle(image, path)
                records.append({
                    'path': path.relative_to(ROOT / 'JiberishIcons').as_posix(),
                    'shape': shape, 'weight': 'bold' if bold else 'thin', 'size': [size, size],
                    'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                    'rgbaSha256': hashlib.sha256(image.tobytes()).hexdigest(),
                })
    (ROOT / 'tests/fixtures/crosshair-textures.json').write_text(json.dumps({
        'description': 'Analytic crosshairs and hollow GCD outlines; white tintable 32-bit TGA, area sampled at four sizes.',
        'textures': records,
    }, indent=2) + '\n')
    print(f'Built {len(records)} crosshair/GCD textures')


if __name__ == '__main__':
    build()
