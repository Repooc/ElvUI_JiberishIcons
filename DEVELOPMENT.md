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
`## Version` in the TOC. The unit-frame themes, portraits, crosshair and profile-sharing release is `1.7.0`;
publish it with the matching `1.7.0` tag after the release checks pass. `1.6.2` and
earlier are already published; never replace or reuse an existing release tag.

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
class. The shared resolver can also read `C_TooltipInfo.GetUnit` directly, so
EllesmereUI and other frame integrations do not need ElvUI for this shortcut.
Match localized spec/class names only on native UnitType lines or immediately
after UnitLevel; ignore names, guilds and unrelated tooltip text. Missing,
restricted or unsupported tooltip data falls back to the existing inspection
path. GUID-scoped `TOOLTIP_DATA_UPDATE` requests repaint when sparse data arrives;
they never apply an old target's answer to its replacement. Classic/Forever
talent trees and personal builds retain their original sources. ElvUI spec tags
use events instead of half-second polling;
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
integration. Blizzard's opt-in Custom Icon Size resizes the player icon holder,
letting native bar/name anchors follow its width. Sizes are capped to row height
because native rows clip children. Retain the latest underlying holder dimensions
across skin refreshes and restore them on disable or a non-player row. Geometry
changes on protected holders wait until combat ends; stock unprotected holders
retain custom sizing during combat skin refreshes. Check 18px skinned and 24px native holders, Edit
Mode bar-height changes, pinned/recycled rows, hidden icons and profile changes
in game; offline fixtures cannot establish live taint or visual compatibility.

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

**1.7.0 — Bushido unit-frame themes:** `UnitFrameThemes.lua` adds masks,
outlines, optional division marks and Bushido end-cap artwork to existing
ElvUI/EllesmereUI status bars. It does not create a replacement unit frame,
register an oUF style, read/write health values, write host profile settings,
change fill textures/colors/gradients, or move host bars, labels or auras.
ElvUI continues to use its oUF engine; the installed EllesmereUI version has its
own native engine. The supplied `BushidoEndPoint.tga` is copied byte for byte from
the user's `JiberishUI_Ellesmere/Media/EndCaps` addon (originally JiberishMedia).
`tools/build-bushido-shapes.py` generates the other assets without overwriting it.
All 258 assets, including pre-oriented masks, have a separate packaging/hash/alpha/geometry fixture.

Adapters discover ElvUI `E.oUF.objects` by `unitframeType`, EllesmereUI individual
`ns.frames`/Engine attachments, and Raid Frames `_partyAllButtons`/`_allButtons`
with `GetFFD`. These host internals are version-sensitive. Individual categories
cover player/target/focus/pet/targettarget/focustarget/boss; both hosts have party
and raid scopes, plus ElvUI arena. EllesmereUI's separate friendly-boss extra
frames and both hosts' nameplates/party pets/party targets are outside this scope.
EllesmereUI Blizzard/Classic art kits keep their own appearance; use its normal
EllesmereUI frame style. Layout/texture hooks and coalesced events discover changes;
there is no recurring health or frame-discovery poll.

Only owned masks are removed. Masks anchor to the full native bar, including
absorb, heal-absorb, incoming heal and ElvUI cutaway textures. A host health texture
with all three mask slots occupied retains its original shape and border.
Prediction textures with full mask slots remain untouched. The optional native
border replacement hides dedicated borders and rectangular shadows, including
Eltruism's per-unit/group borders, universal borders and ElvUI inner/outer edges.
Backdrop Center and backdropTex textures receive masks while retaining host
gradients and opacity; only backdrop edge regions are suppressed when Center is
available. Eltruism's cosmetic configuration hooks queue another discovery pass
for late objects without hooking per-health-update gradient calls. A highlight
rendered on that same object is also hidden, so disable border replacement if
that highlight is needed. Alpha hooks preserve the latest host writes for restore.
Theme changes, geometry, creation and restoration defer in combat; existing
textures can receive masks when replaced, and end-cap colors re-read the current
unit without caching restricted identities. Unit click rectangles remain native.

Automated fixtures cover opt-in behavior, both adapters, host resize/orientation,
texture replacement in combat, predictions, cutaway, profile copy/reset,
native restoration, later host alpha edits, Eltruism backdrop gradients and late
borders/shadows, foreign masks, full mask slots,
replaced frames, raid categories, party unit reassignment, unavailable identities
and host availability. In-game acceptance is pending: test both hosts separately,
all categories, host and JiberishIcons profile switches, rapid target swaps,
low/full/empty health, absorbs and heal prediction, reverse/vertical fills,
Eltruism gradients, fading, attached portraits, borders/highlights and combat
transitions. Confirm native clicks, auras and text are unaffected and inspect
the client error/taint log. Disable the old plugin's shape/end-cap styling on the
same frames when comparing, so the two renderers do not stack.

