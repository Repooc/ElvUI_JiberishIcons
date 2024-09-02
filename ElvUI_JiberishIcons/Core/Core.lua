ElvUI_JiberishIcons[2] = ElvUI_JiberishIcons[1].Libs.ACL:GetLocale('JiberishIcons', ElvUI_JiberishIcons[1]:GetLocale())
local JI, L = unpack(ElvUI_JiberishIcons)
local AddOnName = ...
local blizzOptionsOpen, separateOptionsOpen = false, false
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded or IsAddOnLoaded

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

function JI:Init(event, addon)
	if event == 'ADDON_LOADED' and (JI.Initialized or IsAddOnLoaded(AddOnName)) then
		if addon == AddOnName then
			JI.Initialized = true
			JI:BuildProfile()

			JI:SetupDetails()
			JI:SetupBlizzardFrames() --* Setup class icon icon for frames
			JI:SetupSUF()

			JI:RegisterChatCommand('ji', 'ToggleOptions')
			JI:RegisterChatCommand('jiberishicons', 'ToggleOptions')
		end
	end

	if event == 'PLAYER_LOGIN' then
		JI:BuildOptions()
		JI:SetupChatCache()
		JI:ToggleChat()

		JI:RegisterEvent('PLAYER_ENTERING_WORLD', function() print(L["LOGIN_MSG"]) end)
		JI:SecureHook('UnitFramePortrait_Update', 'UnitFramePortrait_Update')

		-- TODO: Add support for raid frames
		-- JI:RegisterEvent('GROUP_ROSTER_UPDATE', 'UpdateBlizzardRaidFrames')
	end
end

JI:RegisterEvent('ADDON_LOADED', 'Init')
JI:RegisterEvent('PLAYER_LOGIN', 'Init')
