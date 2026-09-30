"""Decode the shipped 32-bit TGA files, including legacy cross-row RLE runs."""
import struct
from PIL import Image


def load_tga(path):
    data = path.read_bytes()
    assert len(data) >= 18 and data[1] == 0 and data[2] in (2, 10) and data[16] == 32, path
    width, height = struct.unpack_from('<HH', data, 12)
    assert width > 0 and height > 0
    length = width * height * 4
    offset = 18 + data[0]
    if data[2] == 2:
        raw = data[offset:offset+length]
    else:
        raw = bytearray()
        while len(raw) < length:
            assert offset < len(data), path
            packet = data[offset]; offset += 1
            count = (packet & 127) + 1
            chunk_size = 4 if packet & 128 else count * 4
            chunk = data[offset:offset+chunk_size]; offset += chunk_size
            assert len(chunk) == chunk_size, path
            raw.extend(chunk * count if packet & 128 else chunk)
    assert len(raw) == length, path
    im = Image.frombytes('RGBA', (width, height), bytes(raw), 'raw', 'BGRA')
    if not data[17] & 32:
        im = im.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    if data[17] & 16:
        im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return im
