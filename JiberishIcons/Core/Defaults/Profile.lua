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

-- Nameplate nav tape. Sizes are physical pixels; colors {r, g, b, a} are used
-- when colors = 'custom' ('host' follows ElvUI/EllesmereUI, 'class' tints the
-- lens and marker with your class color).
P.navTape = {
    enable = false, show = 'target', position = 'above', xOffset = 0, yOffset = 14, inset = 2, level = 10,
    preset = 'elvui', font = 'host', reduceMotion = false,
    yards = true, yardsStyle = 'bracket', yardsPosition = 'above', yardsSize = 10, yardsSuffix = true,
    yardsOutline = true, meleeLamp = true,
    bearing = true, facing = true, lens = true, tape = true,
    tickStyle = 'lines', ticks = 24, tickMinor = 3, tickMajor = 6, tickWeight = 1, majorEvery = 5, lensLift = 4,
    edgeFade = true, tapeWidth = 100, background = 'backdrop', backdropAlpha = 0.6, markerStyle = 'caret', markerSize = 3,
    colors = 'host',
    tickColor = {0.55, 0.57, 0.6, 1}, majorColor = {0.96, 0.96, 0.96, 1}, lensColor = {0.09, 0.51, 0.82, 1},
    markerColor = {0.09, 0.51, 0.82, 1}, alertColor = {1, 0.24, 0.2, 1}, yardsColor = {0.96, 0.96, 0.96, 1},
    meleeColor = {1, 0.24, 0.2, 1}, baseColor = {0.55, 0.57, 0.6, 1},
}

-- Aura timeline: your buffs and ability cooldowns sliding toward zero along a
-- line; only what has less time left than the line's length shows.
P.auraTimeline = {
    enable = false, preset = 'elvui', reduceMotion = false,
    buffs = 'mine', debuffs = false, cooldowns = true, longBuffs = 0, minCooldown = 5, maxEntries = 12, blacklist = '',
    maxTime = 60, length = 260, orientation = 'horizontal', reverse = false, scale = 1, strata = 'MEDIUM',
    x = 0, y = 260,
    lineStyle = 'solid', lineWeight = 1, lineShadow = true, zeroCap = 'dot', farCap = true,
    ticks = true, labels = true, labelSize = 9, font = 'host',
    lanes = 3, stack = 'up', spacing = 3, stems = true,
    iconSize = 26, keyStyle = 'square', borderWeight = 1, kindBorders = true, timeStyle = 'text', timeSize = 11, counts = true,
    colors = 'host',
    lineColor = {0.96, 0.96, 0.96, 0.85}, tickColor = {0.55, 0.57, 0.6, 0.8}, labelColor = {0.55, 0.57, 0.6, 1},
    accentColor = {0.09, 0.51, 0.82, 1}, borderColor = {0, 0, 0, 1}, harmColor = {1, 0.24, 0.2, 1},
    cooldownColor = {0.09, 0.51, 0.82, 1}, textColor = {0.96, 0.96, 0.96, 1}, chipColor = {0.06, 0.06, 0.07, 0.85},
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
