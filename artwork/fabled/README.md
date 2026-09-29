# Fabled Regalia and Fabled Azeroth

Fabled Regalia contains 13 class emblems. Fabled Azeroth contains 26 distinct playable-race emblems, including Earthen and Haranir. Pandaren, Dracthyr, Earthen and Haranir faction pages use one icon per race.

The references are Blizzard's [class pages](https://worldofwarcraft.blizzard.com/en-us/game/classes) and [race pages](https://worldofwarcraft.blizzard.com/en-us/game/races). Each detail page was inspected. `references/blizzard-sources.json` records the individual page and emblem image URLs. The original emblem contact sheets are saved alongside it.

Frostforge portraits and action hubs were read-only visual references. Their carved shapes, worn materials, deep recesses and vivid accents guided the new illustrations; their portrait frames were not reused. No Frostforge files were modified.

Artwork was created with the built-in image generation tool. `originals/` preserves every generated PNG and a JSON record of its full prompt and generation output path. These are working masters: some contain opaque backgrounds and must pass transparency cleanup before export.

All 39 cleaned masters are in `transparent/`. Thirteen retain their original alpha; 26 were cleaned locally with macOS Vision and connected background removal, as authorized by the user. `cleanup-report.json` records the method for each image. `tools/foreground-fabled.swift` and `tools/clean-fabled.cjs` reproduce this step on macOS; original colors are preserved where alpha survives.

The export tool `tools/build-fabled.cjs` (from the repository root) requires Node.js and Sharp. It reads the images from `transparent/`, verifies real alpha, trims the visible bounds, and fits each emblem inside a 248 × 248 area centered in a 256 × 256 cell. This leaves a four-pixel safety margin, equivalent to the previous two-pixel margin at 128px display size. It writes individual PNGs, 2048 × 2048 PNG and 32-bit TGA sheets, labeled previews, and a manifest of coordinates and hashes.

Regalia follows the existing Fabled Realm class-cell layout. Azeroth uses eight columns in the order of `JI.dataHelper.raceOrder` in `Core/API.lua`. The game texture files are `Media/Class/fabledregalia.tga` and `Media/Race/fabledazeroth.tga` inside the addon directory. Unused cells are transparent. The `.pkgmeta` excludes working artwork and tools from release packages.

Registration and rendering are exercised by `tests/ellesmereui.lua`. Final visual behavior in the WoW client still requires an in-game check after restarting the client.

The rc.3 export doubles each icon dimension from the cleaned original masters using Lanczos downsampling. It does not enlarge the earlier 128px output or invent detail. Frostforge's portrait sheets were inspected read-only: each 512 × 256 sheet contains two 256px portrait cells. The new icon sheets retain eight columns and normalized UV coordinates; markup reads each style's declared texture size. The two uncompressed 2048px RGBA sheets use 16 MiB each before runtime overhead. These exports remain unchanged in rc.4; only the older Fabled Core sheet receives a separate resampling pass, documented in `artwork/fabledcore/README.md`. No global graphics/filtering settings are changed.

The addon credits JiberishUI at https://theigloo.io/ and describes these packs as reinterpretations of Blizzard Entertainment's World of Warcraft class and race crests, referenced from Blizzard's official website. The working masters and generation records remain here for provenance and reproducibility.
