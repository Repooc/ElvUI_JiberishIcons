"""Resolve the exact addon load graph and required release assets."""
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / 'JiberishIcons'
LICENSES = {'Libs/Ace3/LICENSE.txt', 'Libs/UTF8/LICENSE.txt'}
RELEASE_DOCS = {'LICENSE.md', 'changelog.md', 'UPGRADING.md'}
PREVIEWS = {'FabledSpecializationsSocial.png', 'FabledRegaliaWebsiteDisplay.png',
            'FabledAzerothWebsiteDisplay.png'}


def source_files():
    """Validate the pending Git tree as well as a clean checkout, without staging it."""
    allowed = {'JiberishIcons/' + name for name in required_files()}
    allowed |= RELEASE_DOCS | {'README.md', 'DEVELOPMENT.md', '.gitignore', '.gitattributes', '.pkgmeta'}
    allowed |= {'images/' + name for name in PREVIEWS}
    allowed |= {'.github/workflows/validate.yml', '.github/workflows/release.yml'}
    for pattern in ('tools/*.py', 'tests/*.lua', 'tests/test_*.py', 'tests/fixtures/*.json'):
        allowed |= {p.relative_to(ROOT).as_posix() for p in ROOT.glob(pattern)}

    def git_files(*args):
        output = subprocess.check_output(['git', '-C', str(ROOT), 'ls-files', '-z', *args])
        return {name for name in output.decode().split('\0') if name}

    # diff recognizes a directory replaced by the ignored legacy-install symlink;
    # ls-files --deleted alone can still follow that link to archived files.
    deleted = subprocess.check_output(['git', '-C', str(ROOT), 'diff', '--name-only', '--diff-filter=D', '-z'])
    candidates = git_files('--cached', '--others', '--exclude-standard') - git_files('--deleted')
    candidates -= {name for name in deleted.decode().split('\0') if name}
    assert candidates == allowed, f'Nonessential source files: {sorted(candidates-allowed)}; missing: {sorted(allowed-candidates)}'
    for name in allowed:
        path = ROOT / name
        assert path.is_file() and not path.is_symlink(), name
        assert not any(p.is_symlink() for p in path.parents if p != ROOT and p.is_relative_to(ROOT)), name
    return sorted(allowed)


def required_files(addon=ADDON):
    addon = addon.resolve()
    loaded = set()

    def visit(path):
        path = path.resolve()
        assert path.is_relative_to(addon) and path.is_file(), f'Missing or external dependency: {path}'
        relative = path.relative_to(addon).as_posix()
        if relative in loaded:
            return
        loaded.add(relative)
        if path.suffix == '.toc':
            for line in path.read_text().splitlines():
                line = line.strip()
                if line and not line.startswith('#'):
                    visit(path.parent / line.replace('\\', '/'))
        elif path.suffix == '.xml':
            for element in ET.parse(path).iter():
                if element.tag.rsplit('}', 1)[-1] in ('Script', 'Include') and element.get('file'):
                    visit(path.parent / element.get('file').replace('\\', '/'))

    visit(addon / 'JiberishIcons.toc')
    textures = json.loads((ROOT / 'tests/fixtures/textures.json').read_text())['textures']
    required = loaded | LICENSES | {t['path'] for t in textures}
    for name in required:
        assert (addon / name).is_file() and not (addon / name).is_symlink(), name
    actual = {p.relative_to(addon).as_posix() for p in addon.rglob('*') if p.is_file()}
    assert actual == required, f'Unexpected addon files: {sorted(actual-required)}; missing: {sorted(required-actual)}'
    return sorted(required)
