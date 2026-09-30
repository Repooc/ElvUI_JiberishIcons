"""Copy legacy saved settings to the renamed addon; preview unless --apply is used."""
import argparse
import csv
import io
from pathlib import Path
import shutil
import subprocess
import sys


def game_running():
    if sys.platform == 'win32':
        output = subprocess.check_output(['tasklist', '/FO', 'CSV', '/NH'], text=True)
        names = [row[0].lower() for row in csv.reader(io.StringIO(output)) if row]
        return any(name.startswith('wow') and name.endswith('.exe') for name in names)
    output = subprocess.check_output(['ps', '-A', '-o', 'comm='], text=True)
    return any('world of warcraft' in name.lower() or Path(name.strip()).name.lower() in
               ('wow', 'wowclassic', 'wowclassicb') for name in output.splitlines())


def migrate(wtf, apply=False):
    wtf = Path(wtf).resolve()
    if (wtf / 'WTF').is_dir():
        wtf = wtf / 'WTF'
    if wtf.name != 'WTF' or not wtf.is_dir():
        raise ValueError('Choose the client WTF directory or its parent, such as _retail_.')
    plan = []
    for name in ['ElvUI_JiberishIcons.lua', 'ElvUI_JiberishIcons.lua.bak']:
        for source in sorted(wtf.rglob(name)):
            if source.parent.name != 'SavedVariables':
                continue
            if source.is_symlink():
                raise ValueError(f'Refusing a linked settings file: {source}')
            data = source.read_bytes()
            if b'JiberishIconsDB' not in data:
                raise ValueError(f'Expected JiberishIconsDB is missing: {source}')
            target = source.with_name(name.replace('ElvUI_', '', 1))
            if target.is_symlink():
                raise ValueError(f'Refusing a linked destination: {target}')
            if target.exists() and target.read_bytes() != data:
                raise ValueError(f'Existing settings differ; nothing was copied: {target}')
            plan.append((source, target, data))
    if apply and plan and game_running():
        raise ValueError('Fully quit World of Warcraft before copying saved settings.')
    copied = []
    try:
        for source, target, data in plan:
            if apply and not target.exists():
                # Exclusive creation prevents replacing files created after planning.
                with target.open('xb') as output:
                    copied.append(target)
                    output.write(data)
                shutil.copystat(source, target)
    except Exception:
        for path in copied:
            path.unlink()
        raise
    return [(str(source), str(target)) for source, target, _ in plan]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('wtf', type=Path)
    parser.add_argument('--apply', action='store_true', help='Copy after confirming WoW is closed; existing files are never replaced')
    args = parser.parse_args()
    try:
        plan = migrate(args.wtf, args.apply)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        parser.exit(1, str(error) + '\n')
    for source, target in plan:
        print(f'{source} -> {target}')
    print(f'{len(plan)} files ' + ('ready; originals retained.' if args.apply else 'planned. Add --apply to copy.'))


if __name__ == '__main__':
    main()
