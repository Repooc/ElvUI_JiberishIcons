local JI, L = unpack(ElvUI_JiberishIcons)

if not JI:IsAddOnEnabled('ElvUI') then return end

local E = unpack(ElvUI)
local UF = E.UnitFrames

local UnitIsPlayer = UnitIsPlayer
local iconMinSize, iconMaxSize = JI.iconMinSize, JI.iconMaxSize
local classStyleInfo = JI.defaultStylePacks.class

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
	for _, kind in ipairs({ 'class', 'race' }) do
		for iconStyle, data in pairs(JI.mergedStylePacks[kind].styles) do
			for _, reverse in ipairs({ false, true }) do
				local tag = format('jiberish:%s:%s%s', kind, iconStyle, reverse and ':reverse' or '')
				E:AddTag(tag, 'UNIT_NAME_UPDATE UNIT_PORTRAIT_UPDATE', function(unit, _, args)
					local size = tonumber(strsplit(':', args or ''))
					size = (size and size >= iconMinSize and size <= iconMaxSize) and size or 64
					local icon, path, textureSize = JI:GetUnitIcon(unit, iconStyle)
					if icon then
						return JI:GetIconMarkup(icon, path, size, reverse, textureSize)
					end
				end)
				E:AddTagInfo(tag, JI.Title, format(L["TAG_HELP"], data.name or '', JI.Title, tag))
			end
		end
	end
end

function JI:PortraitUpdate()
	local element = self
	if not element.useClassBase then return end

	local frame = element.__owner
	local db = JI.db.elvui[frame.unitframeType]

	if db and db.portrait.enable then
		local icon, fullPath = JI:GetUnitIcon(frame.unit, db.portrait.style)
		if not icon then element:SetTexture(nil); return end

		--* Update Icon Texture
		element:SetTexture(fullPath)
		element:SetTexCoord(JI:GetIconTexCoords(icon.texCoords, db.portrait.reverse))

		if db.portrait.backdrop.enable and element.backdrop then
			element.backdrop:SetTemplate(db.portrait.backdrop.transparent and 'Transparent', nil, nil, nil, true)

			if db.portrait.backdrop.colorOverride then
				element.backdrop:SetBackdropColor(unpack(db.portrait.backdrop.color))
			end
		end
	end
end
hooksecurefunc(UF, 'PortraitUpdate', JI.PortraitUpdate)
