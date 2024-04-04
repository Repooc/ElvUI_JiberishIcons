local JI = unpack(ElvUI_JiberishIcons)

local classIconPath, classIcons, iconStyles = JI.classIconPath, JI.classIcons, JI.iconStyles
local cachedPortraits, cachedIcons = {}, {}

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

local function UpdateIcon(frame)
	if not frame or not frame.classIcon then return end

	local db = JI.db.suf[frame.unitType]
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

function JI:UpdateSUF(specific)
	for frame, unit in next, cachedPortraits do
		if specific and unit == specific then
			ShadowUF.Layout:Reload(unit)
		elseif not specific then
			ShadowUF.Layout:Reload(unit)
		end
	end

	for frame, unit in next, cachedIcons do
		if specific and unit == specific then
			ShadowUF.Layout:Reload(unit)
		elseif not specific then
			ShadowUF.Layout:Reload(unit)
		end
	end
end

function JI:SetupSUF()
	if not JI:IsAddOnEnabled('ShadowedUnitFrames') then return end

	JI:SecureHook(ShadowUF, 'LoadUnitDefaults', function()
		for _, unit in pairs(ShadowUF.unitList) do
			ShadowUF.defaults.profile.units[unit].classicon = {
				enabled = true
			}
			ShadowUF.defaults.profile.units[unit].classportrait = {
				enabled = true
			}
		end
	end)
end

if not JI:IsAddOnEnabled('ShadowedUnitFrames') or not ShadowUF then return end

--! Custom SUF Module for Class Portrait
local ClassPortrait = {}

ShadowUF:RegisterModule(ClassPortrait, 'classportrait')
function ClassPortrait:OnEnable(frame)
	frame:RegisterUnitEvent('UNIT_PORTRAIT_UPDATE', ClassPortrait, 'Update')
	frame:RegisterUnitEvent('UNIT_MODEL_CHANGED', ClassPortrait, 'Update')

	frame:RegisterUpdateFunc(ClassPortrait, 'Update')
end

function ClassPortrait:OnDisable(frame)
	frame:UnregisterAll(self)
end

function ClassPortrait:OnLayoutApply(frame)
	if not cachedPortraits[frame] then cachedPortraits[frame] = frame.unitType end
end

function ClassPortrait:OnPreLayoutApply(frame)
	if not frame or not ShadowUF.db.profile.units[frame.unitType].portrait then return end

	if not cachedPortraits[frame] then cachedPortraits[frame] = frame.unitType end
end

function ClassPortrait:Update(frame)
	if not frame.portrait then return end

	local db = JI.db.suf[frame.unitType]
	local classToken = frame:UnitClassToken()
	local icon = classIcons[classToken]
	local type = ShadowUF.db.profile.units[frame.unitType].portrait.type

	if type == 'class' then
		local classToken = frame:UnitClassToken()
		if classToken then
			if db.portrait.enable then
				local icon = classIcons[classToken]
				if icon then
					frame.portrait:SetTexture(format('%s%s', classIconPath, db.portrait.style))
					frame.portrait:SetTexCoord(unpack(icon.texCoords))
				else
					frame.portrait:SetTexture('')
				end
			else
				local classIconAtlas = GetClassAtlas(classToken)
				if classIconAtlas then
					frame.portrait:SetTexCoord(0, 1, 0, 1)
					frame.portrait:SetAtlas(classIconAtlas)
				else
					frame.portrait:SetTexture('')
				end
			end
		else
			frame.portrait:SetTexture('')
		end
	-- Use 2D character image
	elseif type == '2D' then
		frame.portrait:SetTexCoord(0.10, 0.90, 0.10, 0.90)
		SetPortraitTexture(frame.portrait, frame.unitOwner)
	-- Using 3D portrait, but the players not in range so swap to question mark
	elseif not UnitIsVisible(frame.unitOwner) or not UnitIsConnected(frame.unitOwner) then
		frame.portrait:ClearModel()
		frame.portrait:SetModelScale(5.5)
		frame.portrait:SetPosition(0, 0, -0.8)
		frame.portrait:SetModel([[Interface\Buttons\talktomequestionmark.m2]])
	-- Use animated 3D portrait
	else
		frame.portrait:ClearModel()
		frame.portrait:SetUnit(frame.unitOwner)
		frame.portrait:SetPortraitZoom(1)
		frame.portrait:SetPosition(0, 0, 0)
		frame.portrait:Show()
	end
end

--! Custom SUF Module for Class Icons
local ClassIcon = {}

ShadowUF:RegisterModule(ClassIcon, 'classicon')
function ClassIcon:OnEnable(frame)
	frame:RegisterUnitEvent('UNIT_PORTRAIT_UPDATE', ClassIcon, 'Update')
	frame:RegisterUnitEvent('UNIT_MODEL_CHANGED', ClassIcon, 'Update')

	frame:RegisterUpdateFunc(ClassIcon, 'Update')
end

--* Yes the function is empty as SUF api required it to exsist
function ClassIcon:OnDisable(frame)
	frame:UnregisterAll(self)
end

function ClassIcon:OnPreLayoutApply(frame)
	if frame.classIcon then return end

	cachedIcons[frame] = frame.unitType

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

function ClassIcon:Update(frame)
	UpdateIcon(frame)
end
