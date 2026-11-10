"""Validate shipping geometry, alpha, native texture encoding and approved bytes."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from texture_utils import load_tga


class CrosshairTextures(unittest.TestCase):
    def test_all_variants_decode_and_preserve_hollow_outlines(self):
        records = json.loads((ROOT / 'tests/fixtures/crosshair-textures.json').read_text())['textures']
        expected = {(shape, weight, size) for shape in
                    ('plus', 'x', 'splitplus', 'splitx', 'circle', 'diamond', 'square', 'triangle')
                    for weight in ('thin', 'bold') for size in (32, 64, 128, 256)}
        self.assertEqual({(r['shape'], r['weight'], r['size'][0]) for r in records}, expected)
        self.assertEqual(len(records), len(expected))
        for record in records:
            with self.subTest(path=record['path']):
                path = ROOT / 'JiberishIcons' / record['path']
                raw = path.read_bytes()
                self.assertEqual(hashlib.sha256(raw).hexdigest(), record['sha256'])
                self.assertEqual(raw[1:3], bytes((0, 10)))
                self.assertEqual(raw[16], 32)
                self.assertEqual(raw[17] & 15, 8)
                image = load_tga(path)
                self.assertEqual(image.tobytes(), Image.open(path).convert('RGBA').tobytes())
                self.assertEqual(hashlib.sha256(image.tobytes()).hexdigest(), record['rgbaSha256'])
                self.assertEqual(list(image.size), record['size'])
                alpha = image.getchannel('A')
                self.assertTrue(any(0 < a < 255 for a in alpha.tobytes()))
                self.assertGreater(alpha.getextrema()[1], 0)
                self.assertIsNone(alpha.crop((0, 0, image.width, 1)).getbbox())
                self.assertIsNone(alpha.crop((0, 0, 1, image.height)).getbbox())
                if record['shape'] not in ('plus', 'x'):
                    self.assertEqual(alpha.getpixel((image.width // 2, image.height // 2)), 0)
                if record['weight'] == 'bold':
                    thin = load_tga(path.with_name(path.name.replace('-bold-', '-thin-')))
                    self.assertGreater(sum(alpha.tobytes()), sum(thin.getchannel('A').tobytes()))


if __name__ == '__main__':
    unittest.main()
