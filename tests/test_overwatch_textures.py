"""Check actual gaps, rounded corners, and release decoding for native frame and portrait assets."""
import hashlib
import json
from pathlib import Path
import unittest
import sys
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from texture_utils import load_tga

class OverwatchTextures(unittest.TestCase):
    def test_manifest_and_formats(self):
        records = json.loads((ROOT/'tests/fixtures/overwatch-textures.json').read_text())['textures']
        self.assertEqual(len(records), 408)
        for item in records:
            path = ROOT/'JiberishIcons'/item['path']
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), item['sha256'])
            im = Image.open(path).convert('RGBA')
            self.assertEqual(load_tga(path).tobytes(), im.tobytes())
            self.assertEqual(list(im.size), item['size'])
            self.assertEqual(hashlib.sha256(im.tobytes()).hexdigest(), item['rgbaSha256'])
            self.assertEqual(path.read_bytes()[1:3], b'\x00\x0a')
            lo, hi = im.getchannel('A').getextrema()
            self.assertEqual(lo, 0)
            self.assertGreater(hi, 0)
            if item['kind'] != 'border': self.assertEqual(hi, 255)

    def test_health_cells_have_transparent_gaps_and_rounding(self):
        for count in (5, 10, 20):
            im = Image.open(ROOT/f'JiberishIcons/Media/Overwatch/segments-{count}-mask.tga')
            row = [im.getpixel((x, 32))[3] > 127 for x in range(im.width)]
            runs = sum(value and (x == 0 or not row[x-1]) for x, value in enumerate(row))
            self.assertEqual(runs, count)
            self.assertTrue(all(im.getpixel((x, 0))[3] == 0 for x in range(im.width)))
            self.assertTrue(any(0 < a < 255 for a in im.getchannel('A').tobytes()))
            border = Image.open(ROOT/f'JiberishIcons/Media/Overwatch/segments-{count}-border.tga')
            self.assertTrue(all(b <= a for a,b in zip(im.getchannel('A').tobytes(), border.getchannel('A').tobytes())))

    def test_compact_cells_keep_count_and_parallel_gaps_in_both_directions(self):
        for count in (5,10,20):
            for gap in ('', '-narrow', '-gap3', '-gap4', '-wide', '-gap6', '-rounded', '-narrow-rounded'):
                image = Image.open(ROOT/f'JiberishIcons/Media/Overwatch/segments-{count}{gap}-mask.tga')
                for reverse in (False,True):
                    im = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if reverse else image
                    for y in (24,64,100):
                        row = [im.getpixel((x,y))[3] > 127 for x in range(im.width)]
                        self.assertEqual(sum(v and (i == 0 or not row[i-1]) for i,v in enumerate(row)),count)
                    # Tight cells cover most of the native bar, including at 20 cells.
                    if gap == '-narrow':
                        row = [im.getpixel((x,64))[3] > 127 for x in range(im.width)]
                        self.assertGreater(sum(row)/im.width,.90)
                        # Middle-line thresholds still sit in a gap.
                        for k in range(1,count):
                            shear = min(8,512/count*.24) if 'rounded' not in gap else 0
                            boundary = 2+shear*(1-64.5/128)+(512-4-shear)*k/count
                            if reverse: boundary = 512-boundary
                            self.assertLess(min(im.getpixel((x,64))[3] for x in (int(boundary),int(boundary)+1)),128)

    def test_spacing_and_outline_width_are_monotonic_and_inside_the_mask(self):
        for count in (5, 10, 20):
            for style in ('', '-rounded'):
                previous = None
                for gap in ('-narrow', '', '-gap3', '-gap4', '-wide', '-gap6'):
                    stem = ROOT/f'JiberishIcons/Media/Overwatch/segments-{count}{gap}{style}'
                    mask = Image.open(str(stem)+'-mask.tga').getchannel('A')
                    values = list(mask.tobytes()); coverage = sum(values)
                    if previous is not None: self.assertLess(coverage, previous)
                    previous = coverage
                    previous_border = 0
                    for weight in range(1,7):
                        suffix = '' if weight == 2 else '-'+str(weight)
                        border = Image.open(str(stem)+'-border'+suffix+'.tga').getchannel('A')
                        data = list(border.tobytes())
                        self.assertTrue(all(b <= a for a,b in zip(values,data)))
                        self.assertGreater(sum(data),previous_border)
                        previous_border = sum(data)

    def test_reference_rim_has_two_separated_lower_strokes_and_rounded_corners(self):
        rim = Image.open(ROOT/'JiberishIcons/Media/Overwatch/portrait-rim.tga').getchannel('A')
        column = [rim.getpixel((128,y)) > 127 for y in range(175,256)]
        self.assertEqual(sum(v and (i == 0 or not column[i-1]) for i,v in enumerate(column)),2)
        self.assertTrue(any(0 < a < 255 for a in rim.tobytes()))
        self.assertEqual(rim.getpixel((0,0)),0)

    def test_portrait_lower_seam_is_backed_and_rim_has_shading(self):
        folder = ROOT/'JiberishIcons/Media/Overwatch'
        rim = Image.open(folder/'portrait-rim.tga').convert('RGBA')
        base = Image.open(folder/'portrait-base.tga').getchannel('A')
        column = [rim.getpixel((128,y))[3] for y in range(175,256)]
        strokes = [y+175 for y,v in enumerate(column) if v > 127]
        seam = [y for y in range(min(strokes),max(strokes)) if rim.getpixel((128,y))[3] < 20]
        self.assertTrue(seam)
        self.assertTrue(all(base.getpixel((128,y)) == 255 for y in seam))
        tones = {r for r,g,b,a in zip(*[iter(rim.tobytes())]*4) if a == 255}
        self.assertGreater(len(tones),3)

    def test_end_cells_and_borders_have_clearance_and_portrait_accent_is_inset(self):
        folder = ROOT/'JiberishIcons/Media/Overwatch'
        for count in (5,10,20):
            for style in ('','-rounded'):
                for kind in ('mask','border','border-6'):
                    im = Image.open(folder/f'segments-{count}-narrow{style}-{kind}.tga').getchannel('A')
                    self.assertTrue(all(im.getpixel((x,y)) == 0 for x in (0,im.width-1) for y in range(im.height)))
        base = Image.open(folder/'portrait-base.tga').getchannel('A').tobytes()
        for name in ('portrait-front-base','portrait-front-rim','portrait-front-rim-5'):
            accent = Image.open(folder/(name+'.tga')).getchannel('A').tobytes()
            self.assertTrue(all(a <= b for a,b in zip(accent,base)))

if __name__ == '__main__': unittest.main()
