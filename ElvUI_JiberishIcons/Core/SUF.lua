local JI = unpack(ElvUI_JiberishIcons)

local classIconPath, classIcons, iconStyles = JI.classIconPath, JI.classIcons, JI.iconStyles
local cachedPortraits = {}

function JI:UpdateSUF(specific)
	for frame, unit in next, cachedPortraits do
		if specific and unit == specific then
			ShadowUF.Layout:Reload(unit)
		elseif not specific then
			ShadowUF.Layout:Reload(unit)
		end
	end
end

local function UpdateSUFPortrait(module, frame)
	if not frame or not frame.unitType then return end
	local unit = strmatch(frame.unit, 'party') and 'party' or frame.unit
	local db = JI.db.suf[unit]

	local type = ShadowUF.db.profile.units[frame.unitType].portrait.type
	if not type then return end

	if not cachedPortraits[frame] then cachedPortraits[frame] = frame.unitType end

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
