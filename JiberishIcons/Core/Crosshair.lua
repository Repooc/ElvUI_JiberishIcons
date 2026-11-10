local JI = unpack(JiberishIcons)
local frame, driver, unlocked
local media = JI.MediaPath..[[Crosshair\]]
local styles = {plus = true, x = true, splitplus = true, splitx = true}
local shapes = {circle = true, diamond = true, square = true, triangle = true}
local strata = {LOW = true, MEDIUM = true, HIGH = true, DIALOG = true}
-- The Classic beta/Forever client uses the Classic GCD reference spell.
local interface = GetBuildInfo and select(4, GetBuildInfo())
local GCD_SPELL = type(interface) == 'number' and interface >= 16000 and interface < 20000 and 29515 or 61304

local function Settings() return JI.db.crosshair end
local function IsSecret(value) return issecretvalue and issecretvalue(value) end
local function PublicNumber(value)
	return not IsSecret(value) and type(value) == 'number' and value == value
end
local function Number(value, default, low, high)
	if not PublicNumber(value) then return default end
	return math.max(low, math.min(high, value))
end

local function StopGCD()
	frame.preview = nil
	frame.ring:Clear()
	frame.ring:Hide()
end

local function UpdateGCD()
	if not frame then return end
	local db = Settings()
	if not frame:IsShown() or not db.gcd.enable then StopGCD(); return end
	if unlocked then
		if not frame.preview then
			frame.preview = true
			frame.ring:Show()
			frame.ring:SetCooldown(GetTime(), 1.5)
		end
		return
	end
	frame.preview = nil
	-- Read only the global cooldown, never the last spell's own cooldown.
	-- Let the native widget animate duration objects without inspecting secret
	-- timing values in Lua. A zero duration clears the native swipe.
	if C_Spell and C_Spell.GetSpellCooldownDuration and frame.ring.SetCooldownFromDurationObject then
		local duration = C_Spell.GetSpellCooldownDuration(GCD_SPELL, false)
		if duration then
			frame.ring:Show()
			frame.ring:SetCooldownFromDurationObject(duration, true)
			return
		end
		-- Some clients expose duration objects but return nil for the GCD.
		-- Fall through to their timestamp API before clearing the indicator.
	end
	local start, duration, enabled, rate
	if C_Spell and C_Spell.GetSpellCooldown then
		local info = C_Spell.GetSpellCooldown(GCD_SPELL)
		if info then start, duration, enabled, rate = info.startTime, info.duration, info.isEnabled, info.modRate end
	elseif GetSpellCooldown then
		start, duration, enabled, rate = GetSpellCooldown(GCD_SPELL)
	end
	-- Older clients need public timestamps. Unavailable/restricted data clears
	-- the indicator instead of guessing a duration or using stale progress.
	if IsSecret(enabled) or enabled == false or enabled == 0
		or not PublicNumber(start) or not PublicNumber(duration) then StopGCD(); return end
	if rate == nil then rate = 1 end
	if not PublicNumber(rate) or rate <= 0 or duration <= 0 or start + duration / rate <= GetTime() then
		StopGCD(); return
	end
	frame.ring:Show()
	frame.ring:SetCooldown(start, duration, rate)
end

local function Paint()
	if not frame then return end
	local db = Settings()
	local visible = db.enable and (unlocked or db.visibility == 'always' or InCombatLockdown())
	frame:SetShown(visible)
	frame.track:SetShown(db.gcd.enable)
	frame.mover:SetShown(unlocked and db.enable)
	frame.label:SetShown(unlocked and db.enable)
	frame:EnableMouse(unlocked and db.enable)
	UpdateGCD()
end

local function SavePosition()
	if not frame or not frame.dragging then return end
	frame:StopMovingOrSizing(); frame.dragging = nil
	frame:SetClampedToScreen(false)
	local x, y = frame:GetCenter()
	local rootX, rootY = UIParent:GetCenter()
	if not x or not rootX then return end
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local db = Settings()
	db.x, db.y = math.floor(x * scale - rootX + 0.5), math.floor(y * scale - rootY + 0.5)
	if frame.SetUserPlaced then frame:SetUserPlaced(false) end
	if JI.Libs.ACR.NotifyChange then JI.Libs.ACR:NotifyChange(JI.AddOnName) end
end

local function Create()
	frame = CreateFrame('Frame', 'JiberishIconsCrosshair', UIParent)
	JI.crosshairFrame = frame
	frame:SetMovable(true); frame:SetClampedToScreen(false)
	frame:RegisterForDrag('LeftButton'); frame:EnableMouse(false)
	frame.track = frame:CreateTexture(nil, 'BACKGROUND')
	frame.marker = frame:CreateTexture(nil, 'ARTWORK')
	for _, texture in ipairs({frame.track, frame.marker}) do
		texture:SetPoint('CENTER')
		if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false); texture:SetTexelSnappingBias(0) end
	end
	frame.ring = CreateFrame('Cooldown', nil, frame, 'CooldownFrameTemplate')
	local ring = frame.ring
	ring:SetPoint('CENTER'); ring:EnableMouse(false)
	ring:SetDrawEdge(false); ring:SetDrawBling(false); ring:SetDrawSwipe(true)
	ring:SetHideCountdownNumbers(true); ring:SetReverse(true)
	-- Square swipe geometry reaches the corners of every outline texture.
	if ring.SetUseCircularEdge then ring:SetUseCircularEdge(false) end
	ring.noCooldownCount = true
	ring:SetScript('OnCooldownDone', function(self)
		if frame.preview and unlocked and Settings().enable and Settings().gcd.enable then
			self:SetCooldown(GetTime(), 1.5)
		else self:Hide() end
	end)
	frame.mover = frame:CreateTexture(nil, 'OVERLAY')
	frame.mover:SetAllPoints(frame); frame.mover:SetColorTexture(0.1, 0.7, 1, 0.15)
	frame.label = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	frame.label:SetPoint('TOP', frame, 'BOTTOM', 0, -4); frame.label:SetText('Crosshair — drag to position')
	frame:SetScript('OnDragStart', function(self)
		if unlocked and not InCombatLockdown() then
			self:SetClampedToScreen(true); self:StartMoving(); self.dragging = true
		end
	end)
	frame:SetScript('OnDragStop', function()
		SavePosition()
		JI:UpdateCrosshair()
	end)
	StopGCD()
