local JI = unpack(ElvUI_JiberishIcons)

local classIconPath, classIcons, iconStyles = JI.classIconPath, JI.classIcons, JI.iconStyles
local cachedPortraits = {}

local INVERSE = {
	InverseAnchors = {
		BOTTOM = 'TOP',
		BOTTOMLEFT = 'TOPRIGHT',
		BOTTOMRIGHT = 'TOPLEFT',
		CENTER = 'CENTER',
		LEFT = 'RIGHT',
		RIGHT = 'LEFT',
		TOP = 'BOTTOM',
		TOPLEFT = 'BOTTOMRIGHT',
		TOPRIGHT = 'BOTTOMLEFT'
	}
}

function JI:UpdateSUF(specific)
	for frame, unit in next, cachedPortraits do
		if specific and unit == specific then
			ShadowUF.Layout:Reload(unit)
		elseif not specific then
			ShadowUF.Layout:Reload(unit)
		end
	end
end

local function UpdateIcon(frame)
	if not frame or not frame.classIcon then return end
	local unit = cachedPortraits[frame]
	local db = JI.db.suf[unit]

	if db then
		local _, class = UnitClass(frame.unit)
		local icon = classIcons[class]

		if icon and UnitIsPlayer(frame.unit) and not frame.unit ~= 'pet' then
			--* Update Icon Holder Frame
			frame.classIcon:SetSize(db.icon.size, db.icon.size)
			frame.classIcon:ClearAllPoints()
			frame.classIcon:SetPoint(INVERSE.InverseAnchors[db.icon.anchorPoint], frame, db.icon.anchorPoint, db.icon.xOffset, db.icon.yOffset)

			--* Update Icon Texture
			frame.classIcon.icon:SetTexture(format('%s%s', classIconPath, db.icon.style))
			frame.classIcon.icon:SetTexCoord(unpack(icon.texCoords))

			frame.classIcon:SetShown(db.icon.enable)
		elseif frame.classIcon then
			frame.classIcon:Hide()
		end
	end
end

local function CreateIcon(frame)
	if frame.classIcon then return end

	frame.classIcon = CreateFrame('Frame', nil, frame)
	frame.classIcon:SetPoint('LEFT', frame, 'RIGHT', 0, 0)
	frame.classIcon:SetSize(32, 32)
	frame.classIcon:SetFrameLevel(700)

	--! Possible mask support in the furture
	-- frame.classIcon.background = frame.classIcon:CreateTexture(nil, 'ARTWORK', nil, 1)
	-- frame.classIcon.background:SetAllPoints(frame.classIcon)
	-- frame.classIcon.background:SetTexture([[Interface\Tooltips\UI-Tooltip-Background]])

	frame.classIcon.icon = frame.classIcon:CreateTexture(nil, 'ARTWORK', nil, 2)
	frame.classIcon.icon:SetAllPoints(frame.classIcon)

	--! Possible mask support in the furture
	-- frame.classIcon.mask = frame.classIcon:CreateMaskTexture()
	-- frame.classIcon.mask:SetAllPoints(frame.classIcon.background)
	-- frame.classIcon.mask:SetTexture([[Interface\CHARACTERFRAME\TempPortraitAlphaMask]], 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE')

	--! Possible mask support in the furture
	-- frame.classIcon.background:AddMaskTexture(frame.classIcon.mask)
	-- frame.classIcon.icon:AddMaskTexture(frame.classIcon.mask)
end

local function UpdateSUFPortrait(module, frame)
	if not frame or not frame.unitType then return end
	local unit = strmatch(frame.unit, 'party') and 'party' or frame.unit
	local db = JI.db.suf[unit]

	local type = ShadowUF.db.profile.units[frame.unitType].portrait.type
	if not type then return end

	if not cachedPortraits[frame] then cachedPortraits[frame] = frame.unitType end

	if not frame.classIcon then
		CreateIcon(frame)
	end
	UpdateIcon(frame)

	if type ~= 'class' then return end

	if db and db.portrait.enable then
		local classToken = frame:UnitClassToken()
		local icon = classIcons[classToken]
		if icon then
			frame.portrait:SetTexture(format('%s%s', classIconPath, db.portrait.style))
			frame.portrait:SetTexCoord(unpack(icon.texCoords))
		end
	elseif not db.portrait.enable and frame.portrait.SetTexCoord then
		frame.portrait:SetTexCoord(0, 1, 0, 1)
	end
end

function JI:SetupSUF()
	if not JI:IsAddOnEnabled('ShadowedUnitFrames') then return end
	JI:SecureHook(ShadowUF.modules.portrait, 'Update', UpdateSUFPortrait)
end
