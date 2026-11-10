"""Lossless 32-bit TGA encoding and independent raw/RLE pixel decoding."""
from io import BytesIO
import struct
from PIL import Image


def load_tga(path):
    return decode_tga(path.read_bytes())


def decode_tga(data):
    assert len(data) >= 18 and data[1] == 0 and data[2] in (2, 10) and data[16] == 32
    width, height = struct.unpack_from('<HH', data, 12)
    assert width > 0 and height > 0
    length = width * height * 4
    offset = 18 + data[0]
    if data[2] == 2:
        raw = data[offset:offset+length]
    else:
        raw = bytearray()
        while len(raw) < length:
            assert offset < len(data)
            packet = data[offset]; offset += 1
            count = (packet & 127) + 1
            chunk_size = 4 if packet & 128 else count * 4
            chunk = data[offset:offset+chunk_size]; offset += chunk_size
            assert len(chunk) == chunk_size
            raw.extend(chunk * count if packet & 128 else chunk)
    assert len(raw) == length
    im = Image.frombytes('RGBA', (width, height), bytes(raw), 'raw', 'BGRA')
    if not data[17] & 32:
        im = im.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    if data[17] & 16:
        im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return im


def encode_tga_rle(image):
    """Keep all RGBA bytes/dimensions; only compress identical adjacent pixels.

    No resampling, color quantization, alpha reduction or runtime Lua decoder.
    Pillow emits standard scanline-bounded packets, verified independently here.
    """
    assert image.mode == 'RGBA'
    output = BytesIO()
    image.save(output, format='TGA', compression='tga_rle')
    data = output.getvalue()
    assert data[1:3] == bytes((0, 10)) and data[16] == 32 and data[17] & 15 == 8
    offset, pixels = 18 + data[0], 0
    while pixels < image.width * image.height:
        packet = data[offset]
        count = (packet & 127) + 1
        assert pixels % image.width + count <= image.width, 'RLE packet crosses a scanline'
        offset += 1 + (4 if packet & 128 else count * 4)
        pixels += count
    assert pixels == image.width * image.height
    decoded = decode_tga(data)
    assert decoded.size == image.size and decoded.tobytes() == image.tobytes(), 'Lossless encoding failed'
    return data


def save_tga_rle(image, path):
    path.write_bytes(encode_tga_rle(image))


def oriented_masks(image, mirror=True):
    """Bake exact pixel permutations; MaskTexture UV transforms are unreliable.

    NORMAL vertical maps source TR/TL/BR/BL onto destination TL/BL/TR/BR,
    matching the existing border's eight-coordinate transform.
    """
    yield '-vertical', image.transpose(Image.Transpose.ROTATE_90)
    if mirror:
        flipped = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        yield '-reverse', flipped
        yield '-reverse-vertical', flipped.transpose(Image.Transpose.ROTATE_90)
