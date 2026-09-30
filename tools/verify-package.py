"""Verify local or BigWigs packages contain exactly the required source files."""
import argparse
from pathlib import Path
import zipfile
from addon_files import ROOT, ADDON, RELEASE_DOCS, required_files


def verify(archive):
    sources = {'JiberishIcons/' + name: ADDON / name for name in required_files()}
    sources.update({'JiberishIcons/' + name: ROOT / name for name in RELEASE_DOCS})
    with zipfile.ZipFile(archive) as package:
        assert package.testzip() is None, 'Corrupt ZIP entry'
        files = [entry.filename for entry in package.infolist() if not entry.is_dir()]
        assert len(files) == len(set(files)), 'Duplicate ZIP entries'
        assert set(files) == set(sources), f'Extra files: {sorted(set(files)-sources.keys())}; missing: {sorted(sources.keys()-set(files))}'
        for name, source in sources.items():
            assert package.read(name) == source.read_bytes(), f'Packaged content differs: {name}'
    print(f'PASS {archive}: {len(sources)} required files, one JiberishIcons folder, exact source bytes')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    verify(parser.parse_args().archive)
