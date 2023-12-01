local E = unpack(ElvUI)
local AddOnName, Engine = ...

local module = E:NewModule(AddOnName)
_G[AddOnName] = Engine

local iconStyles = Engine.iconStyles
local minSize, maxSize = Engine.iconMinSize, Engine.iconMaxSize
local classIcon = [[|TInterface\AddOns\ElvUI_JiberishIcons\Media\%s:%s:%s:0:0:512:512:%s|t]]
local classIcons = {
	WARRIOR		= '0:128:0:128',
	MAGE		= '128:256:0:128',
	ROGUE		= '256:384:0:128',
	DRUID		= '384:512:0:128',
	HUNTER		= '0:128:128:256',
	SHAMAN		= '128:256:128:256',
	PRIEST		= '256:384:128:256',
	WARLOCK		= '384:512:128:256',
	PALADIN		= '0:128:256:384',
	DEATHKNIGHT = '128:256:256:384',
	MONK		= '256:384:256:384',
	DEMONHUNTER = '384:512:256:384',
	EVOKER		= '0:128:384:512',
}

for iconStyle, tagTitle in next, iconStyles do
	local tag = format('%s:%s', 'jiberish:icon', iconStyle)

	E:AddTag(tag, 'PLAYER_TARGET_CHANGED', function(unit, _, args)
		if not UnitIsPlayer(unit) then return end
	
		local size = strsplit(':', args or '')
		size = (size and size >= minSize and size <= maxSize) and size or '64'	
		local _, class = UnitClass(unit)
		local icon = classIcons[class]

		if icon then
			return format(classIcon, iconStyle, size, size, icon)
		end
	end)
	
	local description = format("This tag will display the %s icon style from Jiberish's class icon plugin!", tagTitle or '')
	E:AddTagInfo(tag, 'Jiberish', description)
end

function module:Initialize()
	E.Libs.EP:RegisterPlugin(AddOnName)
end

E.Libs.EP:HookInitialize(module, module.Initialize)
