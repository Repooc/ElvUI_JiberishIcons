local JI = unpack(JiberishIcons)
local definitions = JI.dataHelper.portraitUnits
local frames, driver, unlocked = {}, nil, false
JI.portraitFrames = frames

local media = JI.MediaPath..[[Portraits\]]
local shapes = {
	circle = {border = 'circle', mask = 'circle-mask'},
	droplet = {border = 'droplet', mask = 'droplet-mask'},
	dropletleft = {border = 'droplet', mask = 'droplet-left-mask', reverse = true},
	circlethin = {border = 'circle-thin', mask = 'circle-thin-mask'},
	dropletthin = {border = 'droplet-thin', mask = 'droplet-thin-mask'},
	dropletleftthin = {border = 'droplet-thin', mask = 'droplet-left-thin-mask', reverse = true},
	none = {},
}
local function IsAdditional(key) return key:match('^additional[123]$') ~= nil end
local function SourceUnit(key, db) return IsAdditional(key) and db.sourceUnit or key end
local points = {CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
	TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true}
local strata = {BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true}

local function IsSecret(value)
	return issecretvalue and issecretvalue(value)
end

local function Number(value, fallback, low, high)
	if IsSecret(value) or type(value) ~= 'number' or value ~= value then return fallback end
	return math.max(low, math.min(high, value))
end

local function Settings(key)
	return JI.db and JI.db.portraits and JI.db.portraits[key]
end

local function FrameUnit(frame)
	local unit = frame.__unit
	if IsSecret(unit) then return nil, true end
	if not unit then unit = frame.unit end
	if IsSecret(unit) then return nil, true end
	if not unit and frame.GetAttribute then unit = frame:GetAttribute('unit') end
	if IsSecret(unit) then return nil, true end
	if not IsSecret(unit) and type(unit) == 'string' then return unit end
end

local function Anchor(key, db)
	key = SourceUnit(key, db)
	if db.anchor == 'screen' then return UIParent end
	if db.anchor == 'custom' then
		local name = db.frameName
		if type(name) ~= 'string' or name:find('^JiberishIconsPortrait') then return end
		local frame = _G[name]
		if (type(frame) == 'table' or type(frame) == 'userdata') and frame.GetCenter and frame.IsShown then return frame end
	elseif db.anchor == 'elvui' then
		local E = _G.ElvUI and _G.ElvUI[1]
		-- A party self-button can also represent "player". Prefer ElvUI's
		-- canonical individual frame, even while its visibility is changing.
		local UF = E and E.UnitFrames
		local direct = UF and (UF[key] or (UF.units and UF.units[key]))
		if direct then return direct end
		local objects = E and E.oUF and E.oUF.objects
		if objects then
			for _, frame in ipairs(objects) do
				if FrameUnit(frame) == key and frame:IsShown() then return frame end
			end
		end
	elseif db.anchor == 'blizzard' then
		local names = {player = 'PlayerFrame', target = 'TargetFrame', targettarget = 'TargetFrameToT',
			pet = 'PetFrame', focus = 'FocusFrame'}
		if names[key] then return _G[names[key]] end
		local index = key:match('^party(%d+)$')
		if index then
			return (_G.PartyFrame and _G.PartyFrame['MemberFrame'..index]) or _G['PartyMemberFrame'..index]
		end
		index = key:match('^boss(%d+)$')
		if index then return _G['Boss'..index..'TargetFrame'] end
	end
end

local function Color(texture, color, vertex)
	local r, g, b, a = unpack(color)
	if vertex then texture:SetVertexColor(r, g, b, a) else texture:SetColorTexture(r, g, b, a) end
end

local function Visible(frame, db)
	if not db or not db.enable then return false end
	if unlocked then return true end
	if db.anchor ~= 'screen' then
		local anchor = frame.anchor
		if not anchor or not anchor:IsShown() then return false end
		-- Party headers may reassign units in combat. Hide until we can safely
		-- attach to this token's new frame instead of displaying the wrong member.
		if db.anchor ~= 'custom' then
			local unit, restricted = FrameUnit(anchor)
			local source = SourceUnit(frame.key, db)
			local playerVehicle = source == 'player' and unit == 'vehicle'
			if restricted or (unit and unit ~= source and not playerVehicle) then return false end
		end
	end
	if IsAdditional(frame.key) and db.mode == 'static' then return true end
	local exists = UnitExists(SourceUnit(frame.key, db))
	return not IsSecret(exists) and not not exists
end

