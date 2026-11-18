"""The nav tape and aura timeline settings glyphs: approved bytes, alpha and a
reproducible standard-library build (no Pillow needed)."""
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('hud_art', ROOT / 'tools/build-hud-settings-art.py')
art = importlib.util.module_from_spec(spec)
spec.loader.exec_module(art)


class HudSettingsTextures(unittest.TestCase):
    def test_glyphs_match_the_builder_and_have_filtered_edges(self):
        records = json.loads((ROOT / 'tests/fixtures/hud-settings-textures.json').read_text())['textures']
        self.assertEqual([r['path'] for r in records], ['Media/Settings/navtape.tga', 'Media/Settings/timeline.tga'])
        others = json.loads((ROOT / 'tests/fixtures/settings-textures.json').read_text())['textures']
        existing = {r['sha256'] for r in others}
        for name, record in zip(art.NAMES, records):
            data = (ROOT / 'JiberishIcons' / record['path']).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(), record['sha256'])
            self.assertNotIn(record['sha256'], existing)
            width, height, rgba = art.decode_tga(data)
            self.assertEqual([width, height], record['size'])
            self.assertEqual(hashlib.sha256(rgba).hexdigest(), record['rgbaSha256'])
            alpha = rgba[3::4]
            self.assertEqual(alpha[0], 0)
            self.assertEqual((min(alpha), max(alpha)), (0, 255))
            self.assertTrue(any(0 < value < 255 for value in alpha))
            self.assertEqual(art.encode_tga(art.render(name)), data)


if __name__ == '__main__':
    unittest.main()
