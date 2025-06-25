ElvUI_JiberishIcons[2] = ElvUI_JiberishIcons[1].Libs.ACL:GetLocale('JiberishIcons', ElvUI_JiberishIcons[1]:GetLocale())
local JI, L = unpack(ElvUI_JiberishIcons)
local AddOnName = ...
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded or IsAddOnLoaded

local UF = JI:IsAddOnEnabled('ElvUI') and ElvUI[1].UnitFrames or ''
JI.defaultStylePacks = {
	class = {
		path = [[Interface\AddOns\ElvUI_JiberishIcons\Media\Class\]],
		styles = {
			fabled = {
				name = 'Fabled',
				artist = 'Royroyart',
				site = 'https://www.fiverr.com/royyanikhwani',
			},
			fabledcore = {
				name = 'Fabled Core',
				artist = 'Penguin aka Jiberish',
				site = 'https://jiberishui.com/',
			},
			fableddimension = {
				name = 'Fabled Dimension',
				artist = 'Dragumagu',
				site = 'https://www.artstation.com/dragumagu',
			},
			fabledmyth = {
				name = 'Fabled Myth',
				artist = 'Penguin aka Jiberish',
				site = 'https://jiberishui.com/',
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
			intothevoid = {
				name = 'Into The VOID',
				artist = 'Handclaw Icons Reimagined by JiberishUI',
				site = 'https://handclaw.artstation.com/',
			},
		}
	}
}

function JI:ToggleOptions()
	if JI:IsAddOnEnabled('ElvUI') then
		if InCombatLockdown() then return end
		_G.ElvUI[1]:ToggleOptions()
		JI.Libs.ACD:SelectGroup('ElvUI', 'jiberishicons')
	else
		if SettingsPanel:IsShown() then
			SettingsPanel:ExitWithCommit(true)
			return
		end

		local ConfigOpen = JI.Libs.ACD.OpenFrames and JI.Libs.ACD.OpenFrames.ElvUI_JiberishIcons
		if ConfigOpen and ConfigOpen.frame then
			JI.Libs.ACD:Close('ElvUI_JiberishIcons')
		else
			JI.Libs.ACD:Open('ElvUI_JiberishIcons')
		end
	end
end

local function SendLoginMessage()
	if JI.db.hideLoginMessage then return end
	local msg = format(L["LOGIN_MSG"], JI.Title)
	print(msg)
end

function JI:Init(event, addon)
	if event == 'ADDON_LOADED' and (JI.Initialized or IsAddOnLoaded(AddOnName)) then
		if addon == AddOnName then
			JI.Initialized = true
			JI:BuildProfile()

			JI:SetupDetails()
			JI:SetupBlizzardFrames() --* Setup class icon icon for frames
			JI:Setup_mMediaTag()
			JI:SetupSUF()

			JI:RegisterChatCommand('ji', 'ToggleOptions')
			JI:RegisterChatCommand('jib', 'ToggleOptions')
			JI:RegisterChatCommand('jiberishicons', 'ToggleOptions')
		end
	end

	if event == 'PLAYER_LOGIN' then
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
