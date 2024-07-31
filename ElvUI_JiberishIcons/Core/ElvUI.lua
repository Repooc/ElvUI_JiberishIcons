local JI, L = unpack(ElvUI_JiberishIcons)
if not JI:IsAddOnEnabled('ElvUI') then return end

local E = unpack(ElvUI)
local UF = E.UnitFrames

local UnitIsPlayer, UnitClass = UnitIsPlayer, UnitClass
local iconMinSize, iconMaxSize = JI.iconMinSize, JI.iconMaxSize
local classIconPath, classData, iconStyles = JI.classIconPath, JI.classData, JI.iconStyles
local displayString = '|T%s%s:%s:%s:0:0:1024:1024:%s|t'

for iconStyle, data in next, iconStyles do
	local tag = format('%s:%s', 'jiberish:icon', iconStyle)

	E:AddTag(tag, 'UNIT_NAME_UPDATE', function(unit, _, args)
		if not UnitIsPlayer(unit) then return end

		local size = strsplit(':', args or '')
		size = tonumber(size)
		size = (size and (size >= iconMinSize and size <= iconMaxSize)) and size or 64
		local _, class = UnitClass(unit)
		local icon = classData[class]

		if icon and icon.texString then
			return format(displayString, classIconPath, iconStyle, size, size, icon.texString)
		end
	end)

	local description = format(L["TAG_HELP"], data.name or '', JI.Title, tag)
	E:AddTagInfo(tag, JI.Title, description)
end

function JI:PortraitUpdate()
	local element = self
	if not element.useClassBase then return end

	local frame = element.__owner
	local db = JI.db.elvui[frame.unitframeType]

	if db and db.portrait.enable then
		local _, class = UnitClass(frame.unit)
		local icon = classData[class]

		--* Update Icon Texture
		element:SetTexture(format('%s%s', classIconPath, db.portrait.style or 'fabled'))
		element:SetTexCoord(unpack(icon.texCoords))
	end
end
hooksecurefunc(UF, 'PortraitUpdate', JI.PortraitUpdate)

