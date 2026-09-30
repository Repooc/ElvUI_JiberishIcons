local AddOnName, Engine = ...
local JI = _G.LibStub('AceAddon-3.0'):NewAddon(AddOnName, 'AceConsole-3.0', 'AceEvent-3.0', 'AceHook-3.0')
JI.DF = { profile = {}, global = {} }

Engine[1] = JI						-- JI
Engine[2] = {}						-- L
Engine[3] = JI.DF.profile			-- P
Engine[4] = JI.DF.global			-- G

_G.JiberishIcons = Engine
_G.ElvUI_JiberishIcons = Engine -- Compatibility for existing external style packs.
_G.JiberishFabledIcons = Engine
JI.AddOnName = AddOnName
JI.MediaPath = 'Interface\\AddOns\\'..AddOnName..'\\Media\\'

JI.Libs = {
	AC = _G.LibStub('AceConfig-3.0'),
	ACD = _G.LibStub('AceConfigDialog-3.0-ElvUI', true) or _G.LibStub('AceConfigDialog-3.0'),
	ACH = _G.LibStub('LibAceConfigHelper'),
	ADB = _G.LibStub('AceDB-3.0'),
	ADBO = _G.LibStub('AceDBOptions-3.0'),
	ACL = _G.LibStub('AceLocale-3.0-ElvUI', true) or _G.LibStub('AceLocale-3.0'),
	EP = _G.LibStub('LibElvUIPlugin-1.0', true),
	ACR = _G.LibStub('AceConfigRegistry-3.0'),
	GUI = _G.LibStub('AceGUI-3.0'),
}

local GetAddOnMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

JI.Title = GetAddOnMetadata(AddOnName, 'Title')
JI.Version = GetAddOnMetadata(AddOnName, 'Version')
JI.Configs = {}
JI.myName = UnitName('player')
JI.myRealm = GetRealmName()
JI.myNameRealm = format('%s - %s', JI.myName, JI.myRealm) -- for profile keys
JI.GuidCache = {}
JI.AuthorCache = {}
JI.mergedStylePacks = {}

JI.locale = GetLocale()
do -- this is different from E.locale because we need to convert for ace locale files
	local convert = { enGB = 'enUS', esES = 'esMX', itIT = 'enUS' }
	local gameLocale = convert[JI.locale] or JI.locale or 'enUS'

	function JI:GetLocale()
		return gameLocale
	end
end

JI.iconMinSize = 1
JI.iconMaxSize = 128

function JI:IsValidTexturePath(path)
	if not path then return false end

	local textureTest = CreateFrame('Frame'):CreateTexture(nil, 'OVERLAY')
	textureTest:SetTexture(path)
	local isValid = textureTest:GetTexture() ~= nil
	textureTest:SetTexture(nil)

	return isValid
end

function JI:ValidateStylePack(styleData, style)
	if not styleData or not styleData.path or not styleData.fileName then return false end
	local fullPath = styleData.path..styleData.fileName
	return JI:IsValidTexturePath(fullPath)
end

-- Saved settings keep their table name. Update paths owned by this addon after
-- users copy the old SavedVariables file to JiberishIcons.lua during upgrade.
function JI:MigrateLegacyMediaPaths()
	local legacy = [[Interface\AddOns\ElvUI_JiberishIcons\]]
	local current = 'Interface\\AddOns\\'..JI.AddOnName..'\\'
	local function migrate(data)
		if type(data) ~= 'table' or type(data.path) ~= 'string' then return end
		local path = data.path:gsub('/', '\\')
		if path:sub(1, #legacy):lower() == legacy:lower() then
			data.path = current..path:sub(#legacy + 1)
		end
	end
	for _, kind in pairs(JI.global.customPacks or {}) do
		for _, data in pairs(kind.styles or {}) do migrate(data) end
	end
	for _, data in pairs(JI.global.newStyleInfo or {}) do migrate(data) end
end

function JI:MergeStylePacks()
	wipe(JI.mergedStylePacks)

	-- First copy all default style packs
	JI:CopyTable(JI.mergedStylePacks, JI.defaultStylePacks)

	-- Then merge custom packs, but only if they don't override existing keys
	if JI.global and JI.global.customPacks and JI.global.customPacks.class and JI.global.customPacks.class.styles then
		for key, data in pairs(JI.global.customPacks.class.styles) do
			-- Only add custom styles if they don't already exist in default styles
			if not JI:GetStyleInfo(key) then
				-- Validate the style pack before adding it
				if JI:ValidateStylePack(data) then
					JI.mergedStylePacks.class.styles[key] = JI:CopyTable({}, data)
				end
			end
		end
	end
	JI:ClearIconStyleCache()
	if JI.UpdateEllesmereUI then JI:UpdateEllesmereUI() end
	if JI.UpdateDamageMeters then JI:UpdateDamageMeters() end
end

local C_AddOns_GetAddOnEnableState = C_AddOns and C_AddOns.GetAddOnEnableState
local GetAddOnEnableState = GetAddOnEnableState -- eventually this will be on C_AddOns and args swap
local IsAddOnLoaded = (_G.C_AddOns and _G.C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
function JI:IsAddOnEnabled(addon)
    -- Enabled addons can still be incompatible or not loaded, including on
    -- Forever's modern client. Only access an integration after it has loaded.
    if IsAddOnLoaded then
        return IsAddOnLoaded(addon) and true or false
    elseif C_AddOns_GetAddOnEnableState then
        return C_AddOns_GetAddOnEnableState(addon, JI.myName) == 2
    elseif GetAddOnEnableState then
        return GetAddOnEnableState(JI.myName, addon) == 2
    end
    return false
end

function JI:Print(...)
	_G.DEFAULT_CHAT_FRAME:AddMessage(strjoin('', JI.Title, ':|r ', ...))
end
