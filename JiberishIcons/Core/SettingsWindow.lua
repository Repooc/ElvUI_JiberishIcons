-- Keep settings in the host's native options renderer. ElvUI decorates its option
-- tables with runtime fields (notably `key`); those must never enter stock Ace3.
local JI = unpack(JiberishIcons)
local ACH = JI.Libs.ACH
local standalone = LibStub('AceConfigDialog-3.0')
local brandBlue = {.42, .76, 1, .76, .60, 1}
local brandPink = {1, .48, .76, 1, .72, .39}
local sectionNames = {
    StylePacks = {'Styles', 'styles', 1, {.52, .65, 1, .83, .52, 1}},
    unitFrameThemes = {'Frames', 'frames', 2, {.28, .85, 1, .40, .55, 1}},
    portraits = {'Portraits', 'portrait', 3, {.77, .52, 1, 1, .49, .74}},
    crosshair = {'Crosshair', 'crosshair', 4, {.30, .94, .77, .35, .70, 1}},
    elvui = {'ElvUI', 'elvui', 10, {.47, .81, 1, .57, .57, 1}},
    ellesmereui = {'Ellesmere', 'ellesmere', 11, {.39, .90, .85, .66, .85, .43}},
    blizzard = {'Blizzard', 'blizzard', 12, {.71, .91, 1, .37, .63, 1}},
    suf = {'SUF', 'suf', 13, {.71, .65, 1, .48, .85, .89}},
    damageMeters = {'Meters', 'meters', 20, {1, .73, .35, 1, .43, .53}},
    chat = {'Chat', 'chat', 21, {.48, .90, .55, .33, .86, .83}},
    profiles = {'Profiles', 'profiles', 90, {1, .52, .75, 1, .73, .40}},
    Information = {'Help', 'help', 100, {1, .84, .46, .83, .64, 1}},
}
local sectionParents = {unitFrameThemes='plus', portraits='plus', crosshair='plus'}
for key, data in pairs(sectionNames) do
    if key ~= 'profiles' and key ~= 'Information' and not sectionParents[key] then sectionParents[key] = 'icons' end
    for i, color in ipairs(data[4]) do data[4][i] = color + (1 - color) * .12 end
end
local categoryColors = {icons=brandPink, plus=brandBlue}
local function Plain(text)
    -- Return only the title, not gsub's count (which AceConfig would treat as a parent).
    return (text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''))
