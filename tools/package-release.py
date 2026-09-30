"""Build and verify a clean JiberishIcons ZIP without publishing it."""
import hashlib
import json
import re
import stat
import zipfile
from addon_files import ROOT, ADDON, RELEASE_DOCS, required_files


def build(destination=None):
    destination = destination or ROOT / 'dist'
    toc = (ADDON / 'JiberishIcons.toc').read_text()
    version = re.search(r'^## Version: (\S+)$', toc, re.M)[1]
    assert re.fullmatch(r'[\w.-]+', version)
    entries = [(ADDON / name, 'JiberishIcons/' + name) for name in required_files()]
    entries += [(ROOT / name, 'JiberishIcons/' + name) for name in sorted(RELEASE_DOCS)]
    assert len({name for _, name in entries}) == len(entries)
    destination.mkdir(parents=True, exist_ok=True)
    archive = destination / f'JiberishIcons-{version}.zip'
    temporary = archive.with_suffix('.zip.tmp')
    with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as output:
        for source, name in entries:
            assert source.is_file() and not source.is_symlink()
            entry = zipfile.ZipInfo(name, (2026, 9, 30, 0, 0, 0))
            entry.create_system = 3
            entry.external_attr = (stat.S_IFREG | 0o644) << 16
            output.writestr(entry, source.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    with zipfile.ZipFile(temporary) as packaged:
        assert packaged.testzip() is None
        assert set(packaged.namelist()) == {name for _, name in entries}
        for source, name in entries:
            assert packaged.read(name) == source.read_bytes()
        assert all(name.startswith('JiberishIcons/') for name in packaged.namelist())
        assert 'JiberishIcons/JiberishIcons.toc' in packaged.namelist()
    temporary.replace(archive)
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix('.zip.sha256').write_text(checksum + '  ' + archive.name + '\n')
    report = {'version': version, 'folder': 'JiberishIcons', 'archive': archive.name,
              'sha256': checksum, 'fileCount': len(entries), 'bytes': archive.stat().st_size,
              'crcCheck': 'passed', 'sourceBytesMatch': True,
              'runtimeFiles': len(entries)-len(RELEASE_DOCS), 'inGameVisualCheck': 'pending',
              'files': [name for _, name in entries]}
    archive.with_suffix('.validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'{archive}: {len(entries)} verified files, {archive.stat().st_size:,} bytes')
    print(f'SHA-256 {checksum}')
    return archive


if __name__ == '__main__':
    build()
