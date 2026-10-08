"""Build analytic portrait geometry as game-compatible 32-bit TGA textures.

Borders and masks share the same distance field. Each size is area sampled directly
from the geometry so small UI sizes retain smooth curves rather than compressed
4x4 alpha blocks. No artwork-generation service or third-party assets are needed.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SIZE = 1024
SIZES = (32, 64, 128, 256, 512, 1024)


def render(size, shape, thin=False, mask=False, mirror=False):
    samples = 4
    axis = (np.arange(size * samples, dtype=np.float32) + .5) / (size * samples) - .5
    x, y = axis[None, :], axis[:, None]
    if mirror:
        x = -x
    radius, width = .433, .021 if thin else .055
    if shape == 'circle':
        distance = np.sqrt(x*x + y*y) - radius
    else:
        # Three circular quadrants meet a gently rounded droplet tip.
        corner = np.where((x > 0) & (y > 0), .035, radius)
        qx, qy = np.abs(x) - radius + corner, np.abs(y) - radius + corner
        distance = np.sqrt(np.maximum(qx, 0)**2 + np.maximum(qy, 0)**2) + np.minimum(np.maximum(qx, qy), 0) - corner
    if mask:
        # A tiny overlap beneath the rim avoids a transparent hairline seam.
        alpha = (distance <= -width + .0015).astype(np.float32)
        premultiplied = alpha.copy()
    else:
        ring = ((distance <= 0) & (distance >= -width)).astype(np.float32)
        shadow_distance = np.maximum(np.maximum(distance, -width - distance), 0)
        shadow = np.exp(-.5 * (shadow_distance / .009)**2) * .55
        shadow[shadow_distance > .036] = 0
        alpha = ring + shadow * (1 - ring)
        # Subtle neutral bevel; white remains tintable through SetVertexColor.
        shade = np.clip(.94 - y * .14, .82, 1)
        premultiplied = ring * shade
    alpha = alpha.reshape(size, samples, size, samples).mean(axis=(1, 3))
    premultiplied = premultiplied.reshape(size, samples, size, samples).mean(axis=(1, 3))
    gray = np.divide(premultiplied, alpha, out=np.ones_like(alpha), where=alpha > 0)
    rgba = np.empty((size, size, 4), dtype=np.uint8)
    rgba[:, :, :3] = np.rint(gray[:, :, None] * 255).astype(np.uint8)
    rgba[:, :, 3] = np.rint(alpha * 255).astype(np.uint8)
    return Image.fromarray(rgba)


def build():
    out = ROOT / 'JiberishIcons/Media/Portraits'
    out.mkdir(exist_ok=True)
    records = []
    for shape in ('circle', 'droplet'):
        for thin in (False, True):
            name = shape + ('-thin' if thin else '')
            variants = [(name, False, False), (name + '-mask', True, False)]
            if shape == 'droplet':
                variants.append(('droplet-left' + ('-thin' if thin else '') + '-mask', True, True))
            for filename, mask, mirror in variants:
                for size in SIZES:
                    image = render(size, shape, thin, mask, mirror)
                    suffix = '' if size == SIZE else '-' + str(size)
                    path = out / (filename + suffix + '.tga')
                    image.save(path, format='TGA', compression=None)
                    records.append({'path': path.relative_to(ROOT / 'JiberishIcons').as_posix(),
                                    'size': [size, size], 'shape': filename,
                                    'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                                    'rgbaSha256': hashlib.sha256(image.tobytes()).hexdigest()})
                # Remove only this generator's rejected encoding, never user art.
                (out / (filename + '.blp')).unlink(missing_ok=True)
    (ROOT / 'tests/fixtures/portrait-textures.json').write_text(json.dumps({
        'description': 'Analytic circle/droplet borders and masks. Uncompressed 32-bit TGA with 8-bit alpha in six independently area-sampled sizes.',
        'textures': records}, indent=2) + '\n')
    print(f'Built {len(records)} 32-bit TGA portrait textures at 32–1024px')


if __name__ == '__main__':
    build()