local function Paint(frame)
	local db = Settings(frame.key)
	local visible = Visible(frame, db)
	frame.visible = visible
	frame.background:SetShown(visible and db.shape ~= 'none')
	frame.border:SetShown(visible and db.shape ~= 'none')
	frame.icon:Hide(); frame.portrait:Hide()
	frame.label:SetShown(visible and unlocked)
	frame.mover:SetShown(visible and unlocked)
	if not visible then
		JI:StopPortraitCast(frame)
		return
	end
	local source = SourceUnit(frame.key, db)
	local exists = UnitExists(source)
	local unit = unlocked and (IsSecret(exists) or not exists) and 'player' or source
	local icon, path
	local selectedClass
	if db.mode == 'static' and IsAdditional(frame.key) then
		local _, _, kind = JI:GetStyleInfo(db.style)
		local spec = kind == 'spec' and JI.dataHelper.specialization[db.specID]
		selectedClass = kind == 'class' and db.iconID or (spec and spec.class)
		icon, path = JI:GetIdentityIcon(selectedClass, db.raceID, db.style, db.specID)
	elseif db.mode == 'icon' then
		icon, path = JI:GetUnitIcon(unit, db.style)
		if not icon and db.fallback == 'class' then icon, path = JI:GetUnitIcon(unit, 'fabledclass') end
	end
	if icon then
		frame.icon:SetTexture(path)
		frame.icon:SetTexCoord(JI:GetIconTexCoords(icon.texCoords, db.reverse))
		frame.icon:Show()
	elseif db.mode == 'portrait' or (db.mode ~= 'static' and db.fallback == 'portrait') then
		-- The game's portrait renderer supports players, pets and NPCs directly.
		frame.portrait:SetTexture(nil)
		SetPortraitTexture(frame.portrait, unit)
		local zoom = Number(db.zoom, 0.12, 0, 0.4)
		frame.portrait:SetTexCoord(db.reverse and 1 - zoom or zoom, db.reverse and zoom or 1 - zoom, zoom, 1 - zoom)
		frame.portrait:Show()
	end
	Color(frame.border, db.borderColor, true)
	if db.classColor then
		local _, class = UnitClass(unit)
		if db.mode == 'static' then class = selectedClass end
		if not IsSecret(class) and type(class) == 'string' then
			local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
			local color = colors and colors[class]
			if color then frame.border:SetVertexColor(color.r, color.g, color.b, db.borderColor[4]) end
		end
	end
	JI:UpdatePortraitCast(frame)
end

local function SavePosition(frame)
	if not frame.dragging then return end
	frame:StopMovingOrSizing(); frame.dragging = nil
	frame:SetClampedToScreen(false)
	local x, y = frame:GetCenter()
	local rootX, rootY = UIParent:GetCenter()
	if not x or not rootX then return end
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local db = Settings(frame.key)
	-- Dragging deliberately detaches a portrait from its previous frame anchor.
	db.anchor, db.point, db.relativePoint = 'screen', 'CENTER', 'CENTER'
	db.x, db.y = math.floor(x * scale - rootX + 0.5), math.floor(y * scale - rootY + 0.5)
	if JI.Libs.ACR.NotifyChange then JI.Libs.ACR:NotifyChange(JI.AddOnName) end
end

local function Create(definition)
	local frame = CreateFrame('Frame', 'JiberishIconsPortrait_'..definition.key, UIParent)
	frame.key = definition.key
	frame:SetMovable(true); frame:SetClampedToScreen(false)
	frame:RegisterForDrag('LeftButton'); frame:EnableMouse(false)
	frame.background = frame:CreateTexture(nil, 'BACKGROUND')
	frame.portrait = frame:CreateTexture(nil, 'ARTWORK', nil, 0)
	frame.icon = frame:CreateTexture(nil, 'ARTWORK', nil, 1)
	frame.border = frame:CreateTexture(nil, 'OVERLAY', nil, 0)
	frame.mask = frame:CreateMaskTexture()
	-- Fractional UI scales should filter edges instead of snapping each texture
	-- independently. Keep the border and mask on the same sampling grid.
	for _, texture in ipairs({frame.background, frame.portrait, frame.icon, frame.border, frame.mask}) do
		if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
		if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
	end
	frame.mask:SetAllPoints(frame)
	for _, texture in ipairs({frame.background, frame.portrait, frame.icon}) do texture:AddMaskTexture(frame.mask) end
	frame.masked = true
	frame.background:SetAllPoints(frame); frame.portrait:SetAllPoints(frame); frame.border:SetAllPoints(frame)
	frame.mover = frame:CreateTexture(nil, 'OVERLAY', nil, 1)
	frame.mover:SetAllPoints(frame); frame.mover:SetColorTexture(0.1, 0.7, 1, 0.15)
	frame.label = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	frame.label:SetPoint('TOP', frame, 'BOTTOM', 0, -2); frame.label:SetText(definition.name)
	frame:SetScript('OnDragStart', function(self)
		if unlocked and not InCombatLockdown() then
			self:SetClampedToScreen(true); self:StartMoving(); self.dragging = true
		end
	end)
	frame:SetScript('OnDragStop', function(self)
		SavePosition(self)
		if not InCombatLockdown() then JI:UpdatePortraits() end
	end)
	JI:CreatePortraitCast(frame)
	frames[definition.key] = frame
	return frame
