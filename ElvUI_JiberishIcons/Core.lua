local AddOnName, Engine = ...
_G[AddOnName] = Engine

local E = unpack(ElvUI)
local module = E:NewModule(AddOnName)
module.Version = GetAddOnMetadata(AddOnName, 'Version')
module.Title = GetAddOnMetadata(AddOnName, 'Title')
module.Configs = {}

local iconMinSize, iconMaxSize = Engine.iconMinSize, Engine.iconMaxSize
local classIconPath, classIcons, iconStyles = Engine.classIconPath, Engine.classIcons, Engine.iconStyles

local function GetOptions()
	for _, func in pairs(module.Configs) do
		func()
	end
end

for iconStyle, data in next, iconStyles do
	local tag = format('%s:%s', 'jiberish:icon', iconStyle)

	E:AddTag(tag, 'PLAYER_TARGET_CHANGED', function(unit, _, args)
		if not UnitIsPlayer(unit) then return end
	
		local size = strsplit(':', args or '')
		size = tonumber(size)
		size = (size and (size >= iconMinSize and size <= iconMaxSize)) and size or 64	
		local _, class = UnitClass(unit)
		local icon = classIcons[class]

		if icon then
			return format(classIconPath, iconStyle, size, size, icon)
		end
	end)
	
	local description = format("This tag will display the %s icon style from %s plugin! Optional size arg is supported. Example: [%s{32}]", data.style or '', module.Title, tag)
	E:AddTagInfo(tag, module.Title, description)
end

function module:Initialize()
	E.Libs.EP:RegisterPlugin(AddOnName, GetOptions)
end

E.Libs.EP:HookInitialize(module, module.Initialize)
