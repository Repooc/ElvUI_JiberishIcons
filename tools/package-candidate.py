"""Build a local installable candidate; never publish or change Git state."""
import hashlib
import re
import stat
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
addon = root / 'ElvUI_JiberishIcons'
toc = (addon / 'ElvUI_JiberishIcons.toc').read_text()
version = re.search(r'^## Version: (\S+)$', toc, re.M)[1]
assert re.fullmatch(r'[\w.-]+', version)
for relative in ['Media/Class/fabledregalia.tga', 'Media/Race/fabledazeroth.tga']:
    assert (addon / relative).is_file(), f'Missing {relative}'
destination = root / 'dist'
destination.mkdir(exist_ok=True)
archive = destination / f'ElvUI_JiberishIcons-{version}.zip'
entries = [(p, 'ElvUI_JiberishIcons/' + p.relative_to(addon).as_posix())
           for p in sorted(addon.rglob('*')) if p.is_file() and not p.name.startswith('.')]
entries += [(root / name, 'ElvUI_JiberishIcons/' + name) for name in ['LICENSE.md', 'changelog.md']]
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as output:
    for source, name in entries:
        assert not source.is_symlink()
        entry = zipfile.ZipInfo(name, (2026, 9, 29, 0, 0, 0))
        entry.create_system = 3
        entry.external_attr = (stat.S_IFREG | 0o644) << 16
        output.writestr(entry, source.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
with zipfile.ZipFile(archive) as packaged:
    assert packaged.testzip() is None
    assert len(packaged.namelist()) == len(entries) == len(set(packaged.namelist()))
    for source, name in entries:
        assert packaged.read(name) == source.read_bytes()
    assert all(name.startswith('ElvUI_JiberishIcons/') for name in packaged.namelist())
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
(destination / (archive.name + '.sha256')).write_text(checksum + '  ' + archive.name + '\n')
print(f'{archive}: {len(entries)} verified files, {archive.stat().st_size:,} bytes')
print('SHA-256 ' + checksum)
