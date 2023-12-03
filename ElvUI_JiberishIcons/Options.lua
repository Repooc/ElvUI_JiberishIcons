local E = unpack(ElvUI)
local ACH = E.Libs.ACH
local AddOnName, Engine = ...
local module = E:GetModule(AddOnName)

local classIconPath, classIcons, iconStyles = Engine.classIconPath, Engine.classIcons, Engine.iconStyles

local CREDITS = {
	'|cfff48cbaRepooc|r',
	E:TextGradient('Eltreum', 0.50, 0.70, 1, 0.67, 0.95, 1),
	E:TextGradient('Blinkii', 0, 0.64, 1, 0, 0.80, 1, 0, 0.968, 1),
	'|cffff2f3cTrenchy|r',
	'|cff39FF14MaximumOverdrive|r',
	'|cFF08E8DEBotanica|r',
	'|cffb8bb26Thurin|r',
	'|cffd19d3bPat|r',
	'|cffffb300Madlampy|r',
}

local function SortList(a, b)
	return E:StripString(a) < E:StripString(b)
end
sort(CREDITS, SortList)
CREDITS = table.concat(CREDITS, '|n')

local function configTable()
	--* Listing in the Plugin Section
	local JiberishIcons = ACH:Group(module.Title, nil, nil, 'tab')
	E.Options.args.jiberishicons = JiberishIcons

	--* Main Panel
	JiberishIcons.args.logo = ACH:Description(nil, 0, nil, [[Interface\AddOns\ElvUI_JiberishIcons\Media\LargeLogo]], nil, 256, 128)
	JiberishIcons.args.version = ACH:Header(module.Version, 1)

	--* Style Packs Tab
	local StylePacks = ACH:Group('Style Packs', nil, 5)
	JiberishIcons.args.StylePacks = StylePacks	
	local StyleGroup
	for iconStyle, tagTitle in next, iconStyles do
		StyleGroup = ACH:Group(tagTitle)
		StylePacks.args[iconStyle] = StyleGroup
		StyleGroup.inline = true
		
		local classTextureString = ''
		for _, texcoords in next, classIcons do
			classTextureString = classTextureString..format(classIconPath, iconStyle, '48', '48', texcoords)
		end
		StyleGroup.args[iconStyle] = ACH:Description(function() return classTextureString end, 1, nil, nil, nil, nil, nil)
	end

	--* Information Tab
	local Information = ACH:Group('Information', nil, 10)
	JiberishIcons.args.Information = Information
	Information.args.discord = ACH:Execute('Discord', "Come join the Discord server and share your ui with everyone, and maybe try someone else's...?", 1, function() E:StaticPopup_Show('ELVUI_EDITBOX', nil, nil, 'https://discord.com/invite/jr5w8ArzAx') end, nil, nil, 140)
	Information.args.jiberishui = ACH:Execute('JiberishUI', "Go download JiberishUI from Curse! You can try your pick of various ElvUI profiles by using the installer!", 2, function() E:StaticPopup_Show('ELVUI_EDITBOX', nil, nil, 'https://www.curseforge.com/wow/addons/jiberishui') end, nil, nil, 140)
	Information.args.wagoprofile = ACH:Execute("Wago Profile", "Looking for some nice profile strings for ElvUI? Go check out my wago profile for some nice profiles!", 3, function() E:StaticPopup_Show('ELVUI_EDITBOX', nil, nil, 'https://wago.io/p/Jiberish%231723') end, nil, nil, 140)

	local Credits = ACH:Group("Fabled Incarnates", nil, 10)
	Information.args.Credits = Credits
	Credits.inline = true
	Credits.args.credits = ACH:Description(CREDITS, 1, 'medium')
end

tinsert(module.Configs, configTable)
