local AddOnName, Engine = ...
local JI = _G.LibStub('AceAddon-3.0'):NewAddon(AddOnName, 'AceConsole-3.0', 'AceEvent-3.0', 'AceHook-3.0')
JI.DF = { profile = {}, global = {} }

Engine[1] = JI						-- JI
Engine[2] = {}						-- L
Engine[3] = JI.DF.profile			-- P
Engine[4] = JI.DF.global			-- G

_G.ElvUI_JiberishIcons = Engine

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

local GetAddOnMetadata = C_AddOns.GetAddOnMetadata or GetAddOnMetadata

JI.Title = GetAddOnMetadata(AddOnName, 'Title')
JI.Version = tonumber(GetAddOnMetadata(AddOnName, 'Version'))
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

--* Personal Reference
-- JI.classIconPath = [[|TInterface\AddOns\ElvUI_JiberishIcons\Media\Icons\%s:%s:%s:0:0:1024:1024:%s|t]]
-- texCoords = { ULx, ULy, LLx, LLy, URx, URy, LRx, LRy }

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

function JI:MergeStylePacks()
	wipe(JI.mergedStylePacks)
	JI:CopyTable(JI.mergedStylePacks, JI.defaultStylePacks)
	JI:CopyTable(JI.mergedStylePacks, JI.global.customPacks, true)
end

local C_AddOns_GetAddOnEnableState = C_AddOns and C_AddOns.GetAddOnEnableState
local GetAddOnEnableState = GetAddOnEnableState -- eventually this will be on C_AddOns and args swap

function JI:IsAddOnEnabled(addon)
	if C_AddOns_GetAddOnEnableState then
		return C_AddOns_GetAddOnEnableState(addon, JI.myName) == 2
	else
		return GetAddOnEnableState(JI.myName, addon) == 2
	end
end

function JI:Print(...)
	_G.DEFAULT_CHAT_FRAME:AddMessage(strjoin('', JI.Title, ':|r ', ...))
end
