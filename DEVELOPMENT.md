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

Publish from **Repooc/ElvUI_JiberishIcons** (`upstream`), which owns the existing
`CF_API_KEY` and `WAGO_API_KEY` GitHub Actions secrets. The
`jiberishxd/ElvUI_JiberishIcons` repository (`origin`) is the contribution fork;
it is not the publishing repository. Do not request new tokens or configure
CurseForge's separate auto-packager when secrets are absent from the fork.
Open a pull request to upstream, merge after validation, then push the matching
release tag to upstream. Its existing workflow uploads the verified ZIP.

The installed folder is `JiberishIcons`; the visible title is **Jiberish Fabled Icons**.
The existing GitHub repository name and CurseForge/Wago project IDs are retained
so existing project subscriptions continue to receive updates.

Branch pushes and pull requests run validation only. Publishing runs on a version
tag, after validation succeeds. The tag (optionally prefixed with `v`) must match
`## Version` in the TOC. The portrait release is `1.6.0`; publish it with the
matching `1.6.0` tag after the release checks pass. `1.5.0` is already published;
never replace or reuse an existing release tag.

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

When ElvUI provides `GetUnitSpecInfo`, remote Retail/Mists units first try its
tooltip lookup, accepting only public specialization IDs matching the unit's
class. Missing, restricted or unsupported tooltip data falls back to the existing
lookup/inspection path. Classic/Forever talent trees and personal builds retain
their original sources. ElvUI spec tags use events instead of half-second polling;
the shared driver also repaints visible tagged frames on target/focus changes,
inspection replies and OpenRaid callbacks, independently of portrait settings.
Verify rapid retargeting, focus changes and delayed inspection replies in game;
automated fixtures do not measure tooltip availability or live response times.

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

**1.6.0 candidate — independent portraits:** The portrait module is an independent
implementation. Circle/droplet geometry builds in regular and thin variants,
using standard uncompressed 32-bit TGA with 8-bit alpha, like the shipped icon
atlases. Do not treat an offline decoder as proof of client texture support.
`tools/build-portrait-shapes.py` (NumPy/Pillow) generates
ten shape/mask families at 32, 64, 128, 256, 512 and 1024px, recorded in
`tests/fixtures/portrait-textures.json`. The runtime selects a size appropriate
to the physical display scale and uses linear filtering with texel snapping off.
Both the existing TGA reader and Pillow validate the actual shipped files, and
integration tests check every runtime border/mask path. No external portrait implementation or
runtime dependency is included. All portraits default off. Visual holders belong
to UIParent, use no secure button template, and are click-through when locked.
Creation and layout changes wait until combat ends; existing textures can repaint.
The shared specialization driver supplies late results. Target-of-target uses a
bounded 0.2-second refresh; other portraits use unit events plus visibility checks.
Three Additional slots support fixed class/spec/race icons or a selected live
unit, with optional borders. Fixed icons do not depend on unit existence. ElvUI
anchors prefer its canonical individual frames over party self-buttons. Numeric
placement and anchor-point controls cancel unfinished drags; screen clamping is
only active while dragging, and WoW's separate user-placed persistence is disabled.

`PortraitCast.lua` adds opt-in Player/Target rings to Circle and Thin circle only.
The native Cooldown swipe uses the same annular TGA and physical-size selection as
the border, with no segmented geometry, edge spark or bling. Cast/channel colors
include alpha and are independent per unit. Text uses shared-media fonts with
separate name/time anchors. A separate masked spell texture overlays the normal
portrait and clears at completion, interruption, target loss or disable. Spellcast
events re-read current unit state rather than compare cast IDs, so late stop events
cannot clear a newer cast. Modern clients pass duration objects directly to native
cooldown widgets and secret name/icon/time values directly to display widgets.
Older clients animate readable timestamps; restricted timestamps without a duration
API fail closed. Channels drain; casts and empowered channels fill. The cast driver
only creates widgets out of combat, and live events never move or resize them.
The countdown updates at most every 0.05 seconds while shown; preview casts loop
only while unlocked. No external cast-bar implementation is included.

The native method contracts are in Blizzard's generated
[Cooldown documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPICooldownDocumentation.lua).
Offline fixtures cover public/secret casts, channel and empower durations, legacy
player APIs, delays, interruption, target swaps, preview, colors, font/position
settings, scale-dependent textures and profile reset. Live acceptance must also
check both rings during combat, rapid casts/channels, empower hold, spell icons,
small sizes and different UI scales. Confirm the circle edge and swipe look smooth
in the actual game and that no cooldown-number addon adds duplicate text.

Before release, test `/ji` → Portraits on Retail and Forever: enable player/target,
preview and drag absent party/boss units, reload and switch profiles, attach to
Blizzard/ElvUI/named frames, hide/show and move the anchor, switch live units and
specializations, and check pets/NPCs with 2D fallback. Test circle/both droplets at
small/large sizes, masks and icon cropping, UI scale changes, entering combat while
dragging, deferred layout after combat, party sorting and target-of-target changes.
The initial portrait functionality was confirmed in game. The latest placement,
texture and cast-ring changes still require live validation after a full restart.
Automated fixtures cover state transitions, but not live taint restrictions or
the game's portrait rendering. Release preparation is not a claim of in-game
validation.

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
