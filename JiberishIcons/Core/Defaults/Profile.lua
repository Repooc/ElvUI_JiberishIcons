local JI, L, P, G = unpack(JiberishIcons)
local elvuiUnitList = JI.dataHelper.elvuiUnitList
local sufUnitList = JI.dataHelper.sufUnitList

JI.dataHelper.portraitUnits = {
    {key = 'player', name = 'Player', x = -260, y = -160},
    {key = 'target', name = 'Target', x = 260, y = -160},
    {key = 'targettarget', name = 'Target of Target', x = 350, y = -160},
    {key = 'pet', name = 'Pet', x = -350, y = -160},
    {key = 'focus', name = 'Focus', x = 260, y = -60},
}
for i = 1, 4 do
    table.insert(JI.dataHelper.portraitUnits, {key = 'party'..i, name = 'Party '..i, group = 'party', x = -480, y = 200 - i * 90})
end
for i = 1, MAX_BOSS_FRAMES or 5 do
    table.insert(JI.dataHelper.portraitUnits, {key = 'boss'..i, name = 'Boss '..i, group = 'boss', x = 480, y = 250 - i * 90})
end
for i = 1, 3 do
    table.insert(JI.dataHelper.portraitUnits, {key = 'additional'..i, name = 'Additional '..i, group = 'additional', x = (i - 2) * 100, y = 100})
end
P.portraits = {}
for _, unit in ipairs(JI.dataHelper.portraitUnits) do
    P.portraits[unit.key] = {
        enable = false, mode = unit.group == 'additional' and 'static' or 'icon', style = 'fabledclass', fallback = 'portrait',
        sourceUnit = 'player', iconID = 'PALADIN', specID = 65, raceID = 'HUMAN',
        shape = 'circle', size = 80, iconScale = 0.78, reverse = false,
        zoom = 0.12, contentX = 0, contentY = 0,
        anchor = 'screen', frameName = '', point = 'CENTER', relativePoint = 'CENTER',
        x = unit.x, y = unit.y, strata = 'MEDIUM', level = 10,
        borderColor = {1, 1, 1, 1}, classColor = false,
        backgroundColor = {0.035, 0.045, 0.06, 1},
        cast = {
            enable = false, spellIcon = false, showName = true, showTime = true,
            font = '__default', fontSize = 12, outline = 'OUTLINE',
            namePoint = 'BOTTOM', nameX = 0, nameY = -16, textWidth = 180,
            timePoint = 'CENTER', timeX = 0, timeY = 0,
            color = {1, 0.7, 0.15, 1}, channelColor = {0.2, 0.75, 1, 1},
            textColor = {1, 1, 1, 1},
        },
    }
end

P.blizzard = {
    player = sharedDefaultValues,
    target = sharedDefaultValues,
    targettarget = sharedDefaultValues,
    focus = sharedDefaultValues,
    focustarget = sharedDefaultValues,
    party = sharedDefaultValues,
    -- raid = {
    -- 	icon = sharedDefaultValues.icon,
    -- },
}


P.chat = {
    enable = false,
    style = 'fabled',
    reverse = false,
}

P.elvui = {}
P.suf = {}
P.ellesmereui = {}

P.damageMeters = {
    blizzard = { enable = false, style = 'fabledspecializations', reverse = false },
    ellesmere = { enable = false, style = 'fabledspecializations', reverse = false },
}

for _, unit in ipairs(JI.dataHelper.ellesmereSettingList) do
    P.ellesmereui[unit] = {
        icon = {
            enable = false,
            style = 'fabled',
            reverse = false,
            size = 32,
            anchorPoint = 'RIGHT',
            xOffset = 0,
            yOffset = 0,
        },
    }
end

for unit in pairs(elvuiUnitList) do
    P.elvui[unit] = {
        portrait = {
            enable = false,
            style = 'fabled',
            reverse = false,
            backdrop = {
                enable = false,
                colorOverride = false,
                color = { 0, 0, 0, 0.5 },
                transparent = false,
            },
        },
    }
end

for _, unit in pairs(sufUnitList) do
    P.suf[unit] = {
        portrait = {
            enable = false,
            style = 'fabled',
            reverse = false,
        },
        icon = {
            enable = false,
            style = 'fabled',
            reverse = false,
            size = 32,
            anchorPoint = 'RIGHT',
            xOffset = 0,
            yOffset = 0,
        },
    }
end
