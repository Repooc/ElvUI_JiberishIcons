# 1.4.9 — Fabled Class (October 2, 2026)

- Add **Fabled Class**: all 13 class icons in the bold illustrated style of Fabled Specializations, with thicker continuous black borders and clean transparent edges for small UI sizes.
- Include the final Druid effects and ivory Priest handle. Select Fabled Class on supported unit frames, in chat, with normal/reversed ElvUI tags, and in Details! and Eltruism integrations.
- Export one transparent 2048 × 2048 sheet with 256px cells and eight-pixel safety margins. Ship only required addon assets; exclude artwork drafts, previews and source archives from the addon download.
- Improve Forever's Blizzard and Ellesmere damage-meter specialization icons by using committed player talents and GUID-matched, verified party builds when native meters supply class icons. Refresh inspections and native meter data after combat, and handle reused rows without carrying another player's artwork.
- Retain confirmed builds through temporary API failures without extending cache expiry. Invalidate them when the active build changes; keep recorded specialization lookup for historical fights.
- Add a conservative combat fallback for unchanged parties: after a readable meter snapshot, retain specialization art only when all possible remote members of that class share the same confirmed spec. Conflicting, unknown or expired builds retain Regalia. A new party may need one completed fight and an out-of-combat inspection; this does not provide general hidden-identity or raid specialization support.

# 1.4.8 — Jiberish Fabled Icons (September 30, 2026)

- Rename the install folder to **JiberishIcons** and the addon to **Jiberish Fabled Icons**. Follow **UPGRADING.md** to keep existing profiles when switching folders.
- Add **Fabled Specializations**: 40 transparent icons designed for small UI sizes, including the final glowing Holy Paladin tome, Arms Warrior axe, fire-cat Feral, Guardian paw, Mage eyes and Death Knight skulls.
- Offer specialization icons on supported Blizzard, ElvUI, Shadowed Unit Frames and EllesmereUI frames. Add EllesmereUI Party settings and normal/mirrored ElvUI specialization tags.
- Support Classic/Forever talent-tree point totals alongside Retail/Mists selected specializations. Unspent or tied personal builds fall back to the Regalia class crest.
- Inspect nearby targets and party members automatically when needed and allowed. Cache confirmed results for faster retargeting, prioritize the current target, and preserve manual inspection and combat restrictions. An uncached target still requires a server response.
- Add **Fabled Specializations (Spec)** to Details! with a dedicated atlas that preserves the artwork under its native crops.
- Add separate opt-in **Blizzard Damage Meter** and **Ellesmere Damage Meters** settings, including class/spec styles, reverse direction and a Blizzard Edit Mode shortcut. Preserve native layout, sizing, visibility and spell icons; restore native player icons when disabled.
- Keep existing class/race packs, profiles and external style compatibility. Ship only required addon files and licenses, with automated release validation.

v1.4.7 9/29/26

• [Feature] Add Fabled Regalia: 13 class crests inspired by Blizzard Entertainment's official World of Warcraft class symbols.
• [Feature] Add Fabled Azeroth: 26 race crests, including Earthen and Haranir, with race selection for Blizzard, ElvUI, Shadowed Unit Frames, EllesmereUI and Chat, plus normal and reversed ElvUI race tags.
• [Update] Export Regalia and Azeroth from their original artwork at 256 pixels per icon on transparent 2048 × 2048 sheets for clearer large icons. Fabled Regalia is also available in Details! and Eltruism.
• [Update] Improve Fabled Core's existing artwork with careful resampling and light sharpening at the same 256-pixel resolution, preserving its design and placement. All other older packs remain unchanged.
• [Update] Add WoW Forever beta compatibility (Interface 16001), and load optional integrations only after they are available.
• [Fix] Update AceGUI's checkbox widget to resolve the missing SetDesaturation error when opening settings panels.
• [Fix] Keep race and class selection, missing-texture fallback, reversed crops, chat and previews consistent across texture resolutions. Hide unavailable race identities and keep icon and portrait selections independent.
• [Fix] Repair Blizzard portrait Apply To All controls.
• [Update] Credit Blizzard's official class and race reference pages and update JiberishUI's website links to https://theigloo.io/.

v1.4.6 9/15/26

• [Feature] Add per-frame Reverse options to mirror class artwork horizontally in EllesmereUI, Blizzard, ElvUI and SUF settings, plus Chat icons. Includes bulk Normal/Reverse controls and preserves existing ElvUI reverse tags.
• [Feature] Add movable class icons for EllesmereUI player, target, focus, target-of-target and focus-target frames. Configure each icon through /ji without changing EllesmereUI portraits.
• [Update] TOC compatibility for Retail, Mists of Pandaria, Wrath, The Burning Crusade and Classic Era in one addon package.
• [Fix] Keep options and chat icons compatible with clients without Retail-only APIs, and display the full addon version in settings.