end

local function TextureSuffix(frame, size)
	local pixels = size * frame:GetEffectiveScale()
	if GetPhysicalScreenSize and UIParent.GetHeight then
		local _, height = GetPhysicalScreenSize()
		local rootHeight = UIParent:GetHeight()
		if height and height > 0 and rootHeight and rootHeight > 0 then
			pixels = size * frame:GetEffectiveScale() / UIParent:GetEffectiveScale() * height / rootHeight
		end
	end
	-- Use an area-sampled TGA close to the displayed size. These use the same
	-- proven format as the icon atlases, with no custom BLP decoder dependency.
	for _, edge in ipairs({32, 64, 128, 256, 512}) do
		if pixels <= edge then return '-'..edge end
	end
	return ''
end

local function Layout(frame, db)
	local shape = shapes[db.shape] or shapes.circle
	local size = Number(db.size, 80, 24, 320)
	frame:SetSize(size, size)
	frame:SetClampedToScreen(false)
	if frame.SetUserPlaced then frame:SetUserPlaced(false) end
	frame:SetFrameStrata(strata[db.strata] and db.strata or 'MEDIUM')
	frame:SetFrameLevel(Number(db.level, 10, 1, 100))
	local suffix = TextureSuffix(frame, size)
	frame.border:SetTexture(shape.border and (media..shape.border..suffix..'.tga') or nil, 'CLAMP', 'CLAMP', 'LINEAR')
	frame.border:SetTexCoord(shape.reverse and 1 or 0, shape.reverse and 0 or 1, 0, 1)
	if shape.mask then frame.mask:SetTexture(media..shape.mask..suffix..'.tga', 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE', 'LINEAR') end
	local masked = shape.mask ~= nil
	if masked ~= frame.masked then
		for _, texture in ipairs({frame.background, frame.portrait, frame.icon}) do
			if masked then texture:AddMaskTexture(frame.mask) else texture:RemoveMaskTexture(frame.mask) end
		end
		frame.masked = masked
	end
	Color(frame.background, db.backgroundColor)
	local iconSize = size * Number(db.iconScale, 0.78, 0.4, 1.3)
	frame.icon:SetSize(iconSize, iconSize); frame.icon:ClearAllPoints()
	frame.icon:SetPoint('CENTER', frame, 'CENTER', Number(db.contentX, 0, -100, 100), Number(db.contentY, 0, -100, 100))
	local anchor = Anchor(frame.key, db)
	frame.anchor = anchor
	frame:ClearAllPoints()
	frame:SetPoint(points[db.point] and db.point or 'CENTER', anchor or UIParent,
		points[db.relativePoint] and db.relativePoint or 'CENTER', Number(db.x, 0, -10000, 10000), Number(db.y, 0, -10000, 10000))
	frame:EnableMouse(unlocked and db.enable)
	JI:LayoutPortraitCast(frame, frame.border:GetTexture())
end

function JI:ArePortraitsUnlocked() return unlocked end

function JI:SetPortraitPlacement(key, field, value)
	if InCombatLockdown() then return end
	if field ~= 'x' and field ~= 'y' and field ~= 'point' and field ~= 'relativePoint' then return end
	local frame = frames[key]
	-- A numeric adjustment takes precedence over an unfinished mouse drag.
	if frame and frame.dragging then frame:StopMovingOrSizing(); frame.dragging = nil end
	if field == 'x' or field == 'y' then value = Number(tonumber(value), 0, -10000, 10000)
	elseif not points[value] then return end
	Settings(key)[field] = value
	JI:UpdatePortraits()
end

function JI:LockPortraits(discardPosition)
	for _, frame in pairs(frames) do
		if discardPosition then
			-- AceDB removes defaults from the previous profile before callbacks.
			-- Cancel a drag without writing the old position into the new profile.
			if frame.dragging then frame:StopMovingOrSizing(); frame.dragging = nil end
		else SavePosition(frame) end
		frame:EnableMouse(false)
	end
	unlocked = false
	for _, frame in pairs(frames) do Paint(frame) end
end

function JI:TogglePortraitMovers()
	if InCombatLockdown() then return end
	if unlocked then JI:LockPortraits() else unlocked = true end
	JI:UpdatePortraits()
end

function JI:RefreshPortraitSpecializations()
	for _, frame in pairs(frames) do
		local db = Settings(frame.key)
		local _, _, kind = JI:GetStyleInfo(db.style)
		if db.enable and db.mode == 'icon' and kind == 'spec' then Paint(frame) end
	end
end

local elapsed, anchorElapsed = 0, 0
local function Tick(_, delta)
	elapsed, anchorElapsed = elapsed + delta, anchorElapsed + delta
	if elapsed < 0.2 then return end
	elapsed = 0
	for key, frame in pairs(frames) do
		local db = Settings(key)
		if db.enable then
			if anchorElapsed >= 1 and not InCombatLockdown() and not frame.dragging and Anchor(key, db) ~= frame.anchor then Layout(frame, db) end
			-- ToT changes do not always emit portrait events. Other units repaint
			-- from events; this lightweight check only follows anchor visibility.
			if SourceUnit(key, db) == 'targettarget' or Visible(frame, db) ~= frame.visible then Paint(frame) end
		end
	end
	if anchorElapsed >= 1 then anchorElapsed = 0 end
end

function JI:UpdatePortraits()
	if not driver then return end
	local active = false
	for _, definition in ipairs(definitions) do
		local db = Settings(definition.key)
		local frame = frames[definition.key]
		if db.enable then active = true end
		if not InCombatLockdown() then
			if not frame and db.enable then frame = Create(definition) end
			if frame and not frame.dragging then Layout(frame, db) end
		end
		if frame then Paint(frame) end
	end
	driver:SetScript('OnUpdate', active and Tick or nil)
end

function JI:SetupPortraits()
	if driver then return end
	driver = CreateFrame('Frame')
	for _, event in ipairs({'PLAYER_ENTERING_WORLD', 'PLAYER_TARGET_CHANGED', 'PLAYER_FOCUS_CHANGED',
		'GROUP_ROSTER_UPDATE', 'INSTANCE_ENCOUNTER_ENGAGE_UNIT', 'UNIT_PORTRAIT_UPDATE', 'UNIT_MODEL_CHANGED',
		'UNIT_NAME_UPDATE', 'UNIT_TARGET', 'UNIT_PET', 'UNIT_CONNECTION', 'UNIT_ENTERED_VEHICLE',
		'UNIT_EXITED_VEHICLE', 'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED', 'ADDON_LOADED',
		'UI_SCALE_CHANGED', 'DISPLAY_SIZE_CHANGED'}) do
		if C_EventUtils and C_EventUtils.IsEventValid then
			if C_EventUtils.IsEventValid(event) then driver:RegisterEvent(event) end
		else pcall(driver.RegisterEvent, driver, event) end
	end
	driver:SetScript('OnEvent', function(_, event, unit)
		if event == 'PLAYER_REGEN_DISABLED' then JI:LockPortraits()
		elseif event == 'PLAYER_REGEN_ENABLED' or event == 'PLAYER_ENTERING_WORLD' or event == 'ADDON_LOADED'
			or event == 'GROUP_ROSTER_UPDATE' or event == 'UI_SCALE_CHANGED' or event == 'DISPLAY_SIZE_CHANGED' then JI:UpdatePortraits()
		elseif event:find('^UNIT_') then
			if IsSecret(unit) or type(unit) ~= 'string' then return end
			local frame = frames[unit]
			if frame then Paint(frame) end
			for key, extra in pairs(frames) do
				local db = Settings(key)
				if IsAdditional(key) and db.mode ~= 'static' and (db.sourceUnit == unit
					or (event == 'UNIT_TARGET' and unit == 'target' and db.sourceUnit == 'targettarget')
					or (event == 'UNIT_PET' and unit == 'player' and db.sourceUnit == 'pet')) then Paint(extra) end
			end
			if event == 'UNIT_TARGET' and unit == 'target' and frames.targettarget then Paint(frames.targettarget) end
			if event == 'UNIT_PET' and unit == 'player' and frames.pet then Paint(frames.pet) end
		else for _, frame in pairs(frames) do Paint(frame) end end
	end)
	JI:UpdatePortraits()
end
