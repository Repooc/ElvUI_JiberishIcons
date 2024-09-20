local JI, L = unpack(ElvUI_JiberishIcons)

if not JI:IsAddOnEnabled('ElvUI') then return end

local E = unpack(ElvUI)
local UF = E.UnitFrames

local UnitIsPlayer, UnitClass = UnitIsPlayer, UnitClass
local iconMinSize, iconMaxSize = JI.iconMinSize, JI.iconMaxSize
local classInfo = JI.icons.class
local classString = '|T%s%s:%s:%s:0:0:1024:1024:%s|t'

for iconStyle, data in next, classInfo.styles do
	-- local tag = format('%s:%s', 'jiberish:class', iconStyle) --! Change to class when spec icons are added
	local tag = format('%s:%s', 'jiberish:icon', iconStyle)

	E:AddTag(tag, 'UNIT_NAME_UPDATE', function(unit, _, args)
		if not UnitIsPlayer(unit) then return end

		local size = strsplit(':', args or '')
		size = tonumber(size)
		size = (size and (size >= iconMinSize and size <= iconMaxSize)) and size or 64
		local _, class = UnitClass(unit)
		local icon = classInfo.data[class]

		if icon and icon.texString then
			return format(classString, classInfo.path, iconStyle, size, size, icon.texString)
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
		local icon = classInfo.data[class]
		local texture = format('%s%s', classInfo.path, db.portrait.style or 'fabled') or nil
		local texCoords = icon and icon.texCoords or { 0, 1, 0, 1 }

		--* Update Icon Texture
		element:SetTexture(texture)
		element:SetTexCoord(unpack(texCoords))
	end
end
hooksecurefunc(UF, 'PortraitUpdate', JI.PortraitUpdate)
