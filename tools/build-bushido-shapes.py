"""Generate Bushido silhouettes/dividers; preserve the supplied end-cap artwork."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

from texture_utils import save_tga_rle, oriented_masks

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'JiberishIcons/Media/Bushido'


def build():
    OUT.mkdir(exist_ok=True)
    records = []

    def record(path, kind):
        image = Image.open(path).convert('RGBA')
        records.append({'path': path.relative_to(ROOT / 'JiberishIcons').as_posix(),
                        'kind': kind, 'size': list(image.size),
                        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                        'rgbaSha256': hashlib.sha256(image.tobytes()).hexdigest()})

    # Distance is in units of bar height; variants prevent a long bar from
    # stretching its slanted ends. Masks have baked orientations; only the
    # visible border uses UV mirroring/rotation at runtime.
    width, height = 512, 64
    y, x = np.mgrid[:height, :width]
    u, v = (x + .5) / width, (y + .5) / height
    for shape in ('diagonal', 'chamfer'):
        for ratio in range(1, 33):
            xx = u * ratio
            d = np.minimum.reduce([xx, ratio - xx, v, 1 - v])
            if shape == 'diagonal':
                d = np.minimum(d, np.minimum(xx - .45 * v, ratio - xx - .45 * (1 - v)) / np.hypot(1, .45))
            else:
                for edge in (xx + v - .25, ratio - xx + v - .25, xx + 1 - v - .25, ratio - xx + 1 - v - .25):
                    d = np.minimum(d, edge / np.sqrt(2))
            outer = np.clip(.5 + (d - .008) * 32, 0, 1)
            inner = np.clip(.5 + (d - .043) * 32, 0, 1)
            for suffix, alpha in (('mask', outer), ('border', outer - inner)):
                arr = np.full((height, width, 4), 255, dtype=np.uint8)
                arr[:, :, 3] = np.rint(alpha * 255).astype('uint8')
                path = OUT / f'{shape}-{ratio}-{suffix}.tga'
                save_tga_rle(Image.fromarray(arr), path)
                record(path, suffix)
                if suffix == 'mask':
                    for orientation, image in oriented_masks(Image.fromarray(arr), mirror=shape == 'diagonal'):
                        oriented = OUT / f'{shape}-{ratio}-mask{orientation}.tga'
                        save_tga_rle(image, oriented)
                        record(oriented, 'orientedMask')
    # White line occupies the central third; soft side margins survive rotation.
    axis = (np.arange(64) + .5) / 64 * 3 - 1.5
    alpha = np.clip(.5 + (.5 - np.abs(axis)) * 4, 0, 1)
    arr = np.full((16, 64, 4), 255, dtype=np.uint8)
    arr[:, :, 3] = np.rint(alpha[None, :] * 255).astype('uint8')
    save_tga_rle(Image.fromarray(arr), OUT / 'divider.tga')
    record(OUT / 'divider.tga', 'divider')
    # This file is user-supplied artwork, not generated or modified here.
    record(OUT / 'BushidoEndPoint.tga', 'artwork')
    (ROOT / 'tests/fixtures/bushido-textures.json').write_text(json.dumps({
        'description': 'Procedural bar masks/outlines and divider; BushidoEndPoint.tga supplied via JiberishUI_Ellesmere, preserved byte for byte.',
        'textures': records,
    }, indent=2) + '\n')
    print(f'Validated {len(records)} Bushido assets')


if __name__ == '__main__':
    build()
