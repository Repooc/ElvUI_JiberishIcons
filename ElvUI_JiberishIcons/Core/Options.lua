local JI, L = unpack(ElvUI_JiberishIcons)
local ACH = JI.Libs.ACH

local AddOnName = ...
local classIconPath, classIcons, iconStyles = JI.classIconPath, JI.classIcons, JI.iconStyles

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

--* Main Header
-- JI.Options = ACH:Group(JI:IsAddOnEnabled('ElvUI') and JI.Title or '', nil, 6, 'tab')
JI.Options = ACH:Group(JI.Title, nil, 6, 'tab')
JI.Options.args.logo = ACH:Description(nil, 0, nil, [[Interface\AddOns\ElvUI_JiberishIcons\Media\LargeLogo]], nil, 256, 128)
JI.Options.args.version = ACH:Header(JI.Version, 1)

--* Style Packs Tab
local StylePacks = ACH:Group(L["Style Packs"], nil, 5)
JI.Options.args.StylePacks = StylePacks

local StyleGroup
local iconStyleList = {}
local displayString = '|T%s%s:%s:%s:0:0:1024:1024:%s|t'
local AllPoints = { TOPLEFT = 'TOPLEFT', LEFT = 'LEFT', BOTTOMLEFT = 'BOTTOMLEFT', RIGHT = 'RIGHT', TOPRIGHT = 'TOPRIGHT', BOTTOMRIGHT = 'BOTTOMRIGHT', TOP = 'TOP', BOTTOM = 'BOTTOM', CENTER = 'CENTER' }

local function ColorText(color, text)
	if not text then return end
	color = color or 'FFD100'
	return format('|cff%s%s|r', color, text)
end

for iconStyle, data in next, iconStyles do
	iconStyleList[iconStyle] = data.name

	StyleGroup = ACH:Group(data.name)
	StylePacks.args[iconStyle] = StyleGroup
	StyleGroup.inline = true

	local classTextureString = ''
	for _, iconData in next, classIcons do
		classTextureString = classTextureString..format(displayString, classIconPath, iconStyle, '48', '48', iconData.texString)
	end
	StyleGroup.args.icons = ACH:Description(function() return classTextureString end, 1)

	if data.artist and data.artist ~= '' then
		StyleGroup.args.credit = ACH:Description(format('|cffFFD100%s |r%s%s\n%s|r', L["Made by"], JI:IsAddOnEnabled('ElvUI') and _G.ElvUI[1].media.hexvaluecolor or '|cff1684d1', data.artist or '', data.site or ''), 99)
	end
end

