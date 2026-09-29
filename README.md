# Jiberish Icons
Welcome! JiberishUI Icons adds custom class and race icon packs for your unit frames and chat.

Visit [The Igloo](https://theigloo.io/) for JiberishUI.

You can access this addon in game with the command /ji or /jiberishicons

The current candidate includes WoW Forever beta compatibility for client 1.60.1 / Interface 16001, alongside the existing Retail and Classic compatibility entries. See [candidate testing notes](RELEASE-CANDIDATE.md) for verified checks and remaining in-game acceptance.

Check the screenshots for how to use the addon and get some inspiration for your setup!

ElvUI Users: The addon pack adds tags in ElvUI > Available Tags > Jiberish that you can copy/paste into a Custom Text Field in ElvUI > Unit Frames. Adjust the tag size with, for example, `[jiberish:class:fabledrealm{32}]` or `[jiberish:class:fabled{32}]`.

**Fabled Regalia** adds all 13 class emblems. **Fabled Azeroth** adds all 26 race emblems, including Earthen and Haranir; races available to both factions share an emblem. Both use 256 × 256 icon cells on transparent 2048 × 2048 texture sheets, rebuilt from the original high-resolution artwork. Their on-screen size and cell layout match Fabled Realm, with twice the source resolution in each dimension for clearer large icons. These are reinterpretations of Blizzard Entertainment's World of Warcraft class and race crests, referenced from Blizzard's official [class](https://worldofwarcraft.blizzard.com/en-us/game/classes) and [race](https://worldofwarcraft.blizzard.com/en-us/game/races) pages, with the painted materials and depth of Frostforge.

**Fabled Core** now also uses 256px cells on a transparent 2048px sheet. Its existing artwork is carefully resampled and lightly sharpened from the original 128px cells, preserving its design and placement. This improves scaling without adding new detail. All other older packs retain their original texture files and resolutions. See the [Core comparison](artwork/fabledcore/comparison.png) and [export notes](artwork/fabledcore/README.md).

After installing new texture files, fully exit and restart WoW. Open `/ji` and choose **Fabled Regalia** or **Fabled Azeroth (Race)** in the supported icon/portrait or Chat style selector. Race portraits use the class portrait mode in ElvUI or Shadowed Unit Frames. EllesmereUI supports the independent icon. ElvUI tags are `[jiberish:class:fabledregalia{32}]` and `[jiberish:race:fabledazeroth{32}]`; append `:reverse` before `{32}` to mirror them. Race icons hide when race information is unavailable. Details! and Eltruism class-icon integrations offer Fabled Regalia.

See the [Fabled Regalia preview](images/FabledRegaliaWebsiteDisplay.png), [Fabled Azeroth preview](images/FabledAzerothWebsiteDisplay.png), and [artwork source notes](artwork/fabled/README.md).

General Users: This supports changing the icons in Details! as well! Details Options -> Bars: General -> Icons -> Texture dropdown

EllesmereUI Users (9.1.8): Open `/ji` → **EllesmereUI**, select Player, Target, Focus, Target of Target, or Focus Target, and enable the icon. Choose a style, size, anchor point, and X/Y offsets to place it around that unit frame. **Apply To All** copies that frame's complete icon settings to the other four frames. All icons start disabled.

These are independent icons: EllesmereUI's portraits and embedded artwork are unchanged, and its portrait settings do not need adjusting. The EllesmereUI Unit Frames module and the chosen unit frame must be active. Icons follow frame visibility/fading and hide for NPCs, pets, or unavailable class information. Creation, size, and position changes wait until combat ends. Party/raid frames and other EllesmereUI icon locations are not included.

**Reverse icons:** Enable **Reverse** beside the style selector to mirror the artwork horizontally. For a symmetrical layout, leave Player normal and enable Reverse on Target. This option is available for EllesmereUI icons, Blizzard icons/portraits, ElvUI portraits, Shadowed Unit Frames icons/portraits, and Chat icons. Every setting defaults to off and is saved in your JiberishIcons profile. Blizzard, ElvUI and SUF offer Normal/Reverse with Apply To All under General; EllesmereUI's Apply To All includes the reverse setting. Chat reversal applies to new messages. ElvUI custom text tags retain their existing reverse form, for example `[jiberish:class:fabled:reverse{32}]`.

For local development, testing, and the contribution/release process, see [DEVELOPMENT.md](DEVELOPMENT.md).

Please join the discord if you have any questions/concerns: https://discord.gg/mJKdmm9KGr
