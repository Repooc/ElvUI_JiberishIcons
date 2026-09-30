"""Regression checks for renamed packaging, migration, and legacy TGA decoding."""
import importlib.util
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from addon_files import required_files
from texture_utils import load_tga

spec = importlib.util.spec_from_file_location('migrate_settings', ROOT / 'tools/migrate-settings.py')
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)


class ReleaseChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.wtf = Path(self.temp.name) / 'WTF'
        self.saved = self.wtf / 'Account/TEST/SavedVariables'
        self.saved.mkdir(parents=True)
        self.source = self.saved / 'ElvUI_JiberishIcons.lua'
        self.source.write_bytes(b'JiberishIconsDB = { profiles = { Raid = {} } }\n')

    def test_preview_does_not_change_files(self):
        self.assertEqual(len(migration.migrate(self.wtf)), 1)
        self.assertFalse((self.saved / 'JiberishIcons.lua').exists())

    @patch.object(migration, 'game_running', return_value=False)
    def test_copy_preserves_bytes_originals_and_backup(self, running):
        backup = self.source.with_suffix('.lua.bak')
        backup.write_bytes(b'JiberishIconsDB = { old = true }\n')
        self.assertEqual(len(migration.migrate(self.wtf, True)), 2)
        self.assertEqual(self.source.read_bytes(), (self.saved / 'JiberishIcons.lua').read_bytes())
        self.assertEqual(backup.read_bytes(), (self.saved / 'JiberishIcons.lua.bak').read_bytes())
        self.assertEqual(len(migration.migrate(self.wtf, True)), 2)

    @patch.object(migration, 'game_running', return_value=False)
    def test_conflicting_settings_abort_before_any_copy(self, running):
        (self.saved / 'JiberishIcons.lua.bak').write_bytes(b'newer settings')
        self.source.with_suffix('.lua.bak').write_bytes(b'JiberishIconsDB = {}')
        with self.assertRaises(ValueError):
            migration.migrate(self.wtf, True)
        self.assertFalse((self.saved / 'JiberishIcons.lua').exists())
        self.assertEqual((self.saved / 'JiberishIcons.lua.bak').read_bytes(), b'newer settings')

    @patch.object(migration, 'game_running', return_value=True)
    def test_running_game_prevents_copy(self, running):
        with self.assertRaises(ValueError):
            migration.migrate(self.wtf, True)
        self.assertFalse((self.saved / 'JiberishIcons.lua').exists())

    def test_unrelated_directory_is_rejected(self):
        with self.assertRaises(ValueError):
            migration.migrate(self.saved)

    def test_package_load_graph_has_no_unused_libraries_or_artwork(self):
        files = required_files()
        self.assertIn('JiberishIcons.toc', files)
        self.assertIn('Media/Spec/fabledspecializations.tga', files)
        self.assertIn('Media/Spec/spec_fabledspecializations.tga', files)
        self.assertIn('Libs/Ace3/LICENSE.txt', files)
        self.assertFalse(any('LibOpenRaid/' in f or 'artwork/' in f or f.endswith('.png') for f in files))

    def test_details_native_crops_preserve_every_specializations_complete_artwork(self):
        textures = json.loads((ROOT / 'tests/fixtures/textures.json').read_text())['textures']
        record = next(t for t in textures if t['path'] == 'Media/Spec/fabledspecializations.tga')
        original = load_tga(ROOT / 'JiberishIcons' / record['path'])
        details = load_tga(ROOT / 'JiberishIcons/Media/Spec/spec_fabledspecializations.tga')
        layout = json.loads((ROOT / 'tests/fixtures/details-spec-layout.json').read_text())
        source_icons = {str(icon['specId']): icon for icon in record['icons']}
        self.assertEqual(set(source_icons), set(layout['coordinates']))
        for client in ('classic', 'retail'):
            coordinates = dict(layout['coordinates'])
            if client == 'retail':
                coordinates.update(layout['retailOverrides'])
            for spec_id, (left, right, top, bottom) in coordinates.items():
                with self.subTest(client=client, spec_id=spec_id):
                    x, y = source_icons[spec_id]['cell']
                    cell = record['cellSize']
                    source = original.crop((x*cell, y*cell, (x+1)*cell, (y+1)*cell))
                    scale = details.width // layout['referenceSize']
                    rendered = details.crop(tuple(v*scale for v in (left, top, right, bottom)))
                    source_bounds = source.getchannel('A').getbbox()
                    rendered_bounds = rendered.getchannel('A').getbbox()
                    self.assertIsNotNone(rendered_bounds)
                    self.assertEqual(source.crop(source_bounds).size, rendered.crop(rendered_bounds).size)
                    self.assertEqual(source.crop(source_bounds).tobytes(), rendered.crop(rendered_bounds).tobytes())
                    self.assertGreaterEqual(min(rendered_bounds[:2]), 4)
                    self.assertGreaterEqual(rendered.width - rendered_bounds[2], 4)
                    self.assertGreaterEqual(rendered.height - rendered_bounds[3], 4)

    def test_legacy_rle_can_cross_rows_and_preserves_orientation(self):
        header = bytearray(18)
        header[2] = 10
        struct.pack_into('<HH', header, 12, 2, 2)
        header[16], header[17] = 32, 40
        # Three red pixels in one RLE run cross the two-pixel row boundary.
        path = Path(self.temp.name) / 'cross-row.tga'
        path.write_bytes(header + bytes([0x82, 0, 0, 255, 255, 0, 255, 0, 0, 255]))
        image = load_tga(path)
        self.assertEqual(image.tobytes(), bytes([255, 0, 0, 255])*3 + bytes([0, 0, 255, 255]))


if __name__ == '__main__':
    unittest.main()