end

local function Texture(name, weight, size)
	local pixels = size * frame:GetEffectiveScale()
	if GetPhysicalScreenSize and UIParent.GetHeight then
		local _, height = GetPhysicalScreenSize()
		local rootHeight = UIParent:GetHeight()
		if height and height > 0 and rootHeight and rootHeight > 0 then
			pixels = size * frame:GetEffectiveScale() / UIParent:GetEffectiveScale() * height / rootHeight
		end
	end
	local edge = 256
	for _, candidate in ipairs({32, 64, 128, 256}) do
		if pixels <= candidate then edge = candidate; break end
	end
	return media..name..'-'..(weight == 'bold' and 'bold' or 'thin')..'-'..edge..'.tga'
end

function JI:UpdateCrosshair()
	if not driver then return end
	local db = Settings()
	if not db.enable then JI:LockCrosshair(true) end
	if not InCombatLockdown() then
		if not frame and db.enable then Create() end
		if frame and not frame.dragging then
			local size, ringSize = Number(db.size, 32, 8, 128), Number(db.gcd.size, 64, 16, 256)
			local hitSize = math.max(32, size, db.gcd.enable and ringSize or 0)
			frame:SetSize(hitSize, hitSize)
			frame:SetClampedToScreen(false)
			if frame.SetUserPlaced then frame:SetUserPlaced(false) end
			frame:SetFrameStrata(strata[db.strata] and db.strata or 'HIGH'); frame:SetFrameLevel(20)
			frame:ClearAllPoints()
			frame:SetPoint('CENTER', UIParent, 'CENTER', Number(db.x, 0, -10000, 10000), Number(db.y, -80, -10000, 10000))
			frame.marker:SetSize(size, size)
			frame.marker:SetTexture(Texture(styles[db.style] and db.style or 'plus', db.weight, size), 'CLAMP', 'CLAMP', 'LINEAR')
			frame.marker:SetVertexColor(unpack(db.color))
			local path = Texture(shapes[db.gcd.shape] and db.gcd.shape or 'diamond', db.gcd.weight, ringSize)
			local gx, gy = Number(db.gcd.x, 0, -10000, 10000), Number(db.gcd.y, 0, -10000, 10000)
			frame.track:ClearAllPoints(); frame.track:SetPoint('CENTER', frame, 'CENTER', gx, gy)
			frame.ring:ClearAllPoints(); frame.ring:SetPoint('CENTER', frame, 'CENTER', gx, gy)
			frame.track:SetSize(ringSize, ringSize)
			frame.track:SetTexture(path, 'CLAMP', 'CLAMP', 'LINEAR'); frame.track:SetVertexColor(unpack(db.gcd.trackColor))
			frame.ring:SetSize(ringSize, ringSize); frame.ring:SetSwipeTexture(path, unpack(db.gcd.color))
		end
	end
	Paint()
end

function JI:IsCrosshairUnlocked() return not not unlocked end

function JI:LockCrosshair(discardPosition)
	if frame then
		if discardPosition then
			-- Profile callbacks already point at the new profile.
			if frame.dragging then frame:StopMovingOrSizing(); frame.dragging = nil end
			frame:SetClampedToScreen(false)
		else SavePosition() end
	end
	unlocked = false
	Paint()
end

function JI:ToggleCrosshairMover()
	if InCombatLockdown() or not Settings().enable then return end
	if unlocked then JI:LockCrosshair() else unlocked = true end
	JI:UpdateCrosshair()
end

function JI:SetCrosshairPosition(x, y)
	if InCombatLockdown() then return end
	if frame and frame.dragging then frame:StopMovingOrSizing(); frame.dragging = nil end
	local db = Settings()
	db.x, db.y = Number(tonumber(x), 0, -10000, 10000), Number(tonumber(y), -80, -10000, 10000)
	JI:UpdateCrosshair()
end

function JI:SetupCrosshair()
	if driver then return end
	driver = CreateFrame('Frame')
	for _, event in ipairs({'PLAYER_ENTERING_WORLD', 'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED',
		'SPELL_UPDATE_COOLDOWN', 'UNIT_SPELLCAST_START', 'UNIT_SPELLCAST_SUCCEEDED', 'UI_SCALE_CHANGED', 'DISPLAY_SIZE_CHANGED'}) do
		driver:RegisterEvent(event)
	end
	driver:SetScript('OnEvent', function(_, event, unit)
		if event == 'UNIT_SPELLCAST_START' or event == 'UNIT_SPELLCAST_SUCCEEDED' then
			if not IsSecret(unit) and unit == 'player' then
				UpdateGCD()
				-- The spellcast event can precede the cooldown cache update.
				if C_Timer then C_Timer.After(0, UpdateGCD) end
			end
		elseif event == 'SPELL_UPDATE_COOLDOWN' then UpdateGCD()
		elseif event == 'PLAYER_REGEN_DISABLED' then JI:LockCrosshair()
		else JI:UpdateCrosshair() end
	end)
	JI:UpdateCrosshair()
end
