# 1.7.0 — Unit frame themes, 3D portraits, crosshair and profile sharing (November 10, 2026)

- Supports Retail 12.1.5 (120105), Forever 1.60.1 (16001), Mists, Titan, Anniversary and Classic Era clients.

## Lossless texture optimization and reverse-mask fix

- Compress generated Bushido, Overwatch, portrait, crosshair and settings textures with lossless 32-bit TGA RLE. Preserve resolution, every RGB/alpha pixel, all options and the supplied artwork. Keep the texture generators on the same verified encoding.
- Replace unit-frame mask UV flipping/rotation with pre-oriented masks to address disappearing health fills after reversing a copied layout. Preserve native health/power textures, Eltruism gradients, opacity and saved settings. Existing reversed layouts select the corrected masks after restarting the client.
- Reduce the active addon from approximately 236 MB to 99 MB despite adding the safe directional masks. This reduces installed file size; decoded texture dimensions and GPU-memory requirements are unchanged.

## Native Jiberish settings and Ace3 compatibility fix

- Organize settings into JiberishIcons (Styles and icon integrations) and Jiberish Plus (Frames, Portraits and Crosshair), with shared Profiles and Help tabs. Preserve existing settings and dynamic custom-style editors.
- Brighten active-section gradients and apply them to nested tabs. Keep inactive labels white and disabled tabs gray. Preserve the two-part brand gradient on the ElvUI sidebar button, including while selected.

- Remove the separate rounded dashboard. `/ji` opens the Jiberish page in ElvUI's native options, or the standard Ace3 window without ElvUI. Retain compact section navigation, native tabs, borders, controls and the user's existing options font.
- Use short white sidebar labels, with a unique two-color gradient only on the selected section. Split the title into blue–purple JIBERISH and pink–orange FABLED ICONS; remove the stray color-reset text between them.
- Add 12 original settings glyphs with thicker rounded strokes. Do not use class/spec artwork as navigation icons.
- Fix repeated `JiberishIconsStudio.key: unknown parameter` errors by retiring the second renderer. ElvUI's runtime menu metadata stays in ElvUI; standalone options exclude that metadata without modifying the source or callbacks.
- Preserve all configuration sections, live portrait/crosshair movers, copy/reverse controls and profile import/export. Remove synthetic dashboard previews and pooled-widget recoloring.

## Individual layout copying and profile sharing

- Add Copy from, Reverse when copying and Reverse this layout to individual unit-frame theme pages. Copy theme, artwork, host icon settings and portraits with independent tables. Mirror sides, shapes, offsets, model facing and cast-label placement. Preserve the destination unit frame’s screen position; optionally copy ElvUI width/height.
- Support player, target, focus, pet, target of target and focus target. Add focus-target portraits and EllesmereUI portrait attachment. Keep party, raid, boss and arena outside individual layout copying.
- Add Profiles export/import using versioned, checksummed AceSerializer data. Capture the complete current JiberishIcons profile and custom-pack definitions; create a new named profile on import, validate input before mutation and preserve existing profiles/packs. Custom image files and native host-addon profiles are shared separately.
- Refresh host icon adapters and chat settings when activating a profile; defer protected host refreshes until combat ends.

## 3D portraits and Overwatch unit-frame theme

- Consolidate 3D character portraits into **Portraits**, with independent settings for player, target, focus and other supported units. Add Overwatch shield, circle, diamond and square frames, adjustable model fit, camera controls and border thickness. Retain left/right attachment and existing portrait placement controls.
- Lower shoulders into the inset V, extend the model viewport above the rear rim, and reduce the dark shelf beneath the bust. Preserve class/custom tinting and keep the lower accent inside the shield.
- Remove the separate Overwatch HUD, resource/cast dial and action-bar skins/docking. Migrate enabled HUD portraits into Portraits without replacing existing enabled portrait entries.
- Keep Overwatch in **Unit Frame Themes** for all supported ElvUI/EllesmereUI unit categories. Add 5/10/20 cells, rounded/angled shapes, six spacing levels, reversible slant and optional half-step outline widths/opacity. Retain native health values, text, sizing and Eltruism colors/gradients.
- Fit entire slanted cell rows and outlines inside native bars so end cells stay whole; smooth edges and tighten inter-cell gaps.
- Fix Classic beta GCD detection, fall back when duration objects are unavailable, and refresh after spellcasts. Add separate GCD X/Y offsets and a center-on-crosshair button.

