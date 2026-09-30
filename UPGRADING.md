# Upgrade to JiberishIcons

The visible name is **Jiberish Fabled Icons**. The install folder and TOC are now
`JiberishIcons/JiberishIcons.toc`. Do not install both folder names together.

## Existing profiles

Fully quit World of Warcraft before changing addon folders or saved settings.
Back up your current addon folder and the client's `WTF` folder first.

1. In each account's `WTF/Account/<account>/SavedVariables` directory, copy
   `ElvUI_JiberishIcons.lua` to `JiberishIcons.lua`. Copy the `.lua.bak` file to
   `JiberishIcons.lua.bak` as well if it exists. Leave the original files intact.
   Do not replace an existing `JiberishIcons.lua` containing newer settings.
2. Move the old `ElvUI_JiberishIcons` addon folder outside `Interface/AddOns`.
   Keep it as a backup. Copy any personal files from its `Media/Custom` folder
   into the corresponding new folder if you stored custom art there.
3. Extract the supplied `JiberishIcons` folder into `Interface/AddOns`.
4. Start WoW, enable **Jiberish Fabled Icons**, open `/ji`, and check your profile.

The saved table remains `JiberishIconsDB`, so its contents should not be renamed
or edited. A filename copy is required because the addon folder name changed.
Existing profile selections and style IDs are preserved. Custom style paths
inside the old addon directory are updated when the profile loads; paths to
separate custom-art addons remain unchanged.

For repository users, `tools/migrate-settings.py` previews the filename copies:

```sh
python3 tools/migrate-settings.py "/path/to/World of Warcraft/_retail_/WTF"
python3 tools/migrate-settings.py "/path/to/World of Warcraft/_retail_/WTF" --apply
```

The tool retains originals, refuses conflicting destination files, and requires
WoW to be closed before copying. Run it separately for other WoW clients.
No migration or installation is performed by the release packager.

## ElvUI tags

Add these under **ElvUI → Unit Frames → Custom Texts**. The size is optional
(default 64, supported range 1–128). All tags appear under **Available Tags →
Jiberish Fabled Icons**.

| Icon set | Normal | Mirrored |
| --- | --- | --- |
| Specializations | `[jiberish:spec:fabledspecializations{32}]` | `[jiberish:spec:fabledspecializations:reverse{32}]` |
| Regalia classes | `[jiberish:class:fabledregalia{32}]` | `[jiberish:class:fabledregalia:reverse{32}]` |
| Azeroth races | `[jiberish:race:fabledazeroth{32}]` | `[jiberish:race:fabledazeroth:reverse{32}]` |

Class and race tags for the other existing style names continue to work.
Specialization tags use available public information and hide when a unit's
specialization is unknown or restricted. Unsupported clients can use class and
race icons instead.

On Classic/Forever, your own spec icon follows the talent tree with the most
spent points. Unspent builds and tied splits display the Regalia class crest.
Talent-point and active-talent-group changes refresh the icon automatically.
Forever uses its current combat configuration's trait-group totals. Missing
unspent group entries count as zero; uncommitted previews retain the last known
committed icon until the changes are applied.