**1.7.0 — crosshair and GCD:** `Crosshair.lua` owns an opt-in, unprotected
UIParent marker. Four marker styles and four hollow GCD shapes use white tintable
32-bit TGAs generated by `tools/build-crosshair-shapes.py`, in thin/bold weights
and 32/64/128/256px sizes. The dedicated texture manifest participates in release
packaging; Python checks validate hashes, decoding, alpha, margins and hollow centers.
The native cooldown swipe fills the outline texture without shading its center.
Only global cooldown spell 61304 is read. Modern clients pass
`C_Spell.GetSpellCooldownDuration` objects directly to the native cooldown;
legacy clients use public `GetSpellCooldown` timestamps and rate. Unavailable
or restricted legacy values clear the swipe. No per-frame Lua polling is used.
GCD events refresh current state; native completion clears progress. The empty
outline remains while the marker is visible, unless its alpha is zero.

The marker is fixed in screen space, not attached to the 3D character. Placement
controls cancel drags; profile changes discard unfinished drags. Creation and
layout defer in combat, while visibility and existing cooldowns can update.
Preview loops only while unlocked and auto-locks on combat entry. All options
default off. Automated fixtures cover visibility, GCD sources and completion,
preview, profile copy/reset, drag cancellation, deferred layout and texture paths.
Before release, test `/ji` → Crosshair on Retail and Classic/Forever: position it
over the character, reload, change profiles, enter/leave combat while dragging,
cast rapidly (including off-GCD spells), and try every outline at different sizes
and UI scales. Confirm fill direction, smooth corners, click-through behavior and
no taint or duplicate cooldown numbers with installed UI addons. Offline checks
do not establish native GPU rendering or live client behavior.

**1.6.1 — Blizzard damage meter icon sizing (October 10, 2026):** The user
confirmed the custom icon size control works well in game. This confirms the
reported sizing fix, not exhaustive testing of every client or skin. Automated
fixtures cover row-height limits, skin refreshes during combat, pinned/recycled
rows, hidden icons, restoration, profile reset and protected-holder deferral.
Release preparation includes the version bump, concise README and verified ZIP.

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


**1.7.0 — native themes and 3D portraits:**
`PortraitModel.lua` is a renderer inside the existing Portraits lifecycle. It uses
an unprotected PlayerModel with an independent tall viewport, a rear rim and a
foreground lower lip. Geometry and creation wait for combat end; identity events
refresh already-created models in combat. Existing anchor visibility checks,
profile handling and click-through behavior apply to 3D portraits too. The shield
uses a 100x110 design space; the revised default viewport is 94x160, bottom 8.
Camera fitting still needs live validation across races, hair, helmets and forms.
Circle, diamond and square use split rear/front frames as well. A 3D viewport
is rectangular, not a polygon mask; the inset foreground art covers the lower
bust, so extreme user-selected model offsets may extend past the frame.

The retired HUD has no loaded module, options, dial, action skins or ring assets.
On profile initialization/switch, its enabled player/target/focus portraits move
into Portraits only when no enabled Portraits entry exists. Placement and colors
are preserved, with the new default camera fit. Obsolete HUD data is removed.
Native unit-frame theme settings and host mover settings are preserved.

Overwatch Unit Frame Themes mask native fill/background and prediction textures
into rounded cells without writing health values, text, fonts or gradient colors.
Five, ten or twenty cells divide the fitted row evenly; health fills continuously.
Six gap levels, six outline weights and mirrored/vertical orientations share the
same geometry. Outer clearance prevents first/last-cell clipping. Optional cell
outlines default off, with independent opacity and half-step width controls.

`build-overwatch-shapes.py` generates only native cell masks/borders and layered
portrait textures. Shapes use design-pixel signed-distance coverage or 8x polygon
rasterization, then area filtering; asset tests check gaps, edge containment,
rounded corners, inset accents, actual TGA decoding and manifest hashes.

Crosshair GCD timing selects spell 29515 for the 16000–19999 Classic beta/Forever
interface range, otherwise 61304. Native duration objects include the GCD and are
passed directly to Cooldown; nil duration results fall back to public timestamps.
Spellcast events schedule one next-frame refresh to handle stale cooldown caches;
SPELL_UPDATE_COOLDOWN remains the primary event. The GCD track and swipe share
independent X/Y offsets relative to the crosshair and defer geometry during combat.

**Individual layout copying and sharing:** `FrameLayout.lua` restricts copy/reverse
to six individual units. Theme, portrait and host-icon tables are deep-copied.
Horizontal anchors, end caps, slants, model facing and cast-label offsets mirror;
vertical offsets and the destination host position remain unchanged. Screen/custom
portraits convert from live scaled coordinates to host-edge attachments. Optional
ElvUI width/height copying uses its native update method and never writes its auras,
colors, text or mover settings. Protected changes are blocked during combat.

