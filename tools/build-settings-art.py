"""Draw original, small navigation glyphs for the native WoW settings tree.

These are code-defined UI symbols, not class/spec artwork. All coordinates use a
32px grid and are area-filtered from 8x resolution for fractional UI scales.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw

from texture_utils import save_tga_rle

ROOT = Path(__file__).resolve().parents[1]
NAMES = ('styles', 'frames', 'portrait', 'crosshair', 'elvui', 'ellesmere',
         'blizzard', 'suf', 'meters', 'chat', 'profiles', 'help')

def render(name):
    scale = 8
    mask = Image.new('L', (32*scale, 32*scale))
    d = ImageDraw.Draw(mask)
    def line(points, width=2.8):
        # Consistent rounded caps/joins, including closed outlines. At 16px
        # these retain a readable 1.4px stroke instead of disappearing.
        pts = [(round(x*scale),round(y*scale)) for x,y in points]
        stroke = round(width*scale)
        d.line(pts, fill=255, width=stroke, joint='curve')
        radius = stroke / 2
        for x,y in pts:
            d.ellipse((x-radius,y-radius,x+radius,y+radius),fill=255)
    def poly(points):
        d.polygon([(int(x*scale),int(y*scale)) for x,y in points], fill=255)
    def ellipse(box, fill=False, width=2.8):
        d.ellipse(tuple(round(v*scale) for v in box), fill=255 if fill else None, outline=None if fill else 255, width=round(width*scale))
    def rect(box, fill=False):
        d.rounded_rectangle(tuple(round(v*scale) for v in box), radius=1.6*scale,
                            fill=255 if fill else None, outline=None if fill else 255, width=round(2.8*scale))
    if name == 'styles':
        for box in ((4,4,13,13),(19,4,28,13),(4,19,13,28),(19,19,28,28)):
            rect(box)
    elif name == 'frames':
        rect((3,6,29,26)); line([(11,7),(11,25)])
        line([(16,13),(24,13)]); line([(16,20),(21,20)])
    elif name == 'portrait':
        line([(16,3),(27,9),(27,23),(16,29),(5,23),(5,9),(16,3)])
        ellipse((12,8,20,16)); line([(9,24),(10,20),(13,18),(19,18),(22,20),(23,24)])
    elif name == 'crosshair':
        ellipse((7,7,25,25)); ellipse((14,14,18,18),True)
        for points in ([(16,2),(16,10)],[(16,22),(16,30)],[(2,16),(10,16)],[(22,16),(30,16)]): line(points)
    elif name == 'elvui':
        rect((4,5,28,25)); line([(11,29),(21,29)]); line([(16,25),(16,29)])
        line([(9,11),(23,11)]); line([(9,19),(18,19)])
    elif name == 'ellesmere':
        line([(16,3),(29,10),(16,17),(3,10),(16,3)])
        line([(3,16),(16,23),(29,16)]); line([(3,22),(16,29),(29,22)])
    elif name == 'blizzard':
        line([(16,3),(27,7),(26,19),(22,25),(16,29),(10,25),(6,19),(5,7),(16,3)])
        poly([(16,9),(18,14),(23,16),(18,18),(16,23),(14,18),(9,16),(14,14)])
    elif name == 'suf':
        line([(4,20),(4,5),(23,5),(23,9)]); rect((9,11,28,27))
        line([(13,16),(24,16)]); line([(13,22),(21,22)])
    elif name == 'meters':
        line([(4,4),(4,28),(29,28)])
        line([(11,18),(11,23)]); line([(18,12),(18,23)]); line([(25,5),(25,23)])
    elif name == 'chat':
        line([(5,5),(27,5),(27,22),(16,22),(9,28),(9,22),(5,22),(5,5)])
        for x in (10,16,22): ellipse((x-1.4,12,x+1.4,14.8),True)
    elif name == 'profiles':
        line([(7,25),(4,25),(4,3),(21,3),(21,6)])
        line([(9,8),(23,8),(28,13),(28,29),(9,29),(9,8)])
        line([(22,9),(22,14),(27,14)]); line([(13,19),(24,19)]); line([(13,24),(22,24)])
    elif name == 'help':
        ellipse((3,3,29,29)); line([(11,11),(13,8),(18,8),(21,11),(20,14),(16,17),(16,18)])
        ellipse((14.6,22,17.4,24.8),True)
    # Neutral, untextured line art keeps color emphasis on the active label.
    base = Image.new('RGBA', mask.size, (242,245,250,0)); base.putalpha(mask)
    return base.resize((64,64),Image.Resampling.LANCZOS)

def build():
    folder=ROOT/'JiberishIcons/Media/Settings'; folder.mkdir(exist_ok=True)
    records=[]
    for name in NAMES:
        image=render(name); path=folder/(name+'.tga'); save_tga_rle(image, path)
        records.append({'path':path.relative_to(ROOT/'JiberishIcons').as_posix(),'size':[64,64],
                        'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                        'rgbaSha256':hashlib.sha256(image.tobytes()).hexdigest()})
    (ROOT/'tests/fixtures/settings-textures.json').write_text(json.dumps({'textures':records},indent=2)+'\n')
if __name__ == '__main__': build()
