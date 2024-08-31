local JI, L = unpack(ElvUI_JiberishIcons)

function JI:SetupElvUI()
	if not JI:IsAddOnEnabled('ElvUI') then return end
	JI:ToggleElvUIChat()
end

if not JI:IsAddOnEnabled('ElvUI') then return end

local E = unpack(ElvUI)
local UF = E.UnitFrames
local CH = E.Chat

local UnitIsPlayer, UnitClass = UnitIsPlayer, UnitClass
local iconMinSize, iconMaxSize = JI.iconMinSize, JI.iconMaxSize
local classInfo = JI.icons.class
local classString = '|T%s%s:%s:%s:0:0:1024:1024:%s|t'

for iconStyle, data in next, classInfo.styles do
	local tag = format('%s:%s', 'jiberish:class', iconStyle)

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

		--* Update Icon Texture
		element:SetTexture(format('%s%s', classInfo.path, db.portrait.style or 'fabled'))
		element:SetTexCoord(unpack(icon.texCoords))
	end
end
hooksecurefunc(UF, 'PortraitUpdate', JI.PortraitUpdate)

function JI:GetPFlag(specialFlag, zoneChannelID, unitGUID)
	local flag = JI.hooks[CH]:GetPFlag(specialFlag, zoneChannelID, unitGUID) or ''
	if unitGUID then
		local iconString = ''
		local _, class = GetPlayerInfoByGUID(unitGUID)
		local icon = classInfo.data[class]
		local db = JI.db.chat

		if icon and icon.texString then
			iconString = format('|T%s%s:0:0:0:0:1024:1024:%s|t', classInfo.path, db.style, icon.texString)
		end
		flag = flag .. iconString
	end

	return flag
end

function JI:ToggleElvUIChat()
	local db = JI.db.chat

	if db.enable and not JI:IsHooked(CH, 'GetPFlag') then
		JI:RawHook(CH, 'GetPFlag', JI.GetPFlag, true)
	elseif not db.enable and JI:IsHooked(CH, 'GetPFlag') then
		JI:Unhook(CH, 'GetPFlag')
	end
end