`ProfileSharing.lua` uses bundled AceSerializer-3.0 (under the existing Ace3 license).
The printable `!JI1!` envelope includes a checksum and format version. Strings are
uncompressed so the input length bounds parser allocation; imports also bound depth,
value count and field types and never execute code. Exports include the complete
current AceDB profile with materialized defaults, plus global custom-pack definitions
and editor settings. Imports create a fresh profile and reject conflicting custom-pack
names before mutation. Image binaries and other addons’ databases are not exported.
Export locks/saves movers first; live import refreshes portraits, themes, crosshair,
icons, meters and chat. ElvUI/SUF adapter refreshes defer in combat.
Tests cover all individual units, double reversal, source independence, group
exclusion, scaled screen attachments, host size updates, full profile round trips,
custom metadata, duplicate names, corrupt input, type errors and combat restrictions.


**Native settings presentation:** `SettingsWindow.lua` now styles the existing
option tree and routes `/ji` to `ElvUI:ToggleOptions('jiberishicons')`. ElvUI owns
its fonts, widgets, skin and layout. The standalone path uses a matching stock
AceConfig registry/dialog pair; no `JiberishIconsStudio` app or custom container
is registered. Scoped post-hooks decorate the plugin's trees and tabs; host
controls and shared widget definitions remain unchanged.

ElvUI's `Config_CreateLeftButtons` adds `key` and a root menu `func` to each
plugin's live option table. Passing that tree to another registry caused the
reported unknown-parameter error. `BuildStandaloneOptions` copies option nodes,
excluding `key` and the host root menu action, while preserving handler/value
tables and callback behavior. Both renderers use `SettingsOptions`, a display
root with `icons` and `plus` wrapper groups referencing the original section
nodes in `Options`. Existing custom-style builders retain their direct source
references. All getters/setters use relative path suffixes or closures, so the
new wrapper does not change saved-variable paths. `SelectSettingsGroup` inserts
the appropriate wrapper for existing internal navigation requests.

The main tabs are JiberishIcons, Jiberish Plus, Profiles and Help. The first
two contain compact section trees with custom icons and nested native tabs. Short
sidebar labels are white except for the selected section, which uses its own
two-stop gradient. A FeedGroup post-hook decorates the plugin section trees and
tab groups, refreshing after RefreshTree, BuildTabs and SelectTab. Nested tabs
inherit their section palette. Ownership is checked every time because AceGUI
recycles widgets; other addons are ignored. Disabled tabs stay gray. A separate
post-hook restores the branded ElvUI sidebar text after Config_SetButtonText
strips selected-button color codes, scoped strictly to the jiberishicons key.
The title uses independent blue–purple and pink–orange UTF-8 gradients without
passing a literal pipe through per-character color formatting.
`tools/build-settings-art.py` draws 12 original UI glyphs on a supersampled grid
and exports standard RGBA TGAs with 2.8px rounded strokes on a 32px grid.
Navigation assets are independent of the class,
race and specialization packs. The old rounded panel and dashboard preview
module are removed from the load graph and distribution.

Regression tests reproduce the exact `key: unknown parameter` failure with
stock AceConfigRegistry, then validate the cleaned tree and every section after
simulated host decoration. They check host/standalone routing, combat guards,
callback preservation, distinct settings icons and profile sharing. Actual
in-game text metrics and visual layout still need the normal client check.


**Lossless texture storage and mask orientation:** All five generated-art
builders now use `texture_utils.save_tga_rle`: standard type-10 32-bit TGA,
8-bit alpha, scanline-bounded RLE packets. The encoder checks dimensions and
exact decoded RGBA against its input through the independent decoder before
writing. `optimize-shape-textures.py` can repack existing generated assets after
validating their approved hashes, without regenerating/resampling any pixels.
The original 565 generated images retained all approved pixel hashes; the 17
supplied/original artwork files were left byte-for-byte intact. Only storage
encoding changed, with no Lua decompressor or effect on decoded GPU footprint.
Pillow and the independent TGA decoder validate every shipped generated texture.

Runtime masks now keep their default UV coordinates. MaskTexture transformations
are not interchangeable with ordinary Texture transforms; see the
[developer reproduction and workaround](https://wowinterface.com/forums/archive/index.php/t-60142.html).
Reversing the target previously changed its native mask UVs while the separately
drawn border remained visible. Generators now produce exact horizontal mirrors
and 90-degree rotations (no resampling) for masks only, including power bars and
all Overwatch cell counts, gap levels and styles. Visible borders retain their
existing UV transforms. No host gradient/color/alpha settings are overwritten.
Existing saved `diagonalback`/`reverseSegments` values select the new masks on
startup; no SavedVariables migration or manual profile reset is needed.

The 801 generated assets, including 236 directional masks, occupy approximately
20 MB; the complete active addon is approximately 99 MB (previously 236 MB).
Regression checks cover exact oriented-mask pixels, all original pixel hashes,
compression budgets, copy/reverse/reverse-again and a fresh renderer with saved
reversed settings. Full in-game acceptance still requires a client restart to
discover the new texture paths, followed by player-to-target copy, reversal,
reload, health/power changes and verification with Eltruism gradients enabled.
