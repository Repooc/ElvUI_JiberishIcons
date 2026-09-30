"""Run the complete release checks without installing or publishing anything."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from addon_files import ROOT, ADDON, required_files, source_files


def run(*command):
    subprocess.run(command, cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lua', default='lua5.1')
    parser.add_argument('--luac', default='luac5.1')
    args = parser.parse_args()
    files = source_files()
    print(f'PASS {len(files)} essential repository files; no source artwork or build output', flush=True)
    version = re.search(r'^## Version: (\S+)$', (ADDON / 'JiberishIcons.toc').read_text(), re.M)[1]
    if os.environ.get('GITHUB_REF_TYPE') == 'tag':
        tag = os.environ.get('GITHUB_REF_NAME', '')
        assert tag.removeprefix('v') == version, f'Tag {tag} does not match TOC version {version}'
    with tempfile.TemporaryDirectory(prefix='jiberish-lua-check-') as directory:
        scratch = Path(directory) / 'syntax.lua'
        count = 0
        for name in required_files():
            if name.endswith('.lua'):
                scratch.write_text((ADDON / name).read_text(encoding='utf-8-sig'))
                run(args.luac, '-p', str(scratch))
                count += 1
        print(f'PASS {count} shipped Lua syntax checks', flush=True)
    run(args.lua, 'tests/ellesmereui.lua')
    run(args.lua, 'tests/acegui-checkbox.lua')
    run(sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_*.py')
    run(sys.executable, 'tools/verify-artwork.py')
    run(sys.executable, 'tools/package-release.py')
    run('git', 'diff', '--check')


if __name__ == '__main__':
    main()
