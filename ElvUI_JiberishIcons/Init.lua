local AddOnName, Engine = ...
local JI = _G.LibStub('AceAddon-3.0'):NewAddon(AddOnName, 'AceConsole-3.0', 'AceEvent-3.0', 'AceHook-3.0')

Engine[1] = JI
Engine[2] = {}

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
JI.GuidCache = {}
JI.AuthorCache = {}

JI.locale = GetLocale()
do -- this is different from E.locale because we need to convert for ace locale files
	local convert = { enGB = 'enUS', esES = 'esMX', itIT = 'enUS' }
	local gameLocale = convert[JI.locale] or JI.locale or 'enUS'

	function JI:GetLocale()
		return gameLocale
	end
end

JI.icons = {
	class = {
		path = [[Interface\AddOns\ElvUI_JiberishIcons\Media\Class\]],
		styles = {
			fabled = {
				name = 'Fabled',
				artist = 'Royroyart',
				site = 'https://www.fiverr.com/royyanikhwani',
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
		},
		data = {
			WARRIOR	= {
				texString = '0:128:0:128',
				texCoords = { 0, 0, 0, 0.125, 0.125, 0, 0.125, 0.125 },
			},
			MAGE = {
				texString = '128:256:0:128',
				texCoords = { 0.125, 0, 0.125, 0.125, 0.25, 0, 0.25, 0.125 },
			},
			ROGUE = {
				texString = '256:384:0:128',
				texCoords = { 0.25, 0, 0.25, 0.125, 0.375, 0, 0.375, 0.125 },
			},
			DRUID = {
				texString = '384:512:0:128',
				texCoords = { 0.375, 0, 0.375, 0.125, 0.5, 0, 0.5, 0.125 },
			},
			EVOKER = {
				texString = '512:640:0:128',
				texCoords = { 0.5, 0, 0.5, 0.125, 0.625, 0, 0.625, 0.125 },
			},
			HUNTER = {
				texString = '0:128:128:256',
				texCoords = { 0, 0.125, 0, 0.25, 0.125, 0.125, 0.125, 0.25 },
			},
			SHAMAN = {
				texString = '128:256:128:256',
				texCoords = { 0.125, 0.125, 0.125, 0.25, 0.25, 0.125, 0.25, 0.25 },
			},
			PRIEST = {
				texString = '256:384:128:256',
				texCoords = { 0.25, 0.125, 0.25, 0.25, 0.375, 0.125, 0.375, 0.25 },
			},
			WARLOCK = {
				texString = '384:512:128:256',
				texCoords = { 0.375, 0.125, 0.375, 0.25, 0.5, 0.125, 0.5, 0.25 },
			},
			PALADIN = {
				texString = '0:128:256:384',
				texCoords = { 0, 0.25, 0, 0.375, 0.125, 0.25, 0.125, 0.375 },
			},
			DEATHKNIGHT = {
				texString = '128:256:256:384',
				texCoords = { 0.125, 0.25, 0.125, 0.375, 0.25, 0.25, 0.25, 0.375 },
			},
			MONK = {
				texString = '256:384:256:384',
				texCoords = { 0.25, 0.25, 0.25, 0.375, 0.375, 0.25, 0.375, 0.375 },
			},
			DEMONHUNTER = {
				texString = '384:512:256:384',
				texCoords = { 0.375, 0.25, 0.375, 0.375, 0.5, 0.25, 0.5, 0.375 },
			},
		}
	},
}

JI.iconMinSize = 1
JI.iconMaxSize = 128

-- JI.classIconPath = [[|TInterface\AddOns\ElvUI_JiberishIcons\Media\Icons\%s:%s:%s:0:0:1024:1024:%s|t]]
-- texCoords = { ULx, ULy, LLx, LLy, URx, URy, LRx, LRy }