## Bushido unit frames, crosshair and GCD indicator

- Add **Unit Frame Themes → ElvUI Unit Frames / EllesmereUI Unit Frames** with per-category Bushido styling: supplied metallic end-cap artwork, forward/backward slanted or clipped-corner silhouettes, optional power shaping and health divisions.
- Preserve the host's existing frames, health values, textures, colors, gradients, fonts, auras and positioning. ElvUI retains oUF; EllesmereUI retains its native engine. Theme options follow JiberishIcons profiles and Native restores the latest host border appearance.
- Keep absorbs, heal prediction and ElvUI cutaway textures within the health silhouette. Defer creation, layout and restoration until out of combat.
- Fix Eltruism compatibility: clip its extra background textures and backdrop gradients to the Bushido silhouette, replace its rectangular borders/shadows when requested, and catch later cosmetic setup. Preserve gradient colors and restore the latest host appearance when disabled.

- Add an optional movable crosshair under **/ji → Crosshair**, visible during combat or always. Choose solid/split cross or X styles, thin/bold lines, size, color and opacity.
- Add an optional circle, diamond, square or triangle outline that fills during the global cooldown. Configure outline size, weight, fill color and resting color independently.
- Preview placement and a looping GCD out of combat. Drag or enter screen offsets; entering combat locks the marker and restores live GCD timing. Locked markers are click-through and settings follow the selected profile.

# 1.6.2 — Ellesmere tooltip specs and Interface 120105 (October 13, 2026)

- Let EllesmereUI and other unit frames read available spec information from Blizzard tooltips on supported Retail/Mists clients without requiring ElvUI. Keep inspection as a fallback; Forever still uses talent inspection.
- Update TOC for 120105

# 1.6.1 — Blizzard damage meter icon sizing (October 10, 2026)

- Add **Custom Icon Size** under **/ji → Damage Meters → Blizzard Damage Meter**. Choose 12–64 pixels, up to the bar height set in Blizzard Edit Mode.
- Keep the chosen size when the meter skin refreshes, including the pinned player row. Turning the option off restores the original size.
- Shorten the README with quick setup instructions.

# 1.6.0 — Portraits and circle cast rings (October 8, 2026)

- Add independent movable portraits for player, target, target of target, pet, focus, each party member and boss. Choose Jiberish class/spec packs or 2D character portraits, with configurable fallback for pets, NPCs and unavailable specializations.
- Add optional Player/Target cast rings for Circle and Thin circle, sharing the portrait border's smooth size-specific textures. Configure separate cast/channel colors and opacity, font and independent name/time positions, or fill the circle with the current spell icon. Preview casts while portraits are unlocked.
- Include smooth circle and left/right droplet frames in regular and thin variants, with textures selected for the portrait's displayed size. Configure artwork sizing, mirroring, portrait zoom, border/background colors and screen or unit-frame anchoring.
- Add three Anything / Additional slots for freely chosen class, specialization or race icons, or a selected live unit. Choose no border for an unclipped icon anywhere on screen.
- Attach portraits to Blizzard, ElvUI or a named unit frame, or position them freely on screen. Unlock to drag and preview; locked portraits are click-through and movers lock in combat. Settings follow the existing profiles. Portraits and cast rings start disabled; configure them under **/ji → Portraits**.
- Show specialization icons sooner when ElvUI already has public tooltip information for a Retail/Mists player. Keep the existing inspection fallback and Classic/Forever talent-tree support.
- Refresh ElvUI specialization tags immediately on target/focus changes and incoming specialization data, including frames with portraits disabled, instead of waiting for a half-second poll.
- Special thanks to **Blinkii** for the portrait idea and continued help, and to **Repooc**, **Eltreum** and **Trenchy** for their ongoing contributions and support.

# 1.5.0 — Fabled Myth remaster (October 7, 2026)

- Redraw all 13 Fabled Myth class icons while preserving their original subjects and palettes, with broader shapes, stronger outlines and cleaner graffiti accents for small UI sizes.
- Increase the Myth atlas to 2048 × 2048 with 256px cells and eight-pixel transparent margins. Preserve its style ID and class mappings, including mirrored icons and chat/tag crops.
- Refine the original horn-hilt Demon Hunter sword, carved Shaman totem, geometric Priest staff, open-palm Warlock casting hand, Monk staff and fantasy Druid foliage.
- Replace the old Fabled Myth artwork automatically for existing selections. Other icon collections and saved settings remain unchanged.

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
