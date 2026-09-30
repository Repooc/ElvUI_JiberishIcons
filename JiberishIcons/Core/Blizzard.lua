local JI = unpack(JiberishIcons)

local UnitClass, UnitIsPlayer = UnitClass, UnitIsPlayer
local classStyleInfo = JI.defaultStylePacks.class
local cachedBlizzardPortraits, cachedBlizzardClassIcons = {}, {}
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

local function LayoutIcon(frame, db)
	if InCombatLockdown() then return end
	frame.classIcon:SetSize(db.size, db.size)
	frame.classIcon:ClearAllPoints()
	frame.classIcon:SetPoint(INVERSE.InverseAnchors[db.anchorPoint], frame, db.anchorPoint, db.xOffset, db.yOffset)
end

local function UpdateIcon(frame)
	if not frame or not frame.classIcon then return end
	local unit = cachedBlizzardClassIcons[frame]
	local db = JI.db.blizzard[unit]

	if db then
		if not db.icon.enable then frame.classIcon:Hide(); return end
		-- Prepare placement even when the specialization is still being inspected.
		LayoutIcon(frame, db.icon)
		local icon, fullPath = JI:GetUnitIcon(frame.unit, db.icon.style)

		if icon and frame.unit ~= 'pet' then

			--* Update Icon Texture
			frame.classIcon.icon:SetTexture(fullPath)
			frame.classIcon.icon:SetTexCoord(JI:GetIconTexCoords(icon.texCoords, db.icon.reverse))

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

local function UpdatePortrait(frame)
	if not frame or not frame.classPortrait then return end
	local unit = cachedBlizzardPortraits[frame]
	local db = JI.db.blizzard[unit]

	if db then
		local _, class = UnitClass(frame.unit)
		local icon, fullPath
		if db.portrait.enable then icon, fullPath = JI:GetUnitIcon(frame.unit, db.portrait.style, class) end
		local showPortrait = icon and db.portrait.enable

		--* Update Background Color
		local r, g, b, a = unpack(db.portrait.background.color)
		if db.portrait.background.colorOverride == 2 and not (issecretvalue and issecretvalue(class)) and class then
			r, g, b = GetClassColor(class)
		elseif db.portrait.background.colorOverride == 1 then
			r, g, b = GetClassColor(select(2, UnitClass('player')))
		end
		frame.classPortrait.background:SetColorTexture(r, g, b, a)

		--* Update Portrait Texture
		frame.classPortrait.portrait:SetTexture(fullPath)
		if icon then frame.classPortrait.portrait:SetTexCoord(JI:GetIconTexCoords(icon.texCoords, db.portrait.reverse)) end

		frame.classPortrait:SetShown(showPortrait)
		frame.classPortrait.background:SetShown(showPortrait and db.portrait.background.enable)
		frame.portrait:SetShown(not showPortrait)
	end
end

