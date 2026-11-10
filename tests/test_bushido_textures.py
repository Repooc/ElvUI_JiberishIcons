"""Verify Bushido shipping assets and geometry independently of WoW."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from texture_utils import load_tga


class BushidoTextures(unittest.TestCase):
    def test_assets_are_standard_tga_and_match_manifest(self):
        records = json.loads((ROOT / 'tests/fixtures/bushido-textures.json').read_text())['textures']
        self.assertEqual(len(records), 258)
        expected = {f'Media/Bushido/{shape}-{ratio}-{suffix}.tga'
                    for shape in ('diagonal', 'chamfer') for ratio in range(1, 33)
                    for suffix in ('mask', 'border')}
        expected |= {'Media/Bushido/divider.tga', 'Media/Bushido/BushidoEndPoint.tga'}
        expected |= {f'Media/Bushido/{shape}-{ratio}-mask{suffix}.tga'
                     for shape in ('diagonal', 'chamfer') for ratio in range(1, 33)
                     for suffix in (('-vertical', '-reverse', '-reverse-vertical') if shape == 'diagonal' else ('-vertical',))}
        self.assertEqual({r['path'] for r in records}, expected)
        for record in records:
            with self.subTest(path=record['path']):
                path = ROOT / 'JiberishIcons' / record['path']
                raw = path.read_bytes()
                self.assertEqual(hashlib.sha256(raw).hexdigest(), record['sha256'])
                self.assertEqual(raw[1:3], bytes((0, 2 if record['kind'] == 'artwork' else 10)))
                self.assertEqual(raw[16], 32)
                self.assertEqual(raw[17] & 15, 8)
                image = load_tga(path)
                self.assertEqual(image.tobytes(), Image.open(path).convert('RGBA').tobytes())
                self.assertEqual(hashlib.sha256(image.tobytes()).hexdigest(), record['rgbaSha256'])
                self.assertEqual(list(image.size), record['size'])
                alpha = image.getchannel('A')
                self.assertGreater(alpha.getextrema()[1], 0)
                self.assertTrue(any(0 < a < 255 for a in alpha.tobytes()))
                if record['kind'] in ('mask', 'border'):
                    self.assertLess(alpha.getpixel((0, 0)), 255)
                    self.assertEqual(alpha.getpixel((256, 32)), 255 if record['kind'] == 'mask' else 0)

    def test_outline_is_inside_mask_and_shape_ends_follow_bar_aspect(self):
        for shape in ('diagonal', 'chamfer'):
            for ratio in (1, 2, 6, 16, 32):
                mask = load_tga(ROOT / f'JiberishIcons/Media/Bushido/{shape}-{ratio}-mask.tga').getchannel('A')
                border = load_tga(ROOT / f'JiberishIcons/Media/Bushido/{shape}-{ratio}-border.tga').getchannel('A')
                self.assertTrue(all(b <= m for b, m in zip(border.tobytes(), mask.tobytes())))
                if shape == 'diagonal':
                    # Width in height units stays ~.45 regardless of long bars.
                    row = [mask.getpixel((x, 62)) for x in range(512)]
                    first = next(x for x, alpha in enumerate(row) if alpha > 127)
                    self.assertAlmostEqual(first / 512 * ratio, .45 * (62.5 / 64) + .008, delta=.07)


if __name__ == '__main__':
    unittest.main()