--* Blizzard Frames Tab
local blizzard = ACH:Group(L["Blizzard Frames"], nil, 6, nil)
JI.Options.args.blizzard = blizzard

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

	if unit ~= 'raid' then
		local portrait = ACH:Group(L["Portrait"], nil, 5)
		blizzard.args[unit].args.portrait = portrait
		portrait.inline = true

		portrait.args.header = ACH:Description(ColorText(nil, L["This will apply the selected class icon style to Blizzard's unitframes where they show a players portrait."]), 1)
		portrait.args.enable = ACH:Toggle(L["Enable"], nil, 2, nil, nil, nil, function(info) return JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-2], info[#info-1]) end)
		portrait.args.style = ACH:Select(L["Style"], nil, 3, iconStyleList, nil, nil, function(info) return JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-2], info[#info-1]) end, function(info) return not JI.db.blizzard[info[#info-2]][info[#info-1]].enable end)

		local background = ACH:Group(L["Background"], nil, 10, nil, nil, 'full', function(info) return not JI.db.blizzard[info[#info-3]][info[#info-2]].enable end)
		portrait.args.background = background
		background.inline = true
		background.args.enable = ACH:Toggle(L["Enable"], nil, 2, nil, nil, nil, function(info) return JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-3], info[#info-2]) end)
		background.args.color = ACH:Color(L["Color"], nil, 10, true, nil, function(info) return unpack(JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]]) end, function(info, r, g, b, a) JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] = { r, g, b, a } JI:UnitFramePortrait_Update(info[#info-3], info[#info-2]) end, function(info) return not JI.db.blizzard[info[#info-3]][info[#info-2]].enable or not JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]].enable end)
		background.args.colorOverride = ACH:Toggle(colorOverrideOptions.name, L["This will override the color option (alpha slider setting is still followed) and force the background color to show as the class color of the unit that is displayed."], 15, true, nil, 'full', function(info) local value = JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] if value == 2 then return true elseif value == 1 then return nil else return false end end, function(info, value) JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]][info[#info]] = (unit ~= 'player' and value and 2) or (unit == 'player' and value and 1) or (value == nil and 1) or 0 JI:UnitFramePortrait_Update(info[#info-3], info[#info-2]) end, function(info) return not JI.db.blizzard[info[#info-3]][info[#info-2]].enable or not JI.db.blizzard[info[#info-3]][info[#info-2]][info[#info-1]].enable end)
	end

	local icon = ACH:Group(L["Icon"], nil, 10)
	blizzard.args[unit].args.icon = icon
	icon.inline = true

	icon.args.header = ACH:Description(ColorText(nil, L["This will add an icon that will show the class of the unit that is displayed in the unitframe that the icon is attached to."]), 1)
	icon.args.enable = ACH:Toggle(L["Enable"], nil, 2, nil, nil, nil, function(info) return JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-2], info[#info-1]) end)
	icon.args.style = ACH:Select(L["Style"], nil, 3, iconStyleList, nil, nil, function(info) return JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-2], info[#info-1]) end, function(info) return not JI.db.blizzard[info[#info-2]][info[#info-1]].enable end)
	icon.args.size = ACH:Range(L["Size"], nil, 5, { min = 8, max = 128, step = 1 }, nil, function(info) return JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-2], info[#info-1]) end, function(info) return not JI.db.blizzard[info[#info-2]][info[#info-1]].enable end)
	icon.args.anchorPoint = ACH:Select(L["Anchor Point"], L["What point to anchor to the frame you set to attach to."], 12, AllPoints, nil, nil, function(info) return JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-2], info[#info-1]) end, function(info) return not JI.db.blizzard[info[#info-2]][info[#info-1]].enable end)
	icon.args.spacer = ACH:Description('', 15)
	icon.args.xOffset = ACH:Range(L["xOffset"], nil, 16, { min = -150, max = 150, step = 1 }, nil, function(info) return JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-2], info[#info-1]) end, function(info) return not JI.db.blizzard[info[#info-2]][info[#info-1]].enable end)
	icon.args.yOffset = ACH:Range(L["yOffset"], nil, 17, { min = -150, max = 150, step = 1 }, nil, function(info) return JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] end, function(info, value) JI.db.blizzard[info[#info-2]][info[#info-1]][info[#info]] = value JI:UnitFramePortrait_Update(info[#info-2], info[#info-1]) end, function(info) return not JI.db.blizzard[info[#info-2]][info[#info-1]].enable end)
end
-- ACH:Toggle(name, desc, order, tristate, confirm, width, get, set, disabled, hidden)
--* Sort unit list manually instead of alphabetically
blizzard.args.player.order = 1
blizzard.args.target.order = 2
blizzard.args.targettarget.order = 3
blizzard.args.focus.order = 4
blizzard.args.focustarget.order = 5
blizzard.args.party.order = 6
-- blizzard.args.raid.order = 7

--* Information Tab
local Information = ACH:Group(L["Information"], nil, 10)
JI.Options.args.Information = Information

Information.args.links = ACH:Group(L["Links"], nil, 1)
Information.args.links.inline = true
Information.args.links.args.discord = ACH:Input(L["Discord"], L["DISCORD_MSG"], 2, nil, 'full', function() return 'https://discord.com/invite/jr5w8ArzAx' end)
Information.args.links.args.issues = ACH:Input(L["Support Tickets"], nil, 3, nil, 'full', function() return 'https://github.com/repooc/ElvUI_JiberishIcons/issues' end)
Information.args.links.args.jiberishui = ACH:Input('JiberishUI', "Go download JiberishUI from Curse! You can try your pick of various ElvUI profiles by using the installer!", 4, nil, 'full', function() return 'https://www.curseforge.com/wow/addons/jiberishui' end)
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
		},
	}
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
	end
	JI.Options.args.profiles = JI.Libs.ADBO:GetOptionsTable(JI.data, true)
	JI.Options.args.profiles.order = -2
end
