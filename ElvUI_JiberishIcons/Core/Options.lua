local JI, L = unpack(ElvUI_JiberishIcons)
local ACH = JI.Libs.ACH

local AddOnName = ...
local classInfo = JI.icons.class

local CREDITS = {
	'|cfff48cbaRepooc|r',
	JI:TextGradient('Eltreum', 0.50, 0.70, 1, 0.67, 0.95, 1),
	JI:TextGradient('Blinkii', 0, 0.64, 1, 0, 0.80, 1, 0, 0.968, 1),
	'|cffff2f3cTrenchy|r',
	'|cff39FF14MaximumOverdrive|r',
	'|cFF08E8DEBotanica|r',
	'|cffb8bb26Thurin|r',
	'|cffd19d3bPat|r',
	'|cffffb300Madlampy|r',
}

local function SortList(a, b)
	return JI:StripString(a) < JI:StripString(b)
end
sort(CREDITS, SortList)
CREDITS = table.concat(CREDITS, '|n')

local UF = JI:IsAddOnEnabled('ElvUI') and ElvUI[1].UnitFrames or ''
local elvuiUnitList = {
	player = {
		updateFunc = UF.CreateAndUpdateUF,
		groupName = 'individualUnits',
	},
	pet = {
		updateFunc = UF.CreateAndUpdateUF,
		groupName = 'individualUnits',
	},
	pettarget = {
		updateFunc = UF.CreateAndUpdateUF,
		groupName = 'individualUnits',
	},
	target = {
		updateFunc = UF.CreateAndUpdateUF,
		groupName = 'individualUnits',
	},
	targettarget = {
		updateFunc = UF.CreateAndUpdateUF,
		groupName = 'individualUnits',
	},
	targettargettarget = {
		updateFunc = UF.CreateAndUpdateUF,
		groupName = 'individualUnits',
	},
	focus = {
		updateFunc = UF.CreateAndUpdateUF,
		groupName = 'individualUnits',
	},
	focustarget = {
		updateFunc = UF.CreateAndUpdateUF,
		groupName = 'individualUnits',
	},
	party = {
		updateFunc = UF.CreateAndUpdateHeaderGroup,
		groupName = 'groupUnits',
	},
	raid1 = {
		updateFunc = UF.CreateAndUpdateHeaderGroup,
		groupName = 'groupUnits',
	},
	raid2 = {
		updateFunc = UF.CreateAndUpdateHeaderGroup,
		groupName = 'groupUnits',
	},
	raid3 = {
		updateFunc = UF.CreateAndUpdateHeaderGroup,
		groupName = 'groupUnits',
	},
	raidpet = {
		updateFunc = UF.CreateAndUpdateHeaderGroup,
		groupName = 'groupUnits',
	},
	boss = {
		updateFunc = UF.CreateAndUpdateUFGroup, --MAX_BOSS_FRAMES
		groupName = 'groupUnits',
	},
	arena = {
		updateFunc = UF.CreateAndUpdateUFGroup, --5
		groupName = 'groupUnits',
	},
}

local settingTest = {}
settingTest['blizzard'] = { portrait = {}, icon = {} }
settingTest['elvui'] = { portrait = {} }
settingTest['suf'] = { portrait = {}, icon = {} }
local function ApplySettingsToAll(module, element, setting, func)
	local db = JI.db[module]
	if not db then return end

	for unit, data in next, db do
		--* Apply Settings to the database
		db[unit][element][setting] = settingTest[module][element][setting]

		--* Check if ElvUI is enabled and module is set to elvui
		if JI:IsAddOnEnabled('ElvUI') and module == 'elvui' then
			--* Update for ElvUI UnitFrames
			elvuiUnitList[unit].updateFunc(nil, unit, (unit == 'boss' and MAX_BOSS_FRAMES) or (unit == 'arena' and 5) or nil)
		end
	end

	--* Run the update function for all modules if not elvui as it is handled above
	if module ~= 'elvui' then
		func()
	end
end

local function UpdateChat()
	if not JI:IsAddOnEnabled('ElvUI') then return end

	JI:ToggleElvUIChat()
end

--! Main Header
JI.Options = ACH:Group(JI.Title, nil, 6, 'tab')
JI.Options.args.logo = ACH:Description(nil, 0, nil, [[Interface\AddOns\ElvUI_JiberishIcons\Media\Logo\LargeLogo]], nil, 256, 128)
JI.Options.args.version = ACH:Header(JI.Version, 1)

--! Style Packs Tab
local StylePacks = ACH:Group(L["Style Packs"], nil, 1)
JI.Options.args.StylePacks = StylePacks

