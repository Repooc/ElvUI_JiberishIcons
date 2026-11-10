"""Original navigation glyphs stay readable, transparent and packaged."""
import hashlib
import json
from pathlib import Path
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

class SettingsTextures(unittest.TestCase):
    def test_navigation_symbols_are_distinct_and_have_filtered_edges(self):
        records = json.loads((ROOT / 'tests/fixtures/settings-textures.json').read_text())['textures']
        self.assertEqual(len(records), 12)
        hashes = set()
        for record in records:
            path = ROOT / 'JiberishIcons' / record['path']
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            self.assertEqual(digest, record['sha256'])
            self.assertNotIn(digest, hashes)
            hashes.add(digest)
            with Image.open(path) as image:
                self.assertEqual(image.mode, 'RGBA')
                self.assertEqual(list(image.size), [64, 64])
                self.assertEqual(hashlib.sha256(image.tobytes()).hexdigest(), record['rgbaSha256'])
                alpha = image.getchannel('A')
                self.assertEqual(alpha.getpixel((0, 0)), 0)
                self.assertEqual(alpha.getextrema(), (0, 255))
                self.assertTrue(any(alpha.histogram()[1:255]))
                small = image.resize((18,18),Image.Resampling.LANCZOS)
                self.assertGreater(sum(1 for value in small.getchannel('A').histogram()[128:] if value), 5)
