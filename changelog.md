v1.5.0-rc.4 9/29/26 — local testing candidate

• [Update] Improve Fabled Core's existing artwork with alpha-aware resampling and light sharpening at 256 pixels per icon on a 2048 × 2048 power-of-two sheet. Preserve its design, placement and on-screen size; use lossless TGA compression.
• [Update] Keep every other texture unchanged from rc.3, including the original eight older sets and the higher-resolution Fabled Regalia and Fabled Azeroth exports.
• [Update] Describe Fabled Regalia and Fabled Azeroth as reinterpretations of Blizzard Entertainment's World of Warcraft class and race crests, with links to the official reference pages.
• [Update] Point JiberishUI's artist website links to https://theigloo.io/.

v1.5.0-rc.3 9/29/26 — local testing candidate

• [Update] Rebuild Fabled Regalia and Fabled Azeroth from their original artwork at 256 pixels per icon on 2048 × 2048 power-of-two texture sheets, improving clarity at large and high-DPI display sizes.
• [Update] Preserve the existing icon sizes, atlas layout, transparent margins and smooth rendering. Older packs remain at their original resolutions.
• [Fix] Use per-pack texture dimensions for Chat, ElvUI tags and previews, including normal/reversed crops and missing-pack fallback.

v1.5.0-rc.2 9/29/26 — local testing candidate

• [Fix] Update AceGUI's checkbox widget to upstream version 27, replacing the missing SetDesaturation helper that prevented settings panels from opening.
• [Update] Declare WoW Forever beta compatibility (Interface 16001; local build 1.60.1.70009).
• [Fix] Only access optional integrations after they have loaded on all clients, including Forever beta.

v1.5.0-rc.1 9/29/26 — local testing candidate

• [Feature] Add Fabled Regalia: 13 class emblems inspired by Blizzard's official class symbols and Frostforge's painted fantasy art.
• [Feature] Add Fabled Azeroth: 26 race emblems, including Earthen and Haranir, with race selection in Blizzard, ElvUI, Shadowed Unit Frames, EllesmereUI and Chat.
• [Feature] Add normal and reversed ElvUI race tags and a Race Styles preview tab. Fabled Regalia is also available to existing class-only integrations.
• [Update] Match Fabled Realm's 128 × 128 icon cells and 1024 × 1024 transparent texture sheets.
• [Fix] Keep icon and portrait style selections independent on Blizzard frames, and repair their portrait Apply To All controls.
• [Fix] Hide unavailable race identities and keep texture/coordinate fallback consistent when a selected pack is missing.

In-game acceptance is pending. This candidate has not been published as a stable release.

v1.4.6 9/15/26

• [Feature] Add per-frame Reverse options to mirror class artwork horizontally in EllesmereUI, Blizzard, ElvUI and SUF settings, plus Chat icons. Includes bulk Normal/Reverse controls and preserves existing ElvUI reverse tags.
• [Feature] Add movable class icons for EllesmereUI player, target, focus, target-of-target and focus-target frames. Configure each icon through /ji without changing EllesmereUI portraits.
• [Update] TOC compatibility for Retail, Mists of Pandaria, Wrath, The Burning Crusade and Classic Era in one addon package.
• [Fix] Keep options and chat icons compatible with clients without Retail-only APIs, and display the full addon version in settings.
