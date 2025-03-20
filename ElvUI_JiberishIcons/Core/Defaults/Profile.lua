local JI, L, P, G = unpack(ElvUI_JiberishIcons)
local elvuiUnitList = JI.dataHelper.elvuiUnitList
local sufUnitList = JI.dataHelper.sufUnitList

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
}

P.elvui = {}
P.suf = {}

for unit in pairs(elvuiUnitList) do
    P.elvui[unit] = {
        portrait = {
            enable = false,
            style = 'fabled',
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
        },
        icon = {
            enable = false,
            style = 'fabled',
            size = 32,
            anchorPoint = 'RIGHT',
            xOffset = 0,
            yOffset = 0,
        },
    }
end