end
function JI:SettingsGradient(text, colors)
    text = Plain(text)
    colors = colors or brandBlue
    local result, characters = {}, {}
    for character in text:gmatch('[%z\1-\127\194-\244][\128-\191]*') do characters[#characters + 1] = character end
    local length = #characters
    for i = 1, length do
        local t = length > 1 and (i - 1) / (length - 1) or 0
        result[i] = self:RGBToHex(colors[1] + (colors[4] - colors[1]) * t,
            colors[2] + (colors[5] - colors[2]) * t, colors[3] + (colors[6] - colors[3]) * t,
            nil, characters[i]..'|r')
    end
    return table.concat(result)
end

function JI:SettingsBrand(uppercase)
    return self:SettingsGradient(uppercase and 'JIBERISH' or 'Jiberish', brandBlue)
        ..(uppercase and '   ' or ' ')
        ..self:SettingsGradient(uppercase and 'FABLED ICONS' or 'Fabled Icons', brandPink)
end
function JI:HookElvUISettingsBrand()
    local E = _G.ElvUI and _G.ElvUI[1]
    if self.settingsBrandHook or not E or not E.Config_SetButtonText then return end
    self.settingsBrandHook = true
    -- ElvUI deliberately removes inline colors on its selected left button.
    -- Restore only our branded label after that update, leaving host skins alone.
    hooksecurefunc(E, 'Config_SetButtonText', function(_, button)
        if button.info and button.info.key == 'jiberishicons' then button:SetText(JI:SettingsBrand()) end
    end)
end

-- AceGUI widgets are pooled. Resolve ownership from current userdata on every
-- refresh so a reused widget cannot carry our colors into another addon.
local function SettingsPath(widget)
    if not widget or not widget.GetUserDataTable then return end
    local user = widget:GetUserDataTable()
    if not user.path then return end
    if user.appName == 'ElvUI' and user.path[1] == 'jiberishicons' then return user.path, 2 end
    if user.appName == JI.AddOnName then return user.path, 1 end
end
local function IsSectionTree(tree)
    local path, start = SettingsPath(tree)
    return tree and tree.type == 'TreeGroup' and path and #path == start and categoryColors[path[start]]
end
local function TabColors(path, start, value)
    -- The first section in the path owns its nested unit/style tabs. For
    -- example, Frames > ElvUI uses Frames colors, not the ElvUI icon palette.
    for i = start, #path do
        local section = sectionNames[path[i]]
        if section then return section[4] end
    end
    return (sectionNames[value] and sectionNames[value][4]) or categoryColors[value] or brandBlue
end
function JI:UpdateSettingsSelection(widget)
    local path, start = SettingsPath(widget)
    if not path then return end
    local status = widget.status or widget.localstatus or {}
    if IsSectionTree(widget) then
        for _, button in pairs(widget.buttons or {}) do
            local data = sectionNames[button.uniquevalue]
            if data and button.text then
                button.text:SetText(status.selected == button.uniquevalue
                    and self:SettingsGradient(data[1], data[4]) or '|cffffffff'..data[1]..'|r')
            end
        end
    elseif widget.type == 'TabGroup' then
        for i, entry in ipairs(widget.tablist or {}) do
            local button = widget.tabs and widget.tabs[i]
            local label = button and button:GetFontString()
            if label and type(entry.text) == 'string' then
                local text = Plain(entry.text)
                label:SetText(entry.disabled and '|cff90949c'..text..'|r'
                    or (status.selected == entry.value and self:SettingsGradient(text, TabColors(path, start, entry.value)))
                    or '|cffffffff'..text..'|r')
            end
        end
    end
end
function JI:HookSettingsSelection(dialog)
    self.settingsDialogs = self.settingsDialogs or {}
    if self.settingsDialogs[dialog] or not dialog.FeedGroup then return end
    self.settingsDialogs[dialog] = true
    hooksecurefunc(dialog, 'FeedGroup', function(_, _, _, container)
        if not SettingsPath(container) then return end
        if container.type == 'TreeGroup' and IsSectionTree(container) then
            if not container.jiberishSelectionHook then
                container.jiberishSelectionHook = true
                hooksecurefunc(container, 'RefreshTree', function(widget) JI:UpdateSettingsSelection(widget) end)
            end
        elseif container.type == 'TabGroup' then
            if not container.jiberishTabHook then
                container.jiberishTabHook = true
                hooksecurefunc(container, 'BuildTabs', function(widget) JI:UpdateSettingsSelection(widget) end)
                hooksecurefunc(container, 'SelectTab', function(widget) JI:UpdateSettingsSelection(widget) end)
            end
        else return end
        JI:UpdateSettingsSelection(container)
    end)
end

-- Only copy option nodes, not handler objects or values tables. Preserve the
-- original getter/setter paths; metadata keys inside actual values stay intact.
function JI:BuildStandaloneOptions(source)
    source = source or self.SettingsOptions or self.Options
    local copy = {}
    for key, value in pairs(source) do
        if key == 'args' then
            copy.args = {}
            for id, option in pairs(value) do copy.args[id] = self:BuildStandaloneOptions(option) end
        elseif key ~= 'key' and not ((source == self.Options or source == self.SettingsOptions) and key == 'func') then
            copy[key] = value
        end
    end
    return copy
end

function JI:StyleNativeOptions()
    local options = self.Options
    options.childGroups = 'tab'
    options.name = self:SettingsBrand()
    options.args.openStudio = nil
    local title = self:SettingsBrand(true)
    options.args.logo = ACH:Description(title, 0, 'large', nil, nil, nil, nil, 'full')
    options.args.version = ACH:Description(function()
        return 'Version '..self.Version..'   |   Profile: |cffd8dce8'..self.data:GetCurrentProfile()..'|r'
    end, .1, 'small', nil, nil, nil, nil, 'full')
    options.args.settingsHint = ACH:Description('JiberishIcons: icon packs and integrations. Jiberish Plus: frame themes, 3D portraits and crosshair.', .2, 'small')
    for key, data in pairs(sectionNames) do
        local group = options.args[key]
        if group then
            group.name = '|cffffffff'..data[1]..'|r'
            group.icon = self.MediaPath..'Settings\\'..data[2]..'.tga'
            group.order = data[3]
            -- A compact section list, with units/pages as native tabs on the
            -- right, like Eltruism. Existing nested host trees remain intact.
            group.childGroups = 'tab'
        end
    end
    -- Presentation wrappers reference the original nodes. Dynamic style editors
    -- keep their source references, and getters still index from the path's end.
    local display = self.SettingsOptions or {type='group', args={}}
    self.SettingsOptions = display
    display.name, display.order, display.childGroups = options.name, options.order, 'tab'
    display.args = {
        logo=options.args.logo, version=options.args.version, settingsHint=options.args.settingsHint,
        icons={type='group', name='|cffffffffJiberishIcons|r', order=1, childGroups='tree', args={}},
        plus={type='group', name='|cffffffffJiberish Plus|r', order=2, childGroups='tree', args={}},
        profiles=options.args.profiles, Information=options.args.Information,
    }
    for key, parent in pairs(sectionParents) do display.args[parent].args[key] = options.args[key] end
end

function JI:ToggleSettingsWindow()
    if InCombatLockdown() then return end
    if self:IsAddOnEnabled('ElvUI') then
        -- Let ElvUI load its options, select the plugin and own every widget.
        _G.ElvUI[1]:ToggleOptions('jiberishicons')
    else
        local frame = standalone.OpenFrames and standalone.OpenFrames[self.AddOnName]
        if frame then standalone:Close(self.AddOnName)
        else standalone:Open(self.AddOnName) end
    end
end
function JI:SelectSettingsGroup(...)
    local path = {...}
    local parent = sectionParents[path[1]]
    if parent then table.insert(path, 1, parent) end
    if self:IsAddOnEnabled('ElvUI') then
        self.Libs.ACD:SelectGroup('ElvUI', 'jiberishicons', unpack(path))
    else standalone:SelectGroup(self.AddOnName, unpack(path)) end
end
function JI:QueueSettingsRefresh()
    if self.nativeRefreshPending then return end
    self.nativeRefreshPending = true
    C_Timer.After(0, function()
        self.nativeRefreshPending = nil
        if self:IsAddOnEnabled('ElvUI') then
            local registry = LibStub('AceConfigRegistry-3.0-ElvUI', true)
            if registry then registry:NotifyChange('ElvUI') end
        elseif self.Libs.ACR.NotifyChange then self.Libs.ACR:NotifyChange(self.AddOnName) end
    end)
end
function JI:SetupSettingsWindow()
    self:StyleNativeOptions()
    self:HookElvUISettingsBrand()
    self:HookSettingsSelection(standalone)
    self:HookSettingsSelection(self.Libs.ACD)
    if self.settingsRegistered then return end
    self.settingsRegistered = true
    self.Libs.AC:RegisterOptionsTable(self.AddOnName, function() return self:BuildStandaloneOptions() end)
    standalone:SetDefaultSize(self.AddOnName, 1000, 700)
    if not self:IsAddOnEnabled('ElvUI') then standalone:AddToBlizOptions(self.AddOnName, Plain(self.Title)) end
end
