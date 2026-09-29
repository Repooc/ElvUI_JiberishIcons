# Pre-release validation: Fabled packs (1.5.0-rc.4)

Historical validation record for the September 29, 2026 candidate. The user requested publication as stable version 1.4.7 after merging PR #12. The release keeps the candidate artwork and runtime fixes, with the final version and consolidated changelog. Automated checks are recorded below; in-game UI automation was not performed.

## Contents

- Fabled Regalia: 13 class emblems.
- Fabled Azeroth: 26 race emblems, including Earthen and Haranir.
- Both packs: 256 × 256 cells, 2048 × 2048 transparent 32-bit TGA sheets.
- Fabled Core: the existing 13 designs resampled and lightly sharpened to 256px cells on a 2048px sheet. All other texture files stay unchanged from rc.3.
- Regalia/Azeroth descriptions credit Blizzard Entertainment's class/race crests and official reference pages; JiberishUI's website links point to https://theigloo.io/.
- Race-aware selectors for Blizzard, ElvUI, SUF, EllesmereUI and Chat; class-only integrations retain the class roster.
- Updated selection, fallback and portrait controls, with 28 passing mocked integration checks plus 4 checkbox regression checks.

The installable archive is `dist/ElvUI_JiberishIcons-1.5.0-rc.4.zip`. It contains one `ElvUI_JiberishIcons` directory, bundled libraries, artwork, license and changelog. Generated masters, tools, previews, tests and development files are excluded. Its SHA-256 checksum is saved beside it.

## Completed validation

- 28 mocked integration checks passed, including race selection, secret/missing identity, independent class/race styles, reversal, Apply To All, fallback, chat and Classic API fixtures.
- 4 real AceGUI checkbox checks passed: creation without the removed global helper, disabled/tristate behavior, click callbacks and sounds, and widget pooling/version upgrades. The test reproduced the reported line-130 crash before the update.
- All 83 addon Lua files passed Lua 5.1 syntax checks; `git diff --check` passed.
- Both TGA sheets independently decoded as 2048 × 2048 RGBA and matched their PNGs exactly. All 39 cells matched their individual 256 × 256 PNGs and Lua coordinates, with transparent margins and empty unused cells.
- Fabled Core's lossless RLE independently decoded and matched its PNG exactly; all 13 cells matched their PNGs and class mapping, with preserved placement and clear alpha margins. The 12 other textures, including eight older sets, Regalia/Azeroth and both logos, were verified byte-identical to rc.3.
- Artwork visually reviewed at 128, 64 and 32 pixels, including dark and light background comparisons.
- ZIP integrity and byte-for-byte comparison passed for all 141 files. Archive size: 9,520,317 bytes.
- SHA-256: `28ebbc46e56e6591f9de9a6025ddb27d82479e9cedf35256e450db82e5ed0003`.

These checks do not establish in-game rendering, combat safety or acceptance on each supported WoW client. Frostforge was used as a read-only style reference and was not modified.

## Resolution upgrade

Both new packs now use power-of-two 2048 × 2048 sheets with 256px cells and lossless 32-bit alpha. They were rebuilt directly from their original cleaned masters, preserving four transparent pixels around each cell. Their on-screen dimensions, relative padding and normalized coordinates stay the same. Chat, ElvUI tags and configuration previews use the correct per-style texture dimensions, including fallback to older 1024px packs. At a 2× display scale, a 128-unit icon now has 256 source pixels available.

See `artwork/fabled/hd-comparison.png` for a simulated 256px comparison of enlarged old icons against the new native exports. This is an export comparison, not a screenshot from the game.

Fabled Core is the only older set upgraded in rc.4. Each original 128px cell is enlarged separately with alpha-aware Lanczos and restrained RGB sharpening, retaining its existing artwork, padding and placement. This improves scaling and contrast; it does not recover additional detail from a higher-resolution master. Its 2048px sheet uses lossless 32-bit RLE TGA (2,230,181 bytes on disk; 16 MiB decoded, versus 4 MiB previously). The other eight older sets stay at 1024px. See `artwork/fabledcore/comparison.png` for all thirteen before/after pairs.

## Forever beta compatibility

The installed beta at `/Applications/World of Warcraft/_classic_beta_` reports 1.60.1.70009. The TOC now includes Interface 16001, matching the installed EllesmereUI 9.3.3 Forever metadata. The adapter hooks were checked against that installed version. Optional integrations must be loaded before they are accessed, regardless of the client project ID.

The checkbox widget uses [upstream AceGUI version 27](https://github.com/WoWUIDev/Ace3/blob/master/AceGUI-3.0/widgets/AceGUIWidget-CheckBox.lua), calling the texture desaturation method directly. In-game UI automation was not approved for WoW, so post-fix beta testing remains manual.

The existing Forever beta addon has been updated to rc.4; all 141 installed files match the verified archive. Only five files changed from rc.3: Core/Core.lua, Core/Options.lua, the TOC, Fabled Core's TGA, and the changelog. The full prior addon backup is `dist/backups/forever-beta-before-1.5.0-rc.4.zip`; the exact update plan is `dist/forever-beta-core-update-plan.json`. Saved variables and Frostforge were untouched. Fully exit and restart the beta to replace any cached textures, refresh compatibility metadata, and retest `/ji` → EllesmereUI.

## Test in WoW

This machine's Retail addon already links to this checkout. Fully exit and restart WoW to load the new textures; keep WowUp's Ignore setting active. Do not extract the ZIP over the linked folder. For another installation, extract the archive into that client's `Interface/AddOns` directory.

1. Open `/ji` and check the Class Styles and Race Styles previews. Check all 13 classes and 26 races for correct labels, clean transparent edges, and readable artwork at 32, 48, 64 and 128 pixels. Check Fabled Core at the largest supported scale, in both orientations, and confirm the new website and Blizzard reference credits.
2. Select Fabled Regalia and Fabled Azeroth on supported frames. Check Player, Target, Focus, Target of Target and Focus Target as available. Mix a class portrait with a race icon and verify they stay independent.
3. Check Human/Orc, Undead, Pandaren, Dracthyr, Earthen, Haranir and allied-race players. Switch to an NPC, pet and no target; stale race icons must disappear. Race information restricted by the game should hide the icon.
4. Toggle Reverse, Apply To All, switch/copy/reset profiles, reload and zone. Check combat updates, frame fading and vehicle changes without Lua errors or taint.
5. In ElvUI custom text, check `[jiberish:class:fabledregalia{32}]`, `[jiberish:race:fabledazeroth{32}]` and `[jiberish:race:fabledazeroth:reverse{32}]`. For ElvUI/SUF race portraits, select their class portrait mode first.
6. Select the race style in Chat; new player messages with known identity should show the right race. Check Fabled Regalia in Details!/Eltruism when installed, and verify earlier stock/custom packs still work.
7. Smoke-test with each optional integration disabled. Record the actual client build and addon versions tested; the compatibility TOC alone does not establish Classic-client acceptance.

## Stable release

The selected stable version is `1.4.7`. The final TOC and changelog are prepared separately from this archived candidate record. Follow `DEVELOPMENT.md` for PR, merge, annotated upstream tagging, and verification of CurseForge/Wago uploads. The local stable archive is `dist/ElvUI_JiberishIcons-1.4.7.zip`; historical candidate hashes above still refer to rc.4.
