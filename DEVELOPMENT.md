# Local development and releases

## Checkout and contribution

`origin` is your fork (`jiberishxd/ElvUI_JiberishIcons`); `upstream` is
`Repooc/ElvUI_JiberishIcons`. Start feature branches from current `upstream/main`
and push them to your fork. Open pull requests against Repooc's `main` branch.
The EllesmereUI feature branch is `codex/ellesmereui-support`.

The official branch-push workflow publishes alpha builds to CurseForge and Wago.
Its name, **Push Commits to Discord Webhook**, does not describe its packaging
behavior. Tagged releases use the separate **Release** workflow. Merging a PR
does not itself publish a stable release. Leave publishing credentials on the
upstream repository and coordinate version/tag selection with its maintainers.

## Linked WoW installation

On this development machine, the Retail AddOns entry
`/Applications/World of Warcraft/_retail_/Interface/AddOns/ElvUI_JiberishIcons`
links to the **inner addon folder** in this checkout, not the repository root.
The original installed folder and copies of existing `ElvUI_JiberishIcons.lua`
and `.lua.bak` saved-variable files are backed up outside AddOns. Those files
contain the `JiberishIconsDB` table.

- Keep **JiberishUI Icons** set to **Ignore** in WowUp while the link is active.
  Do not reinstall or manually update it through an addon manager: that could
  replace the link or write into the checkout.
- Use `/reload` for edits to existing Lua files. Fully restart WoW after adding
  files, changing the TOC/load list, or first installing this integration.
- Switching branches also switches the addon code WoW loads on its next reload.
- Saved settings remain in WoW's WTF directory; they are not stored in Git.
- The initial settings backup reflects the last disk save. WoW may have newer
  in-memory settings if it was running when the backup was taken.

To restore the previous installation, exit WoW, verify that the AddOns entry is
still a symlink to this checkout, remove **only that symlink**, and move the
backed-up addon folder into its place. Restore saved settings only if wanted,
while WoW is closed. Turn off WowUp's Ignore setting after restoring a normal
installed copy. Do not delete or move the checkout to remove the link.

## Automated checks

Run from the repository root with Lua 5.1:

```sh
lua5.1 tests/ellesmereui.lua
git diff --check
```

The test suite loads the actual addon initialization, options, defaults,
AceDB callbacks, and EllesmereUI adapter against mocked WoW frames. It exercises
readiness, repeated setup, unit identity, combat deferral, inherited visibility,
custom styles, profile changes, Apply to All, and replacement frames. It does
not simulate WoW's secure execution or GPU rendering.

Syntax-check Lua files with `luac -p`; strip a leading UTF-8 BOM in memory when
checking unchanged vendored libraries, since WoW accepts it but stock Lua 5.1
does not. Development documentation and tests are excluded from addon packages.

## In-game acceptance checklist (EllesmereUI 9.1.8)

- Restart WoW, open `/ji` → EllesmereUI, and verify all five icons start disabled
  on a new profile. Existing profiles/settings for other integrations must remain.
- Enable and position icons on Player, Target, Focus, Target of Target, and Focus
  Target. Check every anchor, size and offset, and Apply to All.
- Check stock and custom artwork, including editing/deleting a selected custom
  pack. Missing styles should display Fabled.
- Switch targets between player classes, NPCs, pets and no target. Check focus,
  target-of-target, focus-target and vehicle transitions. Restricted identity
  should hide the icon rather than reuse the previous unit's class.
- Move and hide EllesmereUI frames; check mouseover visibility and out-of-combat
  fading. Icons must inherit visibility and must not intercept clicks.
- Check with EllesmereUI portraits enabled and disabled. Portraits, native
  text-bar icons, and EllesmereUI saved settings must remain unchanged.
- Enter combat: existing icons must follow class changes; position/size/new
  icon creation must wait until combat ends. Check for Lua errors and taint.
- Switch, copy and reset Jiberish profiles; switch EllesmereUI profiles; zone
  and reload. Disable icons and confirm only Jiberish-owned artwork disappears.
- With EllesmereUI disabled, smoke-test Blizzard, ElvUI, SUF and Details where
  installed. Confirm absent integrations do not cause Lua errors.

Record completed checks in the pull request. Automated test success does not
establish that the in-game checklist has passed.