local StyleGroup
local iconStyleList = {}
local displayString = '|T%s%s:%s:%s:0:0:1024:1024:%s|t'
local AllPoints = { TOPLEFT = 'TOPLEFT', LEFT = 'LEFT', BOTTOMLEFT = 'BOTTOMLEFT', RIGHT = 'RIGHT', TOPRIGHT = 'TOPRIGHT', BOTTOMRIGHT = 'BOTTOMRIGHT', TOP = 'TOP', BOTTOM = 'BOTTOM', CENTER = 'CENTER' }

local function ColorText(text, color)
	if not text then return end
	color = color or 'FFD100'
	return format('|cff%s%s|r', color, text)
end

--* Dynamically build the groups for each style pack
for iconStyle, data in next, classInfo.styles do
	iconStyleList[iconStyle] = data.name

	StyleGroup = ACH:Group(data.name)
	StylePacks.args[iconStyle] = StyleGroup
	StyleGroup.inline = true

	local classTextureString = ''
	for _, iconData in next, classInfo.data do
		classTextureString = classTextureString..format(displayString, classInfo.path, iconStyle, '48', '48', iconData.texString)
	end
	StyleGroup.args.icons = ACH:Description(function() return classTextureString end, 1)

	if data.artist and data.artist ~= '' then
		StyleGroup.args.credit = ACH:Description(format('|cffFFD100%s |r%s%s\n%s|r', L["Made by"], JI:IsAddOnEnabled('ElvUI') and _G.ElvUI[1].media.hexvaluecolor or '|cff1684d1', data.artist or '', data.site or ''), 99)
	end
end

