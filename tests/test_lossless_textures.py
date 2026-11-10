"""Pixel fidelity, orientation safety, and installed-size budgets for UI art."""
from io import BytesIO
import json
from pathlib import Path
import sys
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from texture_utils import decode_tga, encode_tga_rle


class LosslessTextures(unittest.TestCase):
    def test_encoder_preserves_all_alpha_values_colors_and_scanline_edges(self):
        image = Image.new('RGBA', (256, 4))
        image.putdata([(x, 255-x, (x*17) % 256, x) for y in range(4) for x in range(256)])
        encoded = encode_tga_rle(image)
        self.assertEqual(encoded[2], 10)
        self.assertEqual(encoded[16:18], bytes((32, 8)))
        self.assertEqual(decode_tga(encoded).tobytes(), image.tobytes())
        self.assertEqual(Image.open(BytesIO(encoded)).tobytes(), image.tobytes())
        # Long opaque/transparent rows exercise 128-pixel RLE packet boundaries.
        solid = Image.new('RGBA', (512, 3), (23, 45, 67, 0))
        self.assertEqual(decode_tga(encode_tga_rle(solid)).tobytes(), solid.tobytes())

    def test_directional_masks_are_exact_pixel_permutations_of_originals(self):
        for folder in ('Bushido', 'Overwatch'):
            for path in (ROOT / 'JiberishIcons/Media' / folder).glob('*-mask.tga'):
                source = Image.open(path).convert('RGBA')
                directions = {'-vertical': source.transpose(Image.Transpose.ROTATE_90)}
                if not path.name.startswith('chamfer-'):
                    reverse = source.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                    directions['-reverse'] = reverse
                    directions['-reverse-vertical'] = reverse.transpose(Image.Transpose.ROTATE_90)
                for suffix, expected in directions.items():
                    target = path.with_name(path.stem + suffix + '.tga')
                    actual = decode_tga(target.read_bytes())
                    self.assertEqual(actual.size, expected.size, target)
                    self.assertEqual(actual.tobytes(), expected.tobytes(), target)

    def test_generated_assets_stay_compressed_without_reducing_resolution(self):
        total = uncompressed = count = 0
        for family in ('bushido', 'overwatch', 'portrait', 'crosshair', 'settings'):
            records = json.loads((ROOT / f'tests/fixtures/{family}-textures.json').read_text())['textures']
            for record in records:
                if record.get('kind') == 'artwork':
                    continue
                raw = (ROOT / 'JiberishIcons' / record['path']).read_bytes()
                self.assertEqual(raw[1:3], bytes((0, 10)), record['path'])
                self.assertEqual(raw[16], 32)
                total += len(raw); uncompressed += record['size'][0] * record['size'][1] * 4
                count += 1
        self.assertEqual(count, 801)
        self.assertLess(total, 22_000_000)
        self.assertLess(total / uncompressed, .12)
