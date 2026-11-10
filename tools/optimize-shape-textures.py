"""Losslessly repack generated UI textures, preserving approved pixel hashes.

Only the five generated-asset manifests are eligible. Icon atlases and the
supplied Bushido end-cap artwork are deliberately excluded. Safe to rerun.
"""
import hashlib
from io import BytesIO
import json
from pathlib import Path
from PIL import Image
from texture_utils import encode_tga_rle, load_tga

ROOT = Path(__file__).resolve().parents[1]
MANIFESTS = ('bushido', 'overwatch', 'portrait', 'crosshair', 'settings')


def main():
    planned, manifests = [], []
    for name in MANIFESTS:
        path = ROOT / f'tests/fixtures/{name}-textures.json'
        document = json.loads(path.read_text())
        for record in document['textures']:
            if record.get('kind') == 'artwork':
                continue
            asset = ROOT / 'JiberishIcons' / record['path']
            before = asset.read_bytes()
            assert hashlib.sha256(before).hexdigest() == record['sha256'], asset
            image = load_tga(asset)
            pixel_hash = hashlib.sha256(image.tobytes()).hexdigest()
            assert list(image.size) == record['size'], asset
            if 'rgbaSha256' in record:
                assert pixel_hash == record['rgbaSha256'], asset
            encoded = encode_tga_rle(image)
            assert Image.open(BytesIO(encoded)).convert('RGBA').tobytes() == image.tobytes(), asset
            assert len(encoded) <= len(before), f'Compression would enlarge {asset}'
            planned.append((asset, encoded, len(before)))
            # Existing approved pixel hashes are unchanged, never re-baselined.
            record['rgbaSha256'] = pixel_hash
            record['sha256'] = hashlib.sha256(encoded).hexdigest()
        if name == 'portrait':
            document['description'] = 'Analytic circle/droplet borders and masks. Lossless RLE 32-bit TGA with 8-bit alpha in six independently area-sampled sizes.'
        manifests.append((path, document))
    # Validate every conversion before replacing any source asset or manifest.
    for asset, encoded, _ in planned:
        asset.write_bytes(encoded)
    for path, document in manifests:
        path.write_text(json.dumps(document, indent=2) + '\n')
    before = sum(size for _, _, size in planned)
    after = sum(len(data) for _, data, _ in planned)
    print(f'{len(planned)} pixel-identical textures: {before:,} -> {after:,} bytes ({1-after/before:.1%} smaller)')


if __name__ == '__main__':
    main()
