local JI = unpack(JiberishIcons)
local units = {player = 'Player', target = 'Target', focus = 'Focus', pet = 'Pet', targettarget = 'Target of target', focustarget = 'Focus target'}
JI.individualLayoutUnits = units
local mirrorPoint = {LEFT='RIGHT', RIGHT='LEFT', TOPLEFT='TOPRIGHT', TOPRIGHT='TOPLEFT', BOTTOMLEFT='BOTTOMRIGHT', BOTTOMRIGHT='BOTTOMLEFT'}
local function Mirror(point) return mirrorPoint[point] or point end
local function Public(v) return not (issecretvalue and issecretvalue(v)) and type(v) == 'number' and v == v end
function JI:GetLayoutHostFrame(host, unit)
	if host == 'elvui' then
		local E = _G.ElvUI and _G.ElvUI[1]
		local UF = E and E.UnitFrames
		local names = {player='Player',target='Target',focus='Focus',pet='Pet',targettarget='TargetTarget',focustarget='FocusTarget'}
		return (UF and (UF[unit] or (UF.units and UF.units[unit]))) or (names[unit] and _G['ElvUF_'..names[unit]])
	end
	local ns = _G.EllesmereUI and _G.EllesmereUI._ModuleNS and _G.EllesmereUI._ModuleNS.EllesmereUIUnitFrames
	return ns and ns.frames and ns.frames[unit]
end
local function Reverse(theme, portrait)
	theme.cap.side = Mirror(theme.cap.side); theme.cap.mirror = not theme.cap.mirror; theme.cap.x = -theme.cap.x
	if theme.shape == 'diagonal' then theme.shape = 'diagonalback'
	elseif theme.shape == 'diagonalback' then theme.shape = 'diagonal' end
	theme.reverseSegments = not theme.reverseSegments
	portrait.point, portrait.relativePoint = Mirror(portrait.point), Mirror(portrait.relativePoint)
	portrait.x, portrait.contentX = -portrait.x, -portrait.contentX
	local shapes = {droplet='dropletleft',dropletleft='droplet',dropletthin='dropletleftthin',dropletleftthin='dropletthin'}
	portrait.shape = shapes[portrait.shape] or portrait.shape
	portrait.reverse = not portrait.reverse
	portrait.model.x, portrait.model.viewX, portrait.model.facing = -portrait.model.x, -portrait.model.viewX, -portrait.model.facing
	for _, prefix in ipairs({'name','time'}) do
		portrait.cast[prefix..'Point'] = Mirror(portrait.cast[prefix..'Point'])
		portrait.cast[prefix..'X'] = -portrait.cast[prefix..'X']
	end
end
local function CopyHostIcons(host, source, target, reverse)
	local db = JI.db[host]
	if not db or not db[source] or not db[target] then return end
	local settings = JI:CopyTable({}, db[source])
	if reverse then
		for _, field in ipairs({'portrait','icon'}) do
			local icon = settings[field]
			if icon then
				icon.reverse = not icon.reverse
				if icon.anchorPoint then icon.anchorPoint = Mirror(icon.anchorPoint) end
				if icon.xOffset then icon.xOffset = -icon.xOffset end
			end
		end
	end
	db[target] = settings
end
local function Refresh(host)
	JI:UpdateUnitFrameThemes(); JI:UpdatePortraits()
	if host == 'ellesmereui' then JI:UpdateEllesmereUI()
	else
		local E = _G.ElvUI and _G.ElvUI[1]
		if E and E.UnitFrames and E.UnitFrames.Update_AllFrames then E.UnitFrames:Update_AllFrames() end
	end
end
local function PortraitSettings(host, source)
	local db = JI:CopyTable({}, JI.db.portraits[source])
	if db.anchor ~= host and db.enable then
		-- A portrait dragged onto the screen still needs to be copied relative
		-- to its unit, rather than stacked at the source's screen coordinates.
		local frame, native = JI.portraitFrames[source], JI:GetLayoutHostFrame(host, source)
		if not frame or not native or not native:IsShown() then return nil, 'Show the source unit frame and its portrait before copying a screen/custom placement.' end
		local px, py = frame:GetCenter(); local nx, ny = native:GetCenter()
		if not Public(px) or not Public(py) or not Public(nx) or not Public(ny) then return nil, 'The source frame position is not available yet.' end
		local scale = UIParent:GetEffectiveScale()
		local ps, ns = frame:GetEffectiveScale()/scale, native:GetEffectiveScale()/scale
		local dx = px*ps-nx*ns
		local left = dx < 0
		db.point, db.relativePoint = left and 'RIGHT' or 'LEFT', left and 'LEFT' or 'RIGHT'
		db.x = dx + (left and 1 or -1)*(frame:GetWidth()*ps+native:GetWidth()*ns)/2
		db.y = py*ps-ny*ns
	end
	db.anchor, db.frameName = host, ''
	return db
end
function JI:CopyIndividualLayout(host, source, target, reverse, copySize)
	if InCombatLockdown() then return false, 'Leave combat before copying a layout.' end
	if not units[source] or not units[target] or source == target or (host ~= 'elvui' and host ~= 'ellesmereui') then return false, 'Choose two different individual frames.' end
	JI:LockPortraits()
	local portrait, err = PortraitSettings(host, source)
	if not portrait then return false, err end
	local theme = JI:CopyTable({}, JI.db.unitFrameThemes[host][source])
	local E = _G.ElvUI and _G.ElvUI[1]
	local settings = E and E.db and E.db.unitframe and E.db.unitframe.units
	if copySize and (host ~= 'elvui' or not settings or not settings[source] or not settings[target]) then return false, 'ElvUI frame size settings are unavailable.' end
	if copySize then
		for _, field in ipairs({'width','height'}) do
			local value = settings[source][field]
			if not Public(value) or value <= 0 or value > 10000 then return false, 'The source frame dimensions are unavailable.' end
		end
	end
	if reverse then Reverse(theme, portrait) end
	CopyHostIcons(host, source, target, reverse)
	JI.db.unitFrameThemes[host][target], JI.db.portraits[target] = theme, portrait
	if copySize then
		for _, field in ipairs({'width','height'}) do settings[target][field] = settings[source][field] end
		if E.UnitFrames and E.UnitFrames.CreateAndUpdateUF then E.UnitFrames:CreateAndUpdateUF(target) end
	end
	Refresh(host)
	return true, 'Copied '..units[source]..' to '..units[target]..(reverse and ' with reversed layout.' or '.')
end
function JI:ReverseIndividualLayout(host, key)
	if InCombatLockdown() or not units[key] or (host ~= 'elvui' and host ~= 'ellesmereui') then return false end
	JI:LockPortraits()
	local portrait, err = PortraitSettings(host, key)
	if not portrait then return false, err end
	local theme = JI:CopyTable({}, JI.db.unitFrameThemes[host][key])
	Reverse(theme, portrait)
	CopyHostIcons(host, key, key, true)
	JI.db.unitFrameThemes[host][key], JI.db.portraits[key] = theme, portrait
	Refresh(host)
	return true, 'Reversed '..units[key]..' layout.'
end
