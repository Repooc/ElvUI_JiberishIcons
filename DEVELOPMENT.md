# Development and releases

## Repository contents

- `JiberishIcons/`: loaded Lua/XML files, required library licenses and the final game textures.
- `tests/`: integration tests and small artwork checksum/coordinate fixtures.
- `tools/`: release validation/packaging, optional settings migration and final-image export.
- `images/`: the three finished previews referenced by the README; excluded from addon ZIPs.
- `dist/`: local downloads and reports; ignored by Git and the CurseForge packager.

Keep artwork drafts, intermediate PNGs, extracted ZIPs and old builds outside the
repository. Final TGA sheets are the canonical game assets. Update
`tests/fixtures/textures.json` deliberately when artwork changes; never replace
approved hashes merely to bypass a failure. The source check rejects files outside
the addon, documentation, tooling, tests, workflows and approved previews.

The local `ElvUI_JiberishIcons` compatibility link is ignored. It supports this
machine's existing installation and must not be committed or packaged. Preparing a
release does not install the addon or copy saved settings.

## Checks and local download

Use Python 3.10+ with Pillow, plus Lua 5.1 and its compiler:

```sh
python3 tools/check-release.py
```

For custom runtime locations, pass `--lua /path/to/lua --luac /path/to/luac`.
This verifies the source tree, every shipped Lua file, frame/meter integration
fixtures, settings migration, artwork coordinates/transparency and the release ZIP.
The tests do not simulate WoW's secure execution or GPU rendering.

To rebuild only the download:

```sh
python3 tools/package-release.py
```

Outputs are `dist/JiberishIcons-<version>.zip`, a SHA-256 checksum and a validation
report. The archive contains one `JiberishIcons` folder with the required runtime
files, library licenses, project license, changelog and upgrade guide. No artwork
working files, previews, tests or tools are installed with the addon.

## GitHub and CurseForge

The installed folder is `JiberishIcons`; the visible title is **Jiberish Fabled Icons**.
The existing GitHub repository name and CurseForge/Wago project IDs are retained
so existing project subscriptions continue to receive updates.

Branch pushes and pull requests run validation only. Publishing runs on a version
tag, after validation succeeds. The tag (optionally prefixed with `v`) must match
`## Version` in the TOC. For this release, use `1.4.8` or `v1.4.8` after reviewing
and committing the prepared files and completing the in-game checks below.

The release workflow uses [BigWigs packager v2](https://github.com/BigWigsMods/packager)
with `.pkgmeta` and Unix line endings. It builds without uploading first, verifies
the exact archive contents, then publishes. It retains the single comma-separated
Interface line. Required publishing configuration:

- `CF_API_KEY`: CurseForge token authorized for project **978121**.
- `WAGO_API_KEY`: token for the existing Wago project **96E7kPGg**, if Wago publishing is used.
- GitHub's automatic `GITHUB_TOKEN`: supplied to the packager as `GITHUB_OAUTH`, with release write permission.

Never put tokens in source files. A local package does not verify remote token
permissions or publish anything. To test the official packager without uploading,
run its `release.sh -d -e -l -u` in a clean checkout with Bash 4.3+, then validate the
result with `python3 tools/verify-package.py /path/to/package.zip`.

## Artwork and integrations

`tools/verify-artwork.py` validates the runtime load graph, approved texture bytes,
alpha, margins and mappings without needing any generation files. After editing
the shared spec atlas, run `python3 tools/build_details_atlas.py` to rebuild the
Details compatibility atlas, including its alternate Rogue cells and inset crops.

`tools/create-social-image.py` lays out all 40 icons without labels on dark gray.
Its default uses the game atlas; `--masters /path/to/transparent` uses larger final
cutouts. `--background '#17191c'` controls the solid background. The output is
`images/FabledSpecializationsSocial.png` at 3200 × 2000.

The shared specialization lookup supports Retail/Mists selected specs, Classic
talent points and Forever trait-group totals. Remote inspection is GUID-scoped,
throttled and suspended in combat or when manual inspection has priority. Cached
results refresh after one minute and expire after five. Explicit spec changes
invalidate old results. Unknown/restricted units must not inherit another icon.

Damage meters use each recorded combatant's class/spec metadata, with Regalia
fallback; they do not inspect live targets. Preserve native layout, visibility,
spell icons and restored textures when disabling the integration.

## In-game acceptance

**1.4.8:** The user confirmed successful in-game testing on both Retail and Forever
on September 30, 2026 and approved release. This is user-reported live validation
in addition to the automated checks above.

1. Follow [UPGRADING.md](UPGRADING.md), fully restart WoW, confirm saved profiles and enable only the new folder.
2. Check normal/mirrored spec icons and existing class/race packs on Blizzard, ElvUI, SUF and EllesmereUI frames. Verify ElvUI tags and profile switching.
3. Switch talents and targets; check Classic/Forever dominant, tied and empty builds, Retail/Mists selected specs, party reassignments and unknown/restricted units. Verify manual inspection and combat behavior.
4. Select Fabled Specializations in Details. Check current and historical combatants, fallback and crop edges, including Rogue on supported clients.
5. Enable each optional damage-meter integration. Test Edit Mode, pinned rows, scrolling, multiple windows, hidden icons and profile changes. Disable it and confirm the native icons return. Spell drilldowns must remain unchanged.
6. Record client/addon versions and any errors or taint before publishing. Automated checks establish packaging and fixture behavior, not complete live-game compatibility.
