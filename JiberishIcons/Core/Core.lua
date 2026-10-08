JiberishIcons[2] = JiberishIcons[1].Libs.ACL:GetLocale('JiberishIcons', JiberishIcons[1]:GetLocale())
local JI, L = unpack(JiberishIcons)
local AddOnName = ...
local IsAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

local UF = JI:IsAddOnEnabled('ElvUI') and ElvUI[1].UnitFrames or ''
JI.defaultStylePacks = {
	class = {
		path = JI.MediaPath..[[Class\]],
		styles = {
			fabledclass = {
				name = 'Fabled Class',
				textureSize = 2048,
				artist = 'JiberishUI',
				site = 'https://theigloo.io/',
				description = '13 class icons with bold outlines and class-colored effects, designed to match Fabled Specializations.',
			},
			fabled = {
				name = 'Fabled',
				artist = 'Royroyart',
				site = 'https://www.fiverr.com/royyanikhwani',
			},
			fabledcore = {
				name = 'Fabled Core',
				textureSize = 2048,
				artist = 'Penguin aka Jiberish',
				site = 'https://theigloo.io/',
			},
			fableddimension = {
				name = 'Fabled Dimension',
				artist = 'Dragumagu',
				site = 'https://www.artstation.com/dragumagu',
			},
			fabledmyth = {
				name = 'Fabled Myth',
				textureSize = 2048,
				artist = 'Penguin aka Jiberish',
				site = 'https://theigloo.io/',
				description = 'Original Fabled Myth motifs redrawn with bolder silhouettes, cleaner graffiti accents and higher-resolution artwork for small UI sizes.',
			},
			fabledpixels = {
				name = 'Fabled Pixels',
				artist = 'Dragumagu',
				site = 'https://www.artstation.com/dragumagu',
			},
			fabledpixelsv2 = {
				name = 'Fabled Pixels v2',
				artist = 'Dragumagu (Recolor by Caith)',
				site = 'https://www.artstation.com/dragumagu',
			},
			fabledrealm = {
				name = 'Fabled Realm',
				artist = 'Handclaw',
				site = 'https://handclaw.artstation.com/',
			},
			fabledrealmv2 = {
				name = 'Fabled Realm v2',
				artist = 'Handclaw (Recolor by Caith)',
				site = 'https://handclaw.artstation.com/',
			},
			fabledregalia = {
				name = 'Fabled Regalia',
				textureSize = 2048,
				artist = 'JiberishUI',
				site = 'https://theigloo.io/',
				description = "Reinterpretations of Blizzard Entertainment's World of Warcraft class crests, referenced from Blizzard's official website.",
				source = 'https://worldofwarcraft.blizzard.com/en-us/game/classes',
			},
			intothevoid = {
				name = 'Into The VOID',
				artist = 'Handclaw Icons Reimagined by JiberishUI',
				site = 'https://handclaw.artstation.com/',
			},
		}
	},
	race = {
		path = JI.MediaPath..[[Race\]],
		styles = {
			fabledazeroth = {
				name = 'Fabled Azeroth',
				textureSize = 2048,
				artist = 'JiberishUI',
				site = 'https://theigloo.io/',
				description = "Reinterpretations of Blizzard Entertainment's World of Warcraft race crests, referenced from Blizzard's official website.",
				source = 'https://worldofwarcraft.blizzard.com/en-us/game/races',
			},
		},
	},
	spec = {
		path = JI.MediaPath..[[Spec\]],
		styles = {
			fabledspecializations = {
				name = 'Fabled Specializations',
				textureSize = 2048,
				detailsFileName = 'spec_fabledspecializations',
				artist = 'JiberishUI',
				site = 'https://theigloo.io/',
				description = '40 bold specialization symbols with simplified detail for small UI sizes, inspired by Blizzard icons and Fabled Regalia.',
				source = 'https://worldofwarcraft.blizzard.com/en-us/game/classes',
			},
		},
	},
}

function JI:ToggleOptions()
	if JI:IsAddOnEnabled('ElvUI') then
		if InCombatLockdown() then return end
		_G.ElvUI[1]:ToggleOptions()
		JI.Libs.ACD:SelectGroup('ElvUI', 'jiberishicons')
	else
		if SettingsPanel and SettingsPanel:IsShown() then
			SettingsPanel:ExitWithCommit(true)
			return
		end

		local ConfigOpen = JI.Libs.ACD.OpenFrames and JI.Libs.ACD.OpenFrames[JI.AddOnName]
		if ConfigOpen and ConfigOpen.frame then
			JI.Libs.ACD:Close(JI.AddOnName)
		else
			JI.Libs.ACD:Open(JI.AddOnName)
		end
	end
end

local function SendLoginMessage()
	if JI.db.hideLoginMessage then return end
	local msg = format(L["LOGIN_MSG"], JI.Title)
	print(msg)
end

function JI:Init(event, addon)
	if event == 'ADDON_LOADED' and addon == 'Details' and JI.Initialized then
		JI:SetupDetails()
	end
	if event == 'ADDON_LOADED' and (JI.Initialized or IsAddOnLoaded(AddOnName)) then
		if addon == AddOnName then
			JI.Initialized = true
			JI:BuildProfile()

			JI:SetupDetails()
			JI:SetupDamageMeters()
			JI:SetupBlizzardFrames() --* Setup class icon icon for frames
			JI:Setup_Eltruism()
			JI:SetupEltruismIconPacks()
			JI:SetupSUF()
			JI:SetupEllesmereUI()
			JI:SetupPortraits()
			JI:SetupSpecializationIcons()

			JI:RegisterChatCommand('ji', 'ToggleOptions')
			JI:RegisterChatCommand('jib', 'ToggleOptions')
			JI:RegisterChatCommand('jiberishicons', 'ToggleOptions')
		end
	end

	if event == 'PLAYER_LOGIN' then
		JI:SetupDetails()
		JI:SetupDamageMeters()
		JI:BuildOptions()
		JI:SetupChatCache()
		JI:ToggleChat()

		JI:RegisterEvent('PLAYER_ENTERING_WORLD', SendLoginMessage)
		JI:SecureHook('UnitFramePortrait_Update', 'UnitFramePortrait_Update')

		if JI:IsAddOnEnabled('ElvUI') then
			JI:BuildElvUITags()
		end

		-- TODO: Add support for raid frames
		-- JI:RegisterEvent('GROUP_ROSTER_UPDATE', 'UpdateBlizzardRaidFrames')
	end
end

JI:RegisterEvent('ADDON_LOADED', 'Init')
JI:RegisterEvent('PLAYER_LOGIN', 'Init')
