# Development and releases

## Repository contents

- `JiberishIcons/`: loaded Lua/XML files, required library licenses and the final game textures.
- `tests/`: integration tests and small artwork checksum/coordinate fixtures.
- `tools/`: release validation/packaging, optional settings migration and final-image export.
- `images/`: the four finished previews referenced by the README; excluded from addon ZIPs.
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
`## Version` in the TOC. The stable release is `1.5.0`; publish it with the
matching `1.5.0` tag after the release checks pass.

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
Forever's personal committed-build cache also survives unavailable talent reads
for the same config/group, but explicit active-build changes invalidate it.

Damage meters prefer each recorded combatant's class/spec metadata. Forever's
Current/Overall views can supplement missing specs with committed player talents
or a GUID-matched unit's verified build, using the existing inspection queue.
An enabled live spec meter primes public group/target/focus tokens independently
of row identities. A passive GUID-cache lookup retains already-confirmed players
after their unit token disappears, without extending expiry. Native data is
refetched after combat or an inactive restriction-state event; retain scrolling,
coalesce events and do not confuse the activation event with declassification.
Public Player GUIDs and the local-player flag identify meter players even when
the unrelated sourceCreatureID field is restricted. A readable GUID may use its
confirmed cache entry through a unit API outage; never use a previous row's icon
to guess a hidden identity or extend the inspection cache lifetime.
Those live views track current builds, not historical talent snapshots. Explicit
historical sessions never query live talents. Unknown/ambiguous/restricted
identities retain Regalia except for the bounded party inference below. Preserve
native layout, visibility, spell icons and restored textures when disabling the
integration.

`DamageMeterParty.lua` snapshots the full readable native session per window.
For restricted GUIDs only, a previously seen class/icon key may choose a spec if
all remote party candidates of that class have the same unexpired confirmed
build. The public local-player flag excludes our own build. This is conservative
inference from the unchanged party, not recovery of a hidden GUID; never pin
artwork to row position. Include all party members even if absent from the meter.
Conflicting/outside/pet keys block inference. Invalidate on roster/spec changes,
zoning and meter reset, and reject raids, enemy views and explicit historical
sessions. Full snapshots cover off-screen participants. Empty Current sessions
between pulls retain evidence for the unchanged party. New groups may require a
completed fight and inspections before the next pull can use this workaround.

## In-game acceptance

**1.5.0 — Fabled Myth remaster (October 7, 2026):** The user approved the final
artwork and requested publishing to GitHub and CurseForge. All 13 original motifs
were redrawn using the built-in image generator, preserving their subjects and
palettes while increasing shape weight and reducing fine graffiti noise. The
runtime atlas uses 256px cells on a 2048px sheet with eight-pixel margins. Final
PNG masters and the per-class prompts are retained locally in ignored
`dist/FabledMyth-Artwork/`; `dist/FabledMyth-SmallSizeComparison.png` compares
the original and refreshed artwork at 24, 32, 48 and 64 pixels. These are visual
export checks, not live WoW validation. No additional in-game confirmation was
reported; release approval is not a claim of exhaustive live validation.

**1.4.9:** The user approved shipping the final Fabled Class artwork and current
release on October 2, 2026. The user had reported rough class-icon edges in game;
the final export adds a rounded black contour behind all 13 icons, preserving
opaque source colors and interior details. Automated checks cover source files,
Lua syntax, integrations, texture hashes, coordinates, transparency, margins and
ZIP contents. No additional in-game confirmation after the border refinement
was reported; release approval is not a claim of exhaustive live validation.

Forever party icons were confirmed working after combat during candidate testing.
The final party-consensus workaround remains deliberately bounded: it requires an
unchanged party, an observed class/icon key and unexpired confirmed builds shared
by all possible remote members of that class. Mixed/unknown builds, raids and
historical/enemy views retain the documented fallbacks. It does not recover hidden
player identities or provide general in-combat specialization support.

Only `Media/Class/fabledclass.tga` ships for Fabled Class. The high-resolution PNG
masters remain locally in ignored `dist/FabledClass-Artwork.zip`; superseded
artwork folders, candidate packages and comparison previews are removed. Keep the
following in-game checklist for future changes and user-reported regressions.

**1.4.8:** The user confirmed successful in-game testing on both Retail and Forever
on September 30, 2026 and approved release. This is user-reported live validation
in addition to the automated checks above.

1. Follow [UPGRADING.md](UPGRADING.md), fully restart WoW, confirm saved profiles and enable only the new folder.
2. Check normal/mirrored spec icons and existing class/race packs on Blizzard, ElvUI, SUF and EllesmereUI frames. Verify ElvUI tags and profile switching.
3. Switch talents and targets; check Classic/Forever dominant, tied and empty builds, Retail/Mists selected specs, party reassignments and unknown/restricted units. Verify manual inspection and combat behavior.
4. Select Fabled Specializations in Details. Check current and historical combatants, fallback and crop edges, including Rogue on supported clients.
5. Enable each optional damage-meter integration. Test Edit Mode, pinned rows, scrolling, multiple windows, hidden icons and profile changes. Disable it and confirm the native icons return. Spell drilldowns must remain unchanged.
6. Record client/addon versions and any errors or taint before publishing. Automated checks establish packaging and fixture behavior, not complete live-game compatibility.
