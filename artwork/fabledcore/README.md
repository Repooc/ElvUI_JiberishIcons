# Fabled Core resolution export

Only Fabled Core is changed by this export. The other eight older class sheets,
Fabled Regalia, Fabled Azeroth, and both logos remain byte-identical to rc.3.
Their reference hashes are in `unchanged-textures.json`.

`originals/fabledcore.tga` is the untouched 1024 × 1024 original, with thirteen
128 × 128 class cells. Its lossless PNG decode is stored beside it. No larger
working master was found in the repository, Git history, or local artwork backups.

Run `python3 tools/build-fabledcore.py` from the repository root with Pillow
installed. It resamples each cell separately using alpha-aware Lanczos, followed
by restrained RGB sharpening (radius 0.8, amount 45%, threshold 3). Transparency
is not sharpened. There is no generation, redesign, cropping, or recentering.
This improves interpolation and edge contrast; it cannot recover missing detail
from the original 128px source.

The output uses 256px cells on a power-of-two 2048 × 2048 sheet. Existing padding,
on-screen sizing, and normalized coordinates are preserved. The 32-bit TGA uses
lossless RLE and full 8-bit alpha, as the original did. RLE reduces file size;
the decoded RGBA sheet still occupies 16 MiB, compared with 4 MiB previously.
No global texture filtering or graphics settings are changed.

`comparison.png` shows every icon at 256px, pairing bilinear enlargement of the
old cell with the new export. It is a simulated export comparison, not an
in-game capture. `icons/` and `fabledcore.png` provide lossless review files.

`python3 tools/verify-fabledcore.py` independently decodes the RLE payload,
checks all thirteen cells against the PNGs and Lua mapping, verifies alpha,
checks placement and unused cells, and verifies the other textures' hashes.
In-game acceptance remains pending after a full client restart.