--! Chat
local chat = ACH:Group(L["Chat"], nil, 20, nil, function(info) return JI.db.chat[info[#info]] end, function(info, value) JI.db.chat[info[#info]] = value UpdateChat() end)
JI.Options.args.chat = chat
chat.args.enable = ACH:Toggle(L["Enable"], nil, 1)
chat.args.spacer = ACH:Spacer(2, 'full')
chat.args.style = ACH:Select(L["Style Selection"], nil, 3, iconStyleList)

--! Blizzard Frames Tab (BlizzUI)
local blizzard = ACH:Group(L["Blizzard Frames"], nil, 50, nil)
JI.Options.args.blizzard = blizzard

--* General Section (BlizzUI)
blizzard.args.general = ACH:Group(L["General"], nil, 1, 'tab')
blizzard.args.general.args.desc = ACH:Description(ColorText(L["You can use the sections below to change the settings across all supported frames with the selected value at the time you click the Apply To All button."]), 1)

--* Apply All (Portrait)
blizzard.args.general.args.portrait = ACH:Group(L["Portrait"], nil, 2)
blizzard.args.general.args.portrait.inline = true
blizzard.args.general.args.portrait.args.enable = ACH:Select(L["Enabled State"], nil, 1, { enable = L["Enabled"], disable = L["Disabled"] }, nil, nil, function(info) return (settingTest[info[#info-3]][info[#info-1]] and settingTest[info[#info-3]][info[#info-1]].enable) and (settingTest[info[#info-3]][info[#info-1]].enable == true and 'enable') or (settingTest[info[#info-3]][info[#info-1]].enable == false and 'disable') or nil end, function(info, value) settingTest[info[#info-3]][info[#info-1]][info[#info]] = (value == 'enable' and true) or (value == 'disable' and false) end)
blizzard.args.general.args.portrait.args.confirmEnable = ACH:Execute(L["Apply To All"], nil, 2, function() ApplySettingsToAll(info[#info-3], info[#info-1], 'enable', JI.UpdateMedia) settingTest[info[#info-3]][info[#info-1]].enable = nil end, nil, L["You are about to select this option for all supported units.\nDo you wish to continue?"], nil, nil, nil, function(info) return settingTest[info[#info-3]][info[#info-1]].enable == nil end)
blizzard.args.general.args.portrait.args.spacer = ACH:Spacer(3, 'full')
blizzard.args.general.args.portrait.args.style = ACH:Select(L["Style Selection"], nil, 4, iconStyleList, nil, nil, function(info) return (settingTest.portrait and settingTest.portrait.style) and settingTest.portrait.style or nil end, function(info, value) settingTest.portrait[info[#info]] = value end)
blizzard.args.general.args.portrait.args.confirmStyle = ACH:Execute(L["Apply To All"], nil, 5, function(info) ApplySettingsToAll(info[#info-3], info[#info-1], 'style', JI.UpdateMedia) settingTest[info[#info-3]][info[#info-1]].style = nil end, nil, L["You are about to select this option for all supported units.\nDo you wish to continue?"], nil, nil, nil, function(info) return not settingTest[info[#info-3]][info[#info-1]].style end)

--* Apply All (Icon)
blizzard.args.general.args.icon = ACH:Group(L["Icon"], nil, 3)
blizzard.args.general.args.icon.inline = true
blizzard.args.general.args.icon.args.enable = ACH:Select(L["Enabled State"], nil, 1, { enable = L["Enabled"], disable = L["Disabled"] }, nil, nil, function(info) return (settingTest[info[#info-3]][info[#info-1]] and settingTest[info[#info-3]][info[#info-1]].enable) and (settingTest[info[#info-3]][info[#info-1]].enable == true and 'enable') or (settingTest[info[#info-3]][info[#info-1]].enable == false and 'disable') or nil end, function(info, value) settingTest[info[#info-3]][info[#info-1]][info[#info]] = (value == 'enable' and true) or (value == 'disable' and false) end)
blizzard.args.general.args.icon.args.confirmEnable = ACH:Execute(L["Apply To All"], nil, 2, function(info) ApplySettingsToAll(info[#info-3], info[#info-1], 'enable', JI.UpdateMedia) settingTest[info[#info-3]][info[#info-1]].enable = nil end, nil, L["You are about to select this option for all supported units.\nDo you wish to continue?"], nil, nil, nil, function(info) return settingTest[info[#info-3]][info[#info-1]].enable == nil end)
blizzard.args.general.args.icon.args.spacer = ACH:Spacer(3, 'full')
blizzard.args.general.args.icon.args.style = ACH:Select(L["Icon Style"], nil, 4, iconStyleList, nil, nil, function(info) return (settingTest[info[#info-3]][info[#info-1]] and settingTest[info[#info-3]][info[#info-1]].style) and settingTest[info[#info-3]][info[#info-1]].style or nil end, function(info, value) settingTest[info[#info-3]][info[#info-1]][info[#info]] = value end)
blizzard.args.general.args.icon.args.confirmStyle = ACH:Execute(L["Apply To All"], nil, 5, function(info) ApplySettingsToAll(info[#info-3], info[#info-1], 'style', JI.UpdateMedia) settingTest[info[#info-3]][info[#info-1]].style = nil end, nil, L["You are about to select this option for all supported units.\nDo you wish to continue?"], nil, nil, nil, function(info) return not settingTest[info[#info-3]][info[#info-1]].style end)

local colorOverrideOptions = {
	name = function(info)
		local text = L["Class Color Override (|c%s%s|r)"]
		local value = JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]]
		if value == 2 then
			return format(text, 'FF00FF00', L["Unit Class"])
		elseif value == 1 then
			return format(text, RAID_CLASS_COLORS[select(2, UnitClass('player'))].colorStr or 'FFFFFFFF', L["My Class"])
		else
			return format(text, 'FFFF3333', L["Ignored"])
		end
	end,
}

-- for _, unit in next, { 'player', 'target', 'targettarget', 'focus', 'focustarget', 'party', 'raid' } do
for _, unit in next, { 'player', 'target', 'targettarget', 'focus', 'focustarget', 'party' } do
	blizzard.args[unit] = ACH:Group(gsub(gsub(unit, '(.)', strupper, 1), 't(arget)', 'T%1'), nil, 1, 'tab')

	-- if unit ~= 'raid' then
		local portrait = ACH:Group(L["Portrait"], nil, 5)
		blizzard.args[unit].args.portrait = portrait
		portrait.inline = true

		portrait.args.header = ACH:Description(ColorText(format(L["This will apply the selected class icon style to %s unitframes where they show a players portrait."], 'Blizzard')), 1)
		portrait.args.enable = ACH:Toggle(L["Enable"], nil, 2, nil, nil, nil, function(info) return JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-2], info[#info-1]) end)
		portrait.args.style = ACH:Select(L["Style"], nil, 3, iconStyleList, nil, nil, function(info) return JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-2], info[#info-1]) end, function(info) return not JI.db.blizzard[info[#info-2]][info[#info-1]].enable end)

		local background = ACH:Group(L["Background"], nil, 10, nil, nil, 'full', function(info) return not JI.db.blizzard[info[#info-3]][info[#info-2]].enable end)
		portrait.args.background = background
		background.inline = true
		background.args.enable = ACH:Toggle(L["Enable"], nil, 2, nil, nil, nil, function(info) return JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-3], info[#info-2]) end)
		background.args.color = ACH:Color(L["Color"], nil, 10, true, nil, function(info) return unpack(JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]]) end, function(info, r, g, b, a) JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] = { r, g, b, a } JI:UnitFramePortrait_Update(info[#info-3], info[#info-2]) end, function(info) return not JI.db.blizzard[info[#info-3]][info[#info-2]].enable or not JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]].enable end)
		background.args.colorOverride = ACH:Toggle(colorOverrideOptions.name, L["This will override the color option (alpha slider setting is still followed) and force the background color to show as the class color of the unit that is displayed."], 15, true, nil, 'full', function(info) local value = JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] if value == 2 then return true elseif value == 1 then return nil else return false end end, function(info, value) JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] = (unit ~= 'player' and value and 2) or (unit == 'player' and value and 1) or (value == nil and 1) or 0 JI:UnitFramePortrait_Update(info[#info-3], info[#info-2]) end, function(info) return not JI.db.blizzard[info[#info-3]][info[#info-2]].enable or not JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]].enable end)
	-- end

	local icon = ACH:Group(L["Icon"], nil, 10)
	blizzard.args[unit].args.icon = icon
	icon.inline = true

	icon.args.header = ACH:Description(ColorText(L["This will add an icon that will show the class of the unit that is displayed in the unitframe that the icon is attached to."]), 1)
	icon.args.enable = ACH:Toggle(L["Enable"], nil, 2, nil, nil, nil, function(info) return JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-2], info[#info-1]) end)
	icon.args.style = ACH:Select(L["Style"], nil, 3, iconStyleList, nil, nil, function(info) return JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-2], info[#info-1]) end, function(info) return not JI.db.blizzard[info[#info-2]][info[#info-1]].enable end)
	icon.args.size = ACH:Range(L["Size"], nil, 5, { min = 8, max = 128, step = 1 }, nil, function(info) return JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-2], info[#info-1]) end, function(info) return not JI.db.blizzard[info[#info-2]][info[#info-1]].enable end)
	icon.args.anchorPoint = ACH:Select(L["Anchor Point"], L["What point to anchor to the frame you set to attach to."], 12, AllPoints, nil, nil, function(info) return JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-2], info[#info-1]) end, function(info) return not JI.db.blizzard[info[#info-2]][info[#info-1]].enable end)
	icon.args.spacer = ACH:Description('', 15)
	icon.args.xOffset = ACH:Range(L["xOffset"], nil, 16, { min = -150, max = 150, step = 1 }, nil, function(info) return JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-2], info[#info-1]) end, function(info) return not JI.db.blizzard[info[#info-2]][info[#info-1]].enable end)
	icon.args.yOffset = ACH:Range(L["yOffset"], nil, 17, { min = -150, max = 150, step = 1 }, nil, function(info) return JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-2], info[#info-1]) end, function(info) return not JI.db.blizzard[info[#info-2]][info[#info-1]].enable end)
end

--* Sort unit list manually instead of alphabetically
blizzard.args.player.order = 4
blizzard.args.target.order = 5
blizzard.args.targettarget.order = 6
blizzard.args.focus.order = 7
blizzard.args.focustarget.order = 8
blizzard.args.party.order = 9
-- blizzard.args.raid.order = 10

--! ElvUI Tab
-- local elvuiUnitList = {'player', 'pet', 'pettarget', 'target', 'targettarget', 'targettargettarget', 'focus', 'focustarget', 'party', 'raid1', 'raid2', 'raid3', 'raidpet', 'boss', 'arena' }
local elvui = ACH:Group('ElvUI', nil, 50, nil, nil, nil, nil, function() return not JI:IsAddOnEnabled('ElvUI') end)
JI.Options.args.elvui = elvui

--* General Section (ElvUI)
elvui.args.general = ACH:Group(L["General"], nil, 1, 'tab')
elvui.args.general.args.desc = ACH:Description(ColorText(L["You can use the sections below to change the settings across all supported frames with the selected value at the time you click the Apply To All button."]), 1)

--* Apply All (Portrait)
elvui.args.general.args.portrait = ACH:Group(L["Portrait"], nil, 2)
elvui.args.general.args.portrait.inline = true
elvui.args.general.args.portrait.args.enable = ACH:Select(L["Enabled State"], nil, 1, { enable = L["Enabled"], disable = L["Disabled"] }, nil, nil, function(info) return (settingTest[info[#info-3]][info[#info-1]] and settingTest[info[#info-3]][info[#info-1]].enable) and (settingTest[info[#info-3]][info[#info-1]].enable == true and 'enable') or (settingTest[info[#info-3]][info[#info-1]].enable == false and 'disable') or nil end, function(info, value) settingTest[info[#info-3]][info[#info-1]][info[#info]] = (value == 'enable' and true) or (value == 'disable' and false) end)
elvui.args.general.args.portrait.args.confirmEnable = ACH:Execute(L["Apply To All"], nil, 2, function(info) ApplySettingsToAll(info[#info-3], info[#info-1], 'enable') settingTest[info[#info-3]][info[#info-1]].enable = nil end, nil, L["You are about to select this option for all supported units.\nDo you wish to continue?"], nil, nil, nil, function(info) return settingTest[info[#info-3]][info[#info-1]].enable == nil end)
elvui.args.general.args.portrait.args.spacer = ACH:Spacer(3, 'full')
elvui.args.general.args.portrait.args.style = ACH:Select(L["Style Selection"], nil, 4, iconStyleList, nil, nil, function(info) return (settingTest[info[#info-3]][info[#info-1]] and settingTest[info[#info-3]][info[#info-1]].style) and settingTest[info[#info-3]][info[#info-1]].style or nil end, function(info, value) settingTest[info[#info-3]][info[#info-1]][info[#info]] = value end)
elvui.args.general.args.portrait.args.confirmStyle = ACH:Execute(L["Apply To All"], nil, 5, function(info) ApplySettingsToAll(info[#info-3], info[#info-1], 'style') settingTest[info[#info-3]][info[#info-1]].style = nil end, nil, L["You are about to select this option for all supported units.\nDo you wish to continue?"], nil, nil, nil, function(info) return not settingTest[info[#info-3]][info[#info-1]].style end)

for unit, data in next, elvuiUnitList do
	local unitName = gsub(gsub(unit, '(.)', strupper, 1), 't(arget)', 'T%1')
	--* Create ElvUI Unit Entry
	elvui.args[unit] = ACH:Group(unitName, nil, 2, 'tab')
	elvui.args[unit].args.elvUnit = ACH:Execute(format(L["ElvUI %s Config"], unitName), L["ElvUI %s Config"], 1, function() JI.Libs.ACD:SelectGroup('ElvUI', 'unitframe', data.groupName, unit, 'general') end, nil, nil, nil, nil, nil, function() if JI:IsAddOnEnabled('ElvUI') then return not ElvUI[1].private.unitframe.enable else return true end end)

	--* Portrait (ElvUI)
	local portrait = ACH:Group(L["Portrait"], nil, 5, nil, nil, nil, function() return not (JI:IsAddOnEnabled('ElvUI') and ElvUI[1].db.unitframe.units[unit].portrait.enable) end)
	elvui.args[unit].args.portrait = portrait
	portrait.inline = true
	portrait.args.header = ACH:Description(ColorText(format(L["This will apply the selected class icon style to %s unitframes where they show a players portrait."], 'ElvUI')), 1)
	portrait.args.enable = ACH:Toggle(L["Enable"], nil, 2, nil, nil, nil, function(info) return JI.db[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] = value data.updateFunc(nil, info[#info-2], (unit == 'boss' and MAX_BOSS_FRAMES) or (unit == 'arena' and 5) or nil) end)
	portrait.args.style = ACH:Select(L["Style"], nil, 3, iconStyleList, nil, nil, function(info) return JI.db[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] = value data.updateFunc(nil, info[#info-2]) end, function(info) return ((JI:IsAddOnEnabled('ElvUI') and not ElvUI[1].db.unitframe.units[unit].portrait.enable)) or not JI.db[info[#info-3]][info[#info-2]][info[#info-1]].enable end)
	portrait.args.spacer = ACH:Spacer(4, 'full')
	portrait.args.elvuiConfig = ACH:Execute(format(L["ElvUI %s Portrait Config"], unitName), format(L["ElvUI %s Portrait Config"], unitName), 99, function() JI.Libs.ACD:SelectGroup('ElvUI', 'unitframe', data.groupName, unit, 'portrait') end, nil, nil, nil, nil, nil, function() return false end)
	portrait.args.helpText = ACH:Description(ColorText(format(L["%s portrait is disabled in %s, click the button to quickly navigate to the proper section."], unitName, 'ElvUI'), 'FF3333'), 100, nil, nil, nil, nil, nil, nil, function() if JI:IsAddOnEnabled('ElvUI') then return ElvUI[1].db.unitframe.units[unit].portrait.enable else return true end end)
end

--! Shadowed Unit Frames Tab (SUF)
--* All suf frames from their own table
local sufUnitList = {'player', 'pet', 'pettarget', 'target', 'targettarget', 'targettargettarget', 'focus', 'focustarget', 'party', 'partypet', 'partytarget', 'partytargettarget', 'raid', 'raidpet', 'boss', 'bosstarget', 'maintank', 'maintanktarget', 'mainassist', 'mainassisttarget', 'arena', 'arenatarget', 'arenapet', 'battleground', 'battlegroundtarget', 'battlegroundpet', 'arenatargettarget', 'battlegroundtargettarget', 'maintanktargettarget', 'mainassisttargettarget', 'bosstargettarget'}
local suf = ACH:Group('Shadowed Unit Frames', nil, 50, nil, nil, nil, nil, function() return not JI:IsAddOnEnabled('ShadowedUnitFrames') end)
JI.Options.args.suf = suf

--* General Section (SUF)
suf.args.general = ACH:Group(L["General"], nil, 1, 'tab')
suf.args.general.args.desc = ACH:Description(ColorText(L["You can use the sections below to change the settings across all supported frames with the selected value at the time you click the Apply To All button."]), 1)

--* Apply All (Portrait)
suf.args.general.args.portrait = ACH:Group(L["Portrait"], nil, 2)
suf.args.general.args.portrait.inline = true
suf.args.general.args.portrait.args.enable = ACH:Select(L["Enabled State"], nil, 1, { enable = L["Enabled"], disable = L["Disabled"] }, nil, nil, function(info) return (settingTest[info[#info-3]][info[#info-1]] and settingTest[info[#info-3]][info[#info-1]].enable) and (settingTest[info[#info-3]][info[#info-1]].enable == true and 'enable') or (settingTest[info[#info-3]][info[#info-1]].enable == false and 'disable') or nil end, function(info, value) settingTest[info[#info-3]][info[#info-1]][info[#info]] = (value == 'enable' and true) or (value == 'disable' and false) end)
suf.args.general.args.portrait.args.confirmEnable = ACH:Execute(L["Apply To All"], nil, 2, function(info) ApplySettingsToAll(info[#info-3], info[#info-1], 'enable', JI.UpdateSUF) settingTest[info[#info-3]][info[#info-1]].enable = nil end, nil, L["You are about to select this option for all supported units.\nDo you wish to continue?"], nil, nil, nil, function(info) return settingTest[info[#info-3]][info[#info-1]].enable == nil end)
suf.args.general.args.portrait.args.spacer = ACH:Spacer(3, 'full')
suf.args.general.args.portrait.args.style = ACH:Select(L["Style Selection"], nil, 4, iconStyleList, nil, nil, function(info) return (settingTest[info[#info-3]][info[#info-1]] and settingTest[info[#info-3]][info[#info-1]].style) and settingTest[info[#info-3]][info[#info-1]].style or nil end, function(info, value) settingTest[info[#info-3]][info[#info-1]][info[#info]] = value end)
suf.args.general.args.portrait.args.confirmStyle = ACH:Execute(L["Apply To All"], nil, 5, function(info) ApplySettingsToAll(info[#info-3], info[#info-1], 'style', JI.UpdateSUF) settingTest[info[#info-3]][info[#info-1]].style = nil end, nil, L["You are about to select this option for all supported units.\nDo you wish to continue?"], nil, nil, nil, function(info) return not settingTest[info[#info-3]][info[#info-1]].style end)

--* Apply All (Icon)
suf.args.general.args.icon = ACH:Group(L["Icon"], nil, 3)
suf.args.general.args.icon.inline = true
suf.args.general.args.icon.args.enable = ACH:Select(L["Enabled State"], nil, 1, { enable = L["Enabled"], disable = L["Disabled"] }, nil, nil, function(info) return (settingTest[info[#info-3]][info[#info-1]] and settingTest[info[#info-3]][info[#info-1]].enable) and (settingTest[info[#info-3]][info[#info-1]].enable == true and 'enable') or (settingTest[info[#info-3]][info[#info-1]].enable == false and 'disable') or nil end, function(info, value) settingTest[info[#info-3]][info[#info-1]][info[#info]] = (value == 'enable' and true) or (value == 'disable' and false) end)
suf.args.general.args.icon.args.confirmEnable = ACH:Execute(L["Apply To All"], nil, 2, function(info) ApplySettingsToAll(info[#info-3], info[#info-1], 'enable', JI.UpdateSUF) settingTest[info[#info-3]][info[#info-1]].enable = nil end, nil, L["You are about to select this option for all supported units.\nDo you wish to continue?"], nil, nil, nil, function(info) return settingTest[info[#info-3]][info[#info-1]].enable == nil end)
suf.args.general.args.icon.args.spacer = ACH:Spacer(3, 'full')
suf.args.general.args.icon.args.style = ACH:Select(L["Icon Style"], nil, 4, iconStyleList, nil, nil, function(info) return (settingTest[info[#info-3]][info[#info-1]] and settingTest[info[#info-3]][info[#info-1]].style) and settingTest[info[#info-3]][info[#info-1]].style or nil end, function(info, value) settingTest[info[#info-3]][info[#info-1]][info[#info]] = value end)
suf.args.general.args.icon.args.confirmStyle = ACH:Execute(L["Apply To All"], nil, 5, function(info) ApplySettingsToAll(info[#info-3], info[#info-1], 'style', JI.UpdateSUF) settingTest[info[#info-3]][info[#info-1]].style = nil end, nil, L["You are about to select this option for all supported units.\nDo you wish to continue?"], nil, nil, nil, function(info) return not settingTest[info[#info-3]][info[#info-1]].style end)

for _, unit in next, sufUnitList do
	--* SUF Unit
	suf.args[unit] = ACH:Group(gsub(gsub(unit, '(.)', strupper, 1), 't(arget)', 'T%1'), nil, 2, 'tab')

	--* Portrait (SUF)
	local portrait = ACH:Group(L["Portrait"], nil, 5)
	suf.args[unit].args.portrait = portrait
	portrait.inline = true
	portrait.args.header = ACH:Description(ColorText(L["This will apply the selected class icon style to SUF's unitframes where they show a players class icon."]), 1)
	portrait.args.enable = ACH:Toggle(L["Enable"], nil, 2, nil, nil, nil, function(info) return JI.db[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] = value ShadowUF.Layout:Reload(info[#info-2]) end)
	portrait.args.style = ACH:Select(L["Style"], nil, 3, iconStyleList, nil, nil, function(info) return JI.db[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] = value ShadowUF.Layout:Reload(info[#info-2]) end, function(info) return not JI.db[info[#info-3]][info[#info-2]][info[#info-1]].enable end)

	--* Icon (SUF)
	local icon = ACH:Group(L["Icon"], nil, 10)
	suf.args[unit].args.icon = icon
	icon.inline = true

	icon.args.header = ACH:Description(ColorText(L["This will add an icon that will show the class of the unit that is displayed in the unitframe that the icon is attached to."]), 1)
	icon.args.enable = ACH:Toggle(L["Enable"], nil, 2, nil, nil, nil, function(info) return JI.db.suf[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.suf[info[#info-2]][info[#info-1]][info[#info]] = value ShadowUF.Layout:Reload(info[#info-2]) end)
	icon.args.style = ACH:Select(L["Style"], nil, 3, iconStyleList, nil, nil, function(info) return JI.db.suf[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.suf[info[#info-2]][info[#info-1]][info[#info]] = value ShadowUF.Layout:Reload(info[#info-2]) end, function(info) return not JI.db.suf[info[#info-2]][info[#info-1]].enable end)
	icon.args.size = ACH:Range(L["Size"], nil, 5, { min = 8, max = 128, step = 1 }, nil, function(info) return JI.db.suf[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.suf[info[#info-2]][info[#info-1]][info[#info]] = value ShadowUF.Layout:Reload(info[#info-2]) end, function(info) return not JI.db.suf[info[#info-2]][info[#info-1]].enable end)
	icon.args.anchorPoint = ACH:Select(L["Anchor Point"], L["What point to anchor to the frame you set to attach to."], 12, AllPoints, nil, nil, function(info) return JI.db.suf[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.suf[info[#info-2]][info[#info-1]][info[#info]] = value ShadowUF.Layout:Reload(info[#info-2]) end, function(info) return not JI.db.suf[info[#info-2]][info[#info-1]].enable end)
	icon.args.spacer = ACH:Description('', 15)
	icon.args.xOffset = ACH:Range(L["xOffset"], nil, 16, { min = -150, max = 150, step = 1 }, nil, function(info) return JI.db.suf[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.suf[info[#info-2]][info[#info-1]][info[#info]] = value ShadowUF.Layout:Reload(info[#info-2]) end, function(info) return not JI.db.suf[info[#info-2]][info[#info-1]].enable end)
	icon.args.yOffset = ACH:Range(L["yOffset"], nil, 17, { min = -150, max = 150, step = 1 }, nil, function(info) return JI.db.suf[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.suf[info[#info-2]][info[#info-1]][info[#info]] = value ShadowUF.Layout:Reload(info[#info-2]) end, function(info) return not JI.db.suf[info[#info-2]][info[#info-1]].enable end)
end

--! Information Tab
local Information = ACH:Group(L["Information"], nil, 80)
JI.Options.args.Information = Information

Information.args.links = ACH:Group(L["Links"], nil, 1)
Information.args.links.inline = true
Information.args.links.args.discord = ACH:Input(L["Discord"], L["DISCORD_MSG"], 2, nil, 'full', function() return 'https://discord.com/invite/jr5w8ArzAx' end)
Information.args.links.args.issues = ACH:Input(L["Support Tickets"], nil, 3, nil, 'full', function() return 'https://github.com/repooc/ElvUI_JiberishIcons/issues' end)
Information.args.links.args.jiberishui = ACH:Input('JiberishUI', L["Go download JiberishUI from Curse! You can try your pick of various ElvUI profiles by using the installer!"], 4, nil, 'full', function() return 'https://www.curseforge.com/wow/addons/jiberishui' end)
Information.args.links.args.wagoprofile = ACH:Input(L["Wago Profile"], L["WAGO_MSG"], 4, nil, 'full', function() return 'https://wago.io/p/Jiberish%231723' end)

-- TODO: Change to execture buttons if ElvUI is loaded instead? Ask Jiberish which he prefers. Don't forget the issues entry as well as these buttons were from before the big changes.
-- Information.args.discord = ACH:Execute('Discord', "Come join the Discord server and share your ui with everyone, and maybe try someone else's...?", 1, function() E:StaticPopup_Show('ELVUI_EDITBOX', nil, nil, 'https://discord.com/invite/jr5w8ArzAx') end, nil, nil, JI:IsAddOnEnabled('ElvUI') and 140 or nil)
-- Information.args.jiberishui = ACH:Execute('JiberishUI', "Go download JiberishUI from Curse! You can try your pick of various ElvUI profiles by using the installer!", 2, function() E:StaticPopup_Show('ELVUI_EDITBOX', nil, nil, 'https://www.curseforge.com/wow/addons/jiberishui') end, nil, nil, JI:IsAddOnEnabled('ElvUI') and 140 or nil)
-- Information.args.wagoprofile = ACH:Execute("Wago Profile", "Looking for some nice profile strings for ElvUI? Go check out my wago profile for some nice profiles!", 3, function() E:StaticPopup_Show('ELVUI_EDITBOX', nil, nil, 'https://wago.io/p/Jiberish%231723') end, nil, nil, JI:IsAddOnEnabled('ElvUI') and 140 or nil)

local Credits = ACH:Group(L["Fabled Incarnates"], nil, 10)
Information.args.Credits = Credits
Credits.inline = true
Credits.args.credits = ACH:Description(CREDITS, 1, 'medium')

local sharedDefaultValues = {
	portrait = {
		enable = false,
		style = 'fabled',
		background = {
			enable = true,
			colorOverride = 0,
			color = { 0, 0, 0, 0.5 },
		},
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

function JI:BuildProfile()
	local Defaults = {
		profile = {
			blizzard = {
				player = sharedDefaultValues,
				target = sharedDefaultValues,
				targettarget = sharedDefaultValues,
				focus = sharedDefaultValues,
				focustarget = sharedDefaultValues,
				party = sharedDefaultValues,
				-- raid = {
				-- 	icon = sharedDefaultValues.icon,
				-- },
			},
			chat = {
				enable = false,
				style = 'fabled',
			},
			elvui = {},
			suf = {},
		},
	}
	for unit in pairs(elvuiUnitList) do
		Defaults.profile.elvui[unit] = {
			portrait = {
				enable = false,
				style = 'fabled',
			},
		}
	end

	for _, unit in pairs(sufUnitList) do
		Defaults.profile.suf[unit] = {
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

	JI.data = JI.Libs.ADB:New('JiberishIconsDB', Defaults)
	JI.data.RegisterCallback(JI, 'OnProfileChanged', 'SetupProfile')
	JI.data.RegisterCallback(JI, 'OnProfileCopied', 'SetupProfile')
	JI.data.RegisterCallback(JI, 'OnProfileReset', 'SetupProfile')

	JI.db = JI.data.profile
end

function JI:SetupProfile()
	JI.db = JI.data.profile
	JI:UpdateMedia()
end

function JI:GetOptions()
	if JI:IsAddOnEnabled('ElvUI') then
		_G.ElvUI[1].Options.args.jiberishicons = JI.Options
		--* Maybe implement this for stuff that may need a reload.
		-- hooksecurefunc(JI.Libs.ACD, 'CloseAll', function()
		-- 	if JI.NeedReload then
		-- 		_G.ElvUI[1]:StaticPopup_Show('PRIVATE_RL')
		-- 	end
		-- end)
	end
end

function JI:BuildOptions()
	if JI.Libs.EP and JI:IsAddOnEnabled('ElvUI') then
		JI.Libs.EP:RegisterPlugin(AddOnName, JI.GetOptions)
	else
		JI.Libs.AC:RegisterOptionsTable(AddOnName, JI.Options)
		JI.Libs.ACD:AddToBlizOptions(AddOnName, JI.Title)
		JI.Libs.ACD:SetDefaultSize(AddOnName, 900, 650)
	end
	JI.Options.args.profiles = JI.Libs.ADBO:GetOptionsTable(JI.data, true)
	JI.Options.args.profiles.order = -2
end