local function CreatePortrait(frame)
	if frame.classPortrait then return end

	frame.classPortrait = CreateFrame('Frame', nil, frame)
	frame.classPortrait:SetAllPoints(frame.portrait)

	frame.classPortrait.background = frame.classPortrait:CreateTexture(nil, 'BACKGROUND', nil, -5)
	frame.classPortrait.background:SetAllPoints(frame.classPortrait)
	frame.classPortrait.background:SetTexture([[Interface\Tooltips\UI-Tooltip-Background]])

	frame.classPortrait.portrait = frame.classPortrait:CreateTexture(nil, 'BACKGROUND', nil, -4)
	frame.classPortrait.portrait:SetAllPoints(frame.classPortrait)

	frame.classPortrait.mask = frame.classPortrait:CreateMaskTexture()
	frame.classPortrait.mask:SetAllPoints(frame.classPortrait.background)
	frame.classPortrait.mask:SetTexture([[Interface\CHARACTERFRAME\TempPortraitAlphaMask]], 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE')

	frame.classPortrait.background:AddMaskTexture(frame.classPortrait.mask)
	frame.classPortrait.portrait:AddMaskTexture(frame.classPortrait.mask)
end

local singleUnits = { 'PlayerFrame', 'TargetFrame', 'TargetFrameToT', 'FocusFrame', 'FocusFrameToT' }
-- Spec refreshes paint existing textures; layout remains untouched in combat.
function JI:RefreshBlizzardSpecializations()
	for frame, unit in pairs(cachedBlizzardClassIcons) do
		local db = JI.db.blizzard[unit].icon
		local _, _, kind = JI:GetStyleInfo(db.style)
		if kind == 'spec' and frame.classIcon then
			local icon, path
			if db.enable then
				LayoutIcon(frame, db)
				icon, path = JI:GetUnitIcon(frame.unit, db.style)
			end
			frame.classIcon.icon:SetTexture(path)
			if icon then frame.classIcon.icon:SetTexCoord(JI:GetIconTexCoords(icon.texCoords, db.reverse)) end
			frame.classIcon:SetShown(db.enable and icon ~= nil)
		end
	end
	for frame, unit in pairs(cachedBlizzardPortraits) do
		local _, _, kind = JI:GetStyleInfo(JI.db.blizzard[unit].portrait.style)
		if kind == 'spec' then UpdatePortrait(frame) end
	end
end

function JI:UpdateMedia(specific)
	if specific then
		for frame, unit in next, cachedBlizzardClassIcons do
			if unit == specific then
				UpdateIcon(frame)
				return
			end
		end
		for frame, unit in next, cachedBlizzardPortraits do
			if unit == specific then
				UpdatePortrait(frame)
				return
			end
		end
	end

	for _, frame in ipairs(singleUnits) do
		frame = _G[frame]
		UpdateIcon(frame)
		UpdatePortrait(frame)
	end

	for i = 1, 4 do
		local frame = _G.PartyFrame and _G.PartyFrame['MemberFrame'..i] or _G['PartyMemberFrame'..i]
		UpdateIcon(frame)
		UpdatePortrait(frame)
	end
end

--* Create both icons and portraits for 'SingleUnits' and 'Party'
function JI:SetupBlizzardFrames()
	--* Setup Single Units Icons and Portraits
	for _, frame in next, singleUnits do
		frame = _G[frame]
		if frame and frame.unit and frame.unit ~= '' then
			if not cachedBlizzardClassIcons[frame] then
				cachedBlizzardClassIcons[frame] = frame.unit
				CreateIcon(frame)
			end
			if not cachedBlizzardPortraits[frame] then
				cachedBlizzardPortraits[frame] = frame.unit
				CreatePortrait(frame)
			end
		end
	end

	--* Setup Party Icons and Portraits
	for i = 1, 4 do
		local frame = _G.PartyFrame and _G.PartyFrame['MemberFrame'..i] or _G['PartyMemberFrame'..i]
		if frame and frame.unit and frame.unit ~= '' then
			local unit = strmatch(frame.unit, 'party') and 'party'

			if not cachedBlizzardClassIcons[frame] then
				cachedBlizzardClassIcons[frame] = unit
				CreateIcon(frame)
			end
			if not cachedBlizzardPortraits[frame] then
				cachedBlizzardPortraits[frame] = unit
				CreatePortrait(frame)
			end
		end
	end
end

--* Update 'SingleUnits' and 'Party' (Icona and Portraits)
function JI:UnitFramePortrait_Update(frame, updated)
	if not frame then return end

	if type(frame) == 'string' and updated then
		if updated == 'icon' then
			for cachedFrame, unit in next, cachedBlizzardClassIcons do
				if frame == unit then
					UpdateIcon(cachedFrame)
				end
			end
		elseif updated == 'portrait' then
			for cachedFrame, unit in next, cachedBlizzardPortraits do
				if frame == unit then
					UpdatePortrait(cachedFrame)
				end
			end
		end
		return
	end

	if cachedBlizzardClassIcons[frame] then UpdateIcon(frame) end
	if cachedBlizzardPortraits[frame] then UpdatePortrait(frame) end
end
