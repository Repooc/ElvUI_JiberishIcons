local JI, L = unpack(ElvUI_JiberishIcons)
if not JI:IsAddOnEnabled('ElvUI') then return end

local E = unpack(ElvUI)

local UnitIsPlayer, UnitClass = UnitIsPlayer, UnitClass
local iconMinSize, iconMaxSize = JI.iconMinSize, JI.iconMaxSize
local classIconPath, classIcons, iconStyles = JI.classIconPath, JI.classIcons, JI.iconStyles
local displayString = '|T%s%s:%s:%s:0:0:1024:1024:%s|t'

for iconStyle, data in next, iconStyles do
	local tag = format('%s:%s', 'jiberish:icon', iconStyle)

	E:AddTag(tag, 'UNIT_NAME_UPDATE', function(unit, _, args)
		if not UnitIsPlayer(unit) then return end

		local size = strsplit(':', args or '')
		size = tonumber(size)
		size = (size and (size >= iconMinSize and size <= iconMaxSize)) and size or 64
		local _, class = UnitClass(unit)
		local icon = classIcons[class]

		if icon and icon.texString then
			return format(displayString, classIconPath, iconStyle, size, size, icon.texString)
		end
	end)

	local description = format(L["TAG_HELP"], data.name or '', JI.Title, tag)
	E:AddTagInfo(tag, JI.Title, description)
end
