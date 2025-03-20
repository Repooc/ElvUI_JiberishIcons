local JI, L = unpack(ElvUI_JiberishIcons)

if not JI:IsAddOnEnabled('ElvUI') then return end

local E = unpack(ElvUI)
local UF = E.UnitFrames

local UnitIsPlayer, UnitClass = UnitIsPlayer, UnitClass
local iconMinSize, iconMaxSize = JI.iconMinSize, JI.iconMaxSize
local classInfo = JI.dataHelper.class
local classStyleInfo = JI.defaultStylePacks.class
local classString = '|T%s%s:%s:%s:0:0:1024:1024:%s|t'

local WarningMsgSent = {}

--! Depreciated tag format
for iconStyle in next, classStyleInfo.styles do
	local tag = format('%s:%s', 'jiberish:icon', iconStyle)

	E:AddTag(tag, 'UNIT_NAME_UPDATE', function(unit, _, args)
		if not UnitIsPlayer(unit) then return end

		local nameplate = unit:match("^nameplate%d+$")
		if nameplate then
			unit = 'nameplate'
		end

		if not WarningMsgSent[unit] then
			E:Print(format('|cffFF3300Warning|r: The tag, %s[%s]|r, is depreciated. Swap all instances of the tag with the new format, %s[jiberish:class:%s]|r.|nThis tag was found on the %s unit, which may help you locate the tag in the config.', E.media.hexvaluecolor, tag, E.media.hexvaluecolor, iconStyle, unit or 'unknown'))
			WarningMsgSent[unit] = true
		end
	end)
end

function JI:BuildElvUITags()
	--! New Format for class icons
	for iconStyle, data in next, JI.mergedStylePacks.class.styles do
		local path = data.path or classStyleInfo.path
		do
			local tag = format('%s:%s', 'jiberish:class', iconStyle)

			E:AddTag(tag, 'UNIT_NAME_UPDATE', function(unit, _, args)
				if not UnitIsPlayer(unit) then return end

				local size = strsplit(':', args or '')
				size = tonumber(size)
				size = (size and (size >= iconMinSize and size <= iconMaxSize)) and size or 64
				local _, class = UnitClass(unit)
				local icon = classInfo[class]

				if icon and icon.texString then
					return format(classString, path, iconStyle, size, size, icon.texString)
				end
			end)

			local description = format(L["TAG_HELP"], data.name or '', JI.Title, tag)
			E:AddTagInfo(tag, JI.Title, description)
		end

		do
			local tag = format('%s:%s:reverse', 'jiberish:class', iconStyle)

			E:AddTag(tag, 'UNIT_NAME_UPDATE', function(unit, _, args)
				if not UnitIsPlayer(unit) then return end

				local size = strsplit(':', args or '')
				size = tonumber(size)
				size = (size and (size >= iconMinSize and size <= iconMaxSize)) and size or 64
				local _, class = UnitClass(unit)
				local icon = classInfo[class]

				if icon and icon.texString then
					local texString = icon.texString

					local x1, x2, y1, y2 = strsplit(':', texString)
					texString = format('%s:%s:%s:%s', x2, x1, y1, y2)
					return format(classString, path, iconStyle, size, size, texString)
				end
			end)

			local description = format(L["TAG_HELP"], data.name or '', JI.Title, tag)
			E:AddTagInfo(tag, JI.Title, description)
		end
	end
end

function JI:PortraitUpdate()
	local element = self
	if not element.useClassBase then return end

	local frame = element.__owner
	local db = JI.db.elvui[frame.unitframeType]

	if db and db.portrait.enable then
		local _, class = UnitClass(frame.unit)
		local icon, style = classInfo[class], db.portrait.style or 'fabled'

		local mergedClassStyles = JI.mergedStylePacks.class
		local path = (mergedClassStyles.styles[style] and mergedClassStyles.styles[style].path) or mergedClassStyles.path
		local fullPath = format('%s%s', path, style)

		--* Fallback to Fabled if it can't find the texture
		if not JI:IsValidTexturePath(fullPath) then fullPath = format('%s%s', mergedClassStyles.path, 'fabled') end

		local texCoords = icon and icon.texCoords or { 0, 1, 0, 1 }

		--* Update Icon Texture
		element:SetTexture(fullPath)
		element:SetTexCoord(unpack(texCoords))

		if db.portrait.backdrop.enable and element.backdrop then
			element.backdrop:SetTemplate(db.portrait.backdrop.transparent and 'Transparent', nil, nil, nil, true)

			if db.portrait.backdrop.colorOverride then
				element.backdrop:SetBackdropColor(unpack(db.portrait.backdrop.color))
			end
		end
	end
end
hooksecurefunc(UF, 'PortraitUpdate', JI.PortraitUpdate)
