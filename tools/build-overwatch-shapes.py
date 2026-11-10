"""Build native unit-frame cells and layered portrait frames."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from texture_utils import save_tga_rle, oriented_masks

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'JiberishIcons/Media/Overwatch'

def build():
    OUT.mkdir(exist_ok=True)
    records = []
    def save(name, alpha, kind, shade=None):
        rgba = np.full((*alpha.shape, 4), 255, dtype=np.uint8)
        if shade is not None:
            rgba[:, :, :3] = np.rint(np.clip(shade,0,1)[:, :, None]*255).astype('uint8')
        rgba[:, :, 3] = np.rint(np.clip(alpha, 0, 1) * 255).astype('uint8')
        im = Image.fromarray(rgba); path = OUT / (name + '.tga'); save_tga_rle(im, path)
        records.append(dict(path=path.relative_to(ROOT/'JiberishIcons').as_posix(), kind=kind,
                            size=list(im.size), sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                            rgbaSha256=hashlib.sha256(im.tobytes()).hexdigest()))
        if kind == 'mask':
            for suffix, oriented in oriented_masks(im):
                path = OUT / (name + suffix + '.tga')
                save_tga_rle(oriented, path)
                records.append(dict(path=path.relative_to(ROOT/'JiberishIcons').as_posix(), kind='orientedMask',
                                    size=list(oriented.size), sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                                    rgbaSha256=hashlib.sha256(oriented.tobytes()).hexdigest()))
    def rounded(x, y, hx, hy, radius):
        qx, qy = np.abs(x)-hx+radius, np.abs(y)-hy+radius
        return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0)-radius
    # Signed-distance coverage in design pixels, not normalized texture axes.
    # The two axes have different texture densities; a single normalized AA
    # width produced stair steps when the old 64px textures were minified.
    y, x = np.mgrid[:128, :512]; u, v = (x+.5)/512, (y+.5)/128
    for count in (5, 10, 20):
        cell = 512/count
        for style in ('angled', 'rounded'):
            for gap, padding in (('narrow', .005), ('normal', .012), ('gap3', .025), ('gap4', .04), ('wide', .065), ('gap6', .10)):
                shear = min(8, cell*.24) if style == 'angled' else 0
                # Fit the entire sheared row inside the native rectangle. The
                # old grid reached past both ends and clipped the end borders.
                # Adjacent boundaries still share the same small parallel slit.
                edge = 2
                span = 512-2*edge-shear
                position = (u*512-edge-shear*(1-v))*512/span
                local = (np.mod(position/cell, 1)-.5)*cell
                half_gap = .7+cell*padding
                d = rounded(local, (v-.5)*40, cell*.5-half_gap, 18, min(1.3, cell*.04))
                alpha = np.clip(.5-d/.9, 0, 1)
                # Exclude repetitions outside the fitted first/last full cell.
                domain = np.clip(position/.9,0,1)*np.clip((512-position)/.9,0,1)
                alpha *= domain
                suffix = '' if gap == 'normal' else '-'+gap
                if style == 'rounded': suffix += '-rounded'
                save(f'segments-{count}{suffix}-mask', alpha, 'mask')
                for width in range(1, 7):
                    # Half-pixel steps at 40px frame height. Native size scales
                    # the outline together with the health/power silhouette.
                    inner = np.clip(.5-(d+width*.5)/.9, 0, 1)*domain
                    ending = '' if width == 2 else '-'+str(width)
                    save(f'segments-{count}{suffix}-border{ending}', np.maximum(0, alpha-inner), 'border')
    # Reference proportions in a 100x110 design space: rounded shoulders,
    # a substantial bright rim, and a second lower V separated by a dark seam.
    # Render at 8x then downsample for stable edges at actual portrait sizes.
    def polygon(points):
        canvas = Image.new('L', (800,880))
        draw = ImageDraw.Draw(canvas)
        curve = []
        for i, point in enumerate(points):
            previous, following = np.array(points[i-1]), np.array(points[(i+1)%len(points)])
            point = np.array(point, dtype=float)
            start = point+(previous-point)*min(.25, 5/np.linalg.norm(previous-point))
            end = point+(following-point)*min(.25, 5/np.linalg.norm(following-point))
            for t in np.linspace(0,1,16):
                pos = (1-t)**2*start+2*(1-t)*t*point+t*t*end
                curve.append(tuple(pos*8))
        draw.polygon(curve, fill=255)
        return np.asarray(canvas.resize((256,256),Image.Resampling.LANCZOS),dtype=float)/255
    points = np.array([(50,7),(94,31),(94,79),(50,104),(6,79),(6,31)], dtype=float)
    center = np.array([50,56])
    yy = (np.arange(256)+.5)/256*110
    xx = (np.arange(256)+.5)/256*100
    main = polygon(points)
    # The second V is an inset accent, wholly inside the one outer shield.
    # The foreground covers the bust along that V, not with a horizontal shelf.
    cover = main*(yy[:,None] > (77+(1-np.abs(xx-50)/50)*17))
    save('portrait-base',main,'portrait')
    save('portrait-front-base',cover,'portrait')
    def finish(alpha):
        blur = Image.fromarray(np.rint(alpha*255).astype('uint8')).filter(ImageFilter.GaussianBlur(1.6))
        body = np.asarray(blur,dtype=float)/255
        light = .97-.04*(yy[:,None]/110)
        return np.clip((.87+.13*body)*light,0,1)
    for weight, scale in ((1,.94),(2,.915),(3,.89),(4,.865),(5,.84)):
        inset = polygon(center+(points-center)*scale)
        stroke = np.maximum(0,main-inset)
        accent_outer = polygon(center+(points-center)*(scale-.045))
        accent_inner = polygon(center+(points-center)*(scale-.105))
        accent = np.maximum(0,accent_outer-accent_inner)*(yy[:,None] > 73)
        full_rim = np.maximum(stroke,accent)
        front_rim = np.maximum(stroke*(yy[:,None] > 64),accent)
        suffix = '' if weight == 3 else '-'+str(weight)
        save('portrait-rim'+suffix,full_rim,'portrait',finish(full_rim))
        save('portrait-front-rim'+suffix,front_rim,'portrait',finish(full_rim))

    # Standard frames use the same split rear/foreground layering as the shield.
    y, x = np.mgrid[:256, :256]; u, v = (x+.5)/256*100-50, (y+.5)/256*100-50
    for shape in ('circle', 'square', 'diamond'):
        if shape == 'circle': distance = np.hypot(u,v)-46
        elif shape == 'square': distance = rounded(u,v,46,46,4)
        else: distance = (np.abs(u)+np.abs(v)-46)/np.sqrt(2)
        outer = np.clip(.5-distance*2.56,0,1)
        save(f'portrait-{shape}-base',outer,'portrait')
        # Back the lower rim with a subtle inset seam; leave the upper half
        # behind the model, so hair is never hidden by the rear border.
        front = np.maximum(0,outer-np.clip(.5-(distance+8)*2.56,0,1))*(v > 12)
        save(f'portrait-{shape}-front-base',front,'portrait')
        for weight in range(1,6):
            rim = np.maximum(0,outer-np.clip(.5-(distance+weight)*2.56,0,1))
            suffix = '' if weight == 3 else '-'+str(weight)
            save(f'portrait-{shape}-rim'+suffix,rim,'portrait',finish(rim))
            save(f'portrait-{shape}-front-rim'+suffix,rim*(v > 12),'portrait',finish(rim))

    # Remove only obsolete assets previously generated by this builder.
    manifest = ROOT/'tests/fixtures/overwatch-textures.json'
    if manifest.exists():
        current = {item['path'] for item in records}
        for item in json.loads(manifest.read_text())['textures']:
            if item['path'] not in current:
                (ROOT/'JiberishIcons'/item['path']).unlink(missing_ok=True)

    (ROOT/'tests/fixtures/overwatch-textures.json').write_text(json.dumps({'textures':records},indent=2)+'\n')
    print(f'Built {len(records)} Overwatch textures')
if __name__ == '__main__': build()
