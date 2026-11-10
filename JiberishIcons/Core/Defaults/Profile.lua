local JI, L, P, G = unpack(JiberishIcons)
local elvuiUnitList = JI.dataHelper.elvuiUnitList
local sufUnitList = JI.dataHelper.sufUnitList

JI.dataHelper.themeUnits = {
    {key = 'player', name = 'Player'}, {key = 'target', name = 'Target'},
    {key = 'focus', name = 'Focus'}, {key = 'pet', name = 'Pet'},
    {key = 'targettarget', name = 'Target of target'}, {key = 'focustarget', name = 'Focus target'},
    {key = 'party', name = 'Party'}, {key = 'raid', name = 'Raid'},
    {key = 'boss', name = 'Boss'}, {key = 'arena', name = 'Arena', elvuiOnly = true},
}
P.unitFrameThemes = {elvui = {}, ellesmereui = {}}
for _, host in ipairs({'elvui', 'ellesmereui'}) do
    for _, unit in ipairs(JI.dataHelper.themeUnits) do
        P.unitFrameThemes[host][unit.key] = {
            theme = 'native', shape = 'diagonal', shapePower = false, replaceBorder = true,
            borderColor = {0.32, 0.35, 0.4, 1},
            segments = 20, reverseSegments = false, segmentGap = 'normal', segmentStyle = 'angled', segmentSpacing = 0, segmentBorderWidth = 1, segmentBorderOpacity = .6, segmentOutline = false, divisions = 0, divisionWidth = 1, divisionColor = {0.02, 0.025, 0.03, 0.85},
            cap = {
                enable = true, side = unit.key == 'target' and 'LEFT' or 'RIGHT',
                mirror = false, scale = 2.2, width = 1, x = 0, y = 0,
                colorMode = 'class', color = {0.65, 0.7, 0.8, 1},
            },
        }
    end
end

P.crosshair = {
    enable = false, visibility = 'combat',
    style = 'plus', weight = 'thin', size = 32, color = {0, 0.85, 1, 1},
    x = 0, y = -80, strata = 'HIGH',
    gcd = {
        enable = false, shape = 'diamond', weight = 'bold', size = 64, x = 0, y = 0,
        color = {1, 0.1, 0.65, 1}, trackColor = {0.08, 0.08, 0.08, 0.65},
    },
}

JI.dataHelper.portraitUnits = {
    {key = 'player', name = 'Player', x = -260, y = -160},
    {key = 'target', name = 'Target', x = 260, y = -160},
    {key = 'targettarget', name = 'Target of Target', x = 350, y = -160},
    {key = 'pet', name = 'Pet', x = -350, y = -160},
    {key = 'focus', name = 'Focus', x = 260, y = -60},
    {key = 'focustarget', name = 'Focus target', x = 350, y = -60},
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
        model = {width = 94, height = 160, x = 0, y = 8, zoom = .9, facing = .25,
            distance = .85, viewX = 0, viewY = 0, rim = 3},
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
    blizzard = { enable = false, style = 'fabledspecializations', reverse = false, customIconSize = false, iconSize = 32 },
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
