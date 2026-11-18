-- Aura timeline: a line where your own buffs and ability cooldowns ride toward
-- zero as their time runs out. Keys that would overlap stack into lanes.
--
-- Positions never come from Lua arithmetic on a possibly secret time. Each entry
-- owns an invisible StatusBar along the line, its range RANGE times the line's
-- length; the time left (a duration object's GetRemainingDuration, secret or
-- not) goes to SetValue, and the key is anchored to the fill's leading edge, so
-- the client places it. The bars live in a clip frame that shows only the line:
-- a longer timer waits past the far end and slides in once it is on the line.
--
-- Only what is on the line shows. Each key sits in a window frame whose alpha
-- says whether its time left is above zero and at most the line's length: set
-- outright for a plain time, and for a secret one from a step curve the
-- duration object evaluates itself (the answer goes straight to the alpha).
-- Auras that last until cancelled are never tracked. Other secrets (an aura's
-- length, a cooldown's active flag) only reach SetAlphaFromBoolean.
--
-- Placement: ElvUI movers when ElvUI is loaded, otherwise EllesmereUI's Unlock
-- Mode, otherwise the offsets in the options.
local JI = unpack(JiberishIcons)
local Hud = JI.Hud

local CreateFrame, UIParent, GetTime, InCombatLockdown = CreateFrame, UIParent, GetTime, InCombatLockdown
local floor, max, min, abs, ceil = math.floor, math.max, math.min, math.abs, math.ceil
local IsSecret, Plain, Clamp = Hud.IsSecret, Hud.Plain, Hud.Clamp
local WHITE, ROUND = Hud.WHITE, Hud.ROUND
local GetActionInfo = (C_ActionBar and C_ActionBar.GetActionInfo) or _G.GetActionInfo

local MOVER = 'JiberishIconsAuraTimelineMover'
local UNLOCK_KEY = 'JiberishIcons_AuraTimeline'

local function DB() return JI.db.auraTimeline end
local function MaxTime() return max(Clamp(DB().maxTime, 60, 5, 3600), 1) end

local INTERPOLATION = Enum and Enum.StatusBarInterpolation
local IMMEDIATE = INTERPOLATION and INTERPOLATION.Immediate
local MARKS = {0, 5, 10, 30, 60, 120, 300, 600}
local STEM_BASE, RANGE = 6, 6

-- outer: the unscaled frame movers place, sized to the drawn timeline;
-- holder: the scaled frame everything is drawn in.
local outer, holder, lane, clip, line, caps, ticks, minors
local entries, activeCount = {}, 0
local metrics
local previewing = false
local driver = CreateFrame('Frame')
driver:Hide()

local function Safe(func, ...)
	local ok, result = pcall(func, ...)
	if not ok then
		if geterrorhandler then geterrorhandler()(result) end
		return false
	end
	return true, result
end

-- Colors ---------------------------------------------------------------------------
local palette = {}
local function ReadColors()
	local db = DB()
	local custom = db.colors == 'custom'
	local function Pick(key, role, alpha)
		local c = palette[key] or {}
		if custom then
			c[1], c[2], c[3], c[4] = Hud.Saved(db[key], role)
		else
			c[1], c[2], c[3] = Hud.Color(role)
			c[4] = alpha or 1
		end
		palette[key] = c
	end
	Pick('lineColor', 'text', 0.85)
	Pick('tickColor', 'dim', 0.8)
	Pick('labelColor', 'dim')
	Pick('accentColor', 'accent')
	Pick('borderColor', 'border')
	Pick('harmColor', 'alert')
	Pick('cooldownColor', 'accent')
	Pick('textColor', 'text')
	Pick('chipColor', 'backdrop', 0.85)
	if db.colors == 'class' then
		local accent = palette.accentColor
		accent[1], accent[2], accent[3] = Hud.ClassColor()
		local cool = palette.cooldownColor
		cool[1], cool[2], cool[3] = accent[1], accent[2], accent[3]
	end
end

local function Tint(region, key, alpha)
	local c = palette[key]
	if c then region:SetVertexColor(c[1], c[2], c[3], alpha or c[4] or 1) end
end

-- Text -----------------------------------------------------------------------------
local function Label(seconds)
	if seconds >= 60 then return format('%dM', floor(seconds / 60)) end
	if seconds == 0 then return '0' end
	return format('%dS', seconds)
end

local function TimeText(remaining)
	if remaining >= 3600 then return format('%dh', floor(remaining / 3600 + 0.5)) end
	if remaining >= 60 then return format('%dm', floor(remaining / 60 + 0.5)) end
	if remaining >= 10 then return format('%d', floor(remaining + 0.5)) end
	return format('%.1f', max(remaining, 0))
end

local blocked, blockedSource = {}, nil
local function Blocked(spellID)
	local source = DB().blacklist or ''
	if source ~= blockedSource then
		blockedSource = source
		wipe(blocked)
		for id in tostring(source):gmatch('%d+') do blocked[tonumber(id)] = true end
	end
	if IsSecret(spellID) or spellID == nil then return false end
	return blocked[spellID] or false
end

-- Geometry -------------------------------------------------------------------------
local function Vertical() return DB().orientation == 'vertical' end
local function Fraction(seconds) return min(1, seconds / MaxTime()) end
local function Edge()
	if Vertical() then return DB().reverse and 'BOTTOM' or 'TOP' end
	return DB().reverse and 'LEFT' or 'RIGHT'
end

local function TimeBand(db)
	if db.timeStyle == 'text' or db.timeStyle == 'chip' then return Clamp(db.timeSize, 10, 6, 20) + 4 end
	return 0
end

local function Metrics()
	local db = DB()
	local m = {}
	m.size = floor(Clamp(db.iconSize, 26, 12, 64) + 0.5)
	m.chipH = TimeBand(db)
	m.chipW = m.size + 8
	m.vertical = Vertical()
	m.gap = floor(Clamp(db.spacing, 3, 0, 20) + 0.5)
	m.keyAcross = m.chipH > 0 and max(m.size, m.chipW) or m.size
	m.cellAlong = m.vertical and (m.size + m.chipH) or m.keyAcross
	m.cellAcross = m.vertical and m.keyAcross or (m.size + m.chipH)
	m.pitch = m.cellAcross + m.gap
	m.lanes = floor(Clamp(db.lanes, 3, 1, 6) + 0.5)
	m.length = floor(Clamp(db.length, 260, 80, 1200) + 0.5)
	m.alongSign = db.reverse and -1 or 1
	m.stack = db.stack or 'up'
	if m.stack == 'down' then m.upLanes = 0
	elseif m.stack == 'both' then m.upLanes = ceil(m.lanes / 2)
	else m.upLanes = m.lanes end
	m.downLanes = m.lanes - m.upLanes
	m.labelBand = db.labels and (Clamp(db.labelSize, 9, 6, 16) + 3) or 0
	-- Scale labels sit on the side the keys don't use ('both': below).
	m.labelsUp = m.stack == 'down'
	m.baseUp = STEM_BASE + (m.labelsUp and m.labelBand or 0)
	m.baseDown = STEM_BASE + ((not m.labelsUp) and m.labelBand or 0)
	return m
end

local function LaneStart(m, k)
	local side, index
	if m.stack == 'down' then side, index = -1, k
	elseif m.stack == 'both' then
		if k % 2 == 1 then side, index = 1, (k + 1) / 2 else side, index = -1, k / 2 end
	else side, index = 1, k end
	return side * ((side > 0 and m.baseUp or m.baseDown) + (index - 1) * m.pitch)
end

-- s: the cell's near edge from the line (positive above, or right when vertical).
local function PlaceCell(key, anchor, s, m, stem)
	local x, y
	if m.vertical then
		y = m.chipH / 2
		x = s >= 0 and (s + m.keyAcross / 2) or (s - m.keyAcross / 2)
	else
		x = 0
		y = s >= 0 and (s + m.chipH + m.size / 2) or (s - m.size / 2)
	end
	key:ClearAllPoints()
	key:SetPoint('CENTER', anchor, 'CENTER', x, y)
	if not stem then return end
	local length = abs(s)
	local show = DB().stems and length > 1
	stem:SetShown(show and true or false)
	if not show then return end
	stem:ClearAllPoints()
	if m.vertical then
		stem:SetSize(length, m.px)
		stem:SetPoint(s >= 0 and 'LEFT' or 'RIGHT', anchor, 'CENTER', 0, 0)
	else
		stem:SetSize(m.px, length)
		stem:SetPoint(s >= 0 and 'BOTTOM' or 'TOP', anchor, 'CENTER', 0, 0)
	end
end

-- Keys -----------------------------------------------------------------------------
-- The outer frame takes "is it running", the face "is it only the global
-- cooldown". Square keys have a 1 px host border, round keys a ring, and
-- borderless keys show only the cropped icon.
local function MakeKey(parent, level)
	local key = CreateFrame('Frame', nil, parent)
	key:SetFrameLevel(level)
	key:EnableMouse(false)
	key.face = CreateFrame('Frame', nil, key)
	key.face:SetAllPoints(key)
	key.face:SetFrameLevel(level + 1)
	key.back = key.face:CreateTexture(nil, 'BACKGROUND')
	key.back:SetTexture(WHITE)
	key.back:SetAllPoints(key)
	key.ring = key.face:CreateTexture(nil, 'BORDER')
	key.ring:SetTexture(ROUND)
	key.ring:SetAllPoints(key)
	key.edges = Hud.Border(key.face, key, 'BORDER')
	key.icon = key.face:CreateTexture(nil, 'ARTWORK')
	key.mask = key.face:CreateMaskTexture()
	key.mask:SetTexture(ROUND, 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE')
	key.mask:SetAllPoints(key.icon)
	key.text = CreateFrame('Frame', nil, key)
	key.text:SetAllPoints(key)
	key.text:SetFrameLevel(level + 3)
	key.count = key.text:CreateFontString(nil, 'OVERLAY')
	key.count:SetPoint('TOPRIGHT', key, 'TOPRIGHT', 1, 1)
	key.chip = CreateFrame('Frame', nil, key)
	key.chip:SetFrameLevel(level + 2)
	key.chip.fill = key.chip:CreateTexture(nil, 'BACKGROUND')
	key.chip.fill:SetTexture(WHITE)
	key.chip.fill:SetAllPoints()
	key.chip.edges = Hud.Border(key.chip)
	key.time = key.text:CreateFontString(nil, 'OVERLAY')
	key.time:SetWordWrap(false)
	return key
end

local function StyleKey(key, m, kind)
	local db = DB()
	local px, style = m.px, db.keyStyle or 'square'
	local weight = floor(Clamp(db.borderWeight, 1, 0, 4) + 0.5) * px
	key:SetSize(m.size, m.size)
	local borderKey = kind == 'harm' and 'harmColor' or ((kind == 'cooldown' and db.kindBorders ~= false) and 'cooldownColor' or 'borderColor')
	key.icon:ClearAllPoints()
	if key.masked then key.icon:RemoveMaskTexture(key.mask); key.masked = nil end
	if style == 'round' then
		key.back:Hide(); Hud.ShowAll(key.edges, false)
		key.ring:SetShown(weight > 0)
		Tint(key.ring, borderKey, 1)
		key.icon:SetPoint('TOPLEFT', key, 'TOPLEFT', weight, -weight)
		key.icon:SetPoint('BOTTOMRIGHT', key, 'BOTTOMRIGHT', -weight, weight)
		key.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
		key.icon:AddMaskTexture(key.mask); key.masked = true
	elseif style == 'borderless' then
		key.back:Hide(); key.ring:Hide(); Hud.ShowAll(key.edges, false)
		key.icon:SetAllPoints(key)
		key.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	else
		key.ring:Hide()
		key.back:Show()
		Tint(key.back, 'chipColor', 1)
		Hud.ShowAll(key.edges, weight > 0)
		if weight > 0 then Hud.PlaceBorder(key.edges, key, weight); Hud.TintAll(key.edges, unpack(palette[borderKey])) end
		local inset = weight + (weight > 0 and px or 0)
		key.icon:SetPoint('TOPLEFT', key, 'TOPLEFT', inset, -inset)
		key.icon:SetPoint('BOTTOMRIGHT', key, 'BOTTOMRIGHT', -inset, inset)
		key.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	-- Stack count and time.
	Hud.SetFont(key.count, db.font, max(8, floor(m.size * 0.38)), 'OUTLINE')
	key.count:SetTextColor(unpack(palette.textColor))
	local timeStyle, size = db.timeStyle or 'text', floor(Clamp(db.timeSize, 10, 6, 20) + 0.5)
	local chip = key.chip
	key.time:ClearAllPoints()
	chip:ClearAllPoints()
	chip:SetSize(m.chipW, size + 3)
	chip:SetPoint('TOP', key, 'BOTTOM', 0, -1)
	chip:SetShown(timeStyle == 'chip')
	if timeStyle == 'chip' then
		local c = palette.chipColor
		chip.fill:SetVertexColor(c[1], c[2], c[3], c[4] or 0.85)
		Hud.PlaceBorder(chip.edges, chip, px)
		Hud.TintAll(chip.edges, unpack(palette.borderColor))
		key.time:SetPoint('CENTER', chip, 'CENTER', 0, 0)
		Hud.SetFont(key.time, db.font, size, '')
	elseif timeStyle == 'inside' then
		key.time:SetPoint('CENTER', key, 'CENTER', 0, 0)
		Hud.SetFont(key.time, db.font, size, 'OUTLINE')
	else
		key.time:SetPoint('TOP', key, 'BOTTOM', 0, -2)
		Hud.SetFont(key.time, db.font, size, 'OUTLINE')
	end
	key.time:SetShown(timeStyle ~= 'none')
	key.time:SetTextColor(unpack(palette.textColor))
end

-- Entries --------------------------------------------------------------------------
local function NewEntry(index)
	local entry = {index = index}
	entry.bar = CreateFrame('StatusBar', nil, clip)
	entry.bar:SetStatusBarTexture(WHITE)
	entry.bar:EnableMouse(false)
	local fill = entry.bar:GetStatusBarTexture()
	fill:SetAlpha(0)
	-- An exact edge, not one snapped to the pixel grid, so the key glides.
	if fill.SetSnapToPixelGrid then fill:SetSnapToPixelGrid(false); fill:SetTexelSnappingBias(0) end
	entry.point = CreateFrame('Frame', nil, entry.bar)
	entry.point:SetSize(1, 1)
	local level = holder:GetFrameLevel() + 8 + index * 5
	entry.gate = CreateFrame('Frame', nil, entry.bar)
	entry.gate:SetAllPoints(clip)
	entry.gate:EnableMouse(false)
	-- The window: shown only while the time left is on the line.
	entry.window = CreateFrame('Frame', nil, entry.gate)
	entry.window:SetAllPoints(clip)
	entry.window:EnableMouse(false)
	entry.window:SetAlpha(0)
	entry.motion = CreateFrame('Frame', nil, entry.window)
	entry.motion:SetAllPoints(clip)
	entry.motion:EnableMouse(false)
	entry.key = MakeKey(entry.motion, level)
	entry.stem = entry.key:CreateTexture(nil, 'BACKGROUND', nil, -4)
	entry.stem:SetTexture(WHITE)
	entry.tick = entry.key:CreateTexture(nil, 'OVERLAY', nil, 4)
	entry.tick:SetTexture(WHITE)
	entry.bar:Hide()
	entries[index] = entry
	return entry
end

local function LayoutEntry(entry)
	local db, m = DB(), metrics
	if not m then return end
	local bar = entry.bar
	bar:SetOrientation(m.vertical and 'VERTICAL' or 'HORIZONTAL')
	bar:SetReverseFill(db.reverse and true or false)
	bar:SetMinMaxValues(0, MaxTime() * RANGE)
	bar:ClearAllPoints()
	local zero = m.vertical and (db.reverse and 'TOP' or 'BOTTOM') or (db.reverse and 'RIGHT' or 'LEFT')
	bar:SetPoint(zero, lane, zero, 0, 0)
	if m.vertical then bar:SetSize(m.px, m.length * RANGE) else bar:SetSize(m.length * RANGE, m.px) end
	entry.point:ClearAllPoints()
	entry.point:SetPoint('CENTER', bar:GetStatusBarTexture(), Edge())
	StyleKey(entry.key, m, entry.kind)
	Tint(entry.stem, 'lineColor', 0.55)
	entry.tick:ClearAllPoints()
	entry.tick:SetSize(3 * m.px, 3 * m.px)
	entry.tick:SetPoint('CENTER', entry.point, 'CENTER', 0, 0)
	Tint(entry.tick, 'accentColor', 1)
	if entry.sNow then PlaceCell(entry.key, entry.point, entry.sNow, m, entry.stem) end
end

-- Lanes ------------------------------------------------------------------------------
local prevLane, laneNow = {}, {}
local Arrange, Ease
do
	-- Work out every visible key's lane; keys still beyond the line keep theirs.
	function Arrange()
		local m = metrics
		if not m or activeCount == 0 then return end
		local length, maxTime, lanes = m.length, MaxTime(), m.lanes
		local half = m.cellAlong / 2 + m.gap / 2
		local busy = {}
		for k = 1, lanes do busy[k] = {} end
		local function Free(k, lo, hi)
			for _, span in ipairs(busy[k]) do
				if lo < span[2] and hi > span[1] then return false end
			end
			return true
		end
		local known, unknown = {}, {}
		for index = 1, activeCount do
			local entry = entries[index]
			local left = entry.estimate
			if left and left > maxTime then
				local had = entry.identity and prevLane[entry.identity]
				entry.lane = (had and had <= lanes) and had or 1
			elseif left then
				entry.pos = length * left / maxTime
				known[#known + 1] = entry
			else
				unknown[#unknown + 1] = entry
			end
		end
		table.sort(known, function(a, b) return a.pos < b.pos end)
		for _, entry in ipairs(known) do
			local lo, hi = entry.pos - half, entry.pos + half
			local choice
			local had = entry.identity and prevLane[entry.identity]
			if had and had <= lanes and Free(had, lo, hi) then choice = had end
			if not choice then
				for k = 1, lanes do if Free(k, lo, hi) then choice = k break end end
			end
			if not choice then
				choice = 1
				for k = 2, lanes do if #busy[k] < #busy[choice] then choice = k end end
			end
			entry.lane = choice
			local list = busy[choice]
			list[#list + 1] = {lo, hi}
		end
		for order, entry in ipairs(unknown) do entry.lane = (order - 1) % lanes + 1 end
		for index = 1, activeCount do
			local entry = entries[index]
			entry.sGoal = LaneStart(m, entry.lane or 1)
			if entry.identity then prevLane[entry.identity] = entry.lane end
			if entry.sNow == nil then
				-- New: slide into its lane from a little further out.
				local fresh = entry.fresh and not DB().reduceMotion
				entry.sNow = entry.sGoal + (fresh and (entry.sGoal >= 0 and 8 or -8) or 0)
				PlaceCell(entry.key, entry.point, entry.sNow, m, entry.stem)
			end
		end
	end

	function Ease(entry, elapsed)
		if entry.fade then
			entry.fade = min(1, entry.fade + elapsed / 0.2)
			entry.motion:SetAlpha(entry.fade)
			if entry.fade >= 1 then entry.fade = nil end
		end
		if not (entry.sGoal and entry.sNow) then return end
		local ds = entry.sGoal - entry.sNow
		if abs(ds) < 0.05 then
			if ds ~= 0 then
				entry.sNow = entry.sGoal
				PlaceCell(entry.key, entry.point, entry.sNow, metrics, entry.stem)
				if entry.identity then laneNow[entry.identity] = entry.sNow end
			end
			return
		end
		entry.sNow = entry.sNow + ds * (DB().reduceMotion and 1 or min(1, elapsed * 12))
		PlaceCell(entry.key, entry.point, entry.sNow, metrics, entry.stem)
		if entry.identity then laneNow[entry.identity] = entry.sNow end
	end
end

-- Timing ---------------------------------------------------------------------------
local known, knownAt = {}, {}
local Tick
do
	-- 0 below 0.05 s (run out, or a cooldown that is ready), 1 up to the line's
	-- length, 0 beyond: evaluated by the duration object itself, so a secret time
	-- is never read; the answer goes straight to an alpha.
	local windowCurves = {}
	local function WindowCurve(maxTime)
		local curve = windowCurves[maxTime]
		if curve ~= nil then return curve or nil end
		curve = false
		if C_CurveUtil and C_CurveUtil.CreateCurve then
			local ok, made = pcall(C_CurveUtil.CreateCurve)
			if ok and made then
				if made.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step then made:SetType(Enum.LuaCurveType.Step) end
				made:AddPoint(0, 0)
				made:AddPoint(0.05, 1)
				made:AddPoint(maxTime + 0.001, 0)
				curve = made
			end
		end
		windowCurves[maxTime] = curve
		return curve or nil
	end

	local function OnLine(left, maxTime) return (left >= 0.05 and left <= maxTime) and 1 or 0 end

	function Tick(entry, now)
		local db = DB()
		local remaining, secret, value = nil, false, nil
		if entry.duration then
			local ok
			ok, value = pcall(entry.duration.GetRemainingDuration, entry.duration)
			if not ok then return end
			entry.bar:SetValue(value, IMMEDIATE)
			if IsSecret(value) then secret = true else remaining = value end
		elseif entry.expires then
			remaining = max(entry.expires - now, 0)
			entry.bar:SetValue(remaining, IMMEDIATE)
		end
		local id = entry.identity
		if remaining then
			entry.last, entry.estimate = remaining, remaining
			if id then known[id], knownAt[id] = remaining, now end
		elseif secret then
			local base = id and known[id]
			entry.estimate = base and max(base - (now - knownAt[id]), 0) or nil
		end
		if db.timeStyle ~= 'none' then
			local text = entry.key.time
			if remaining then text:SetText(TimeText(remaining))
			elseif entry.estimate and entry.estimate >= 60 then text:SetText(TimeText(entry.estimate))
			elseif secret then text:SetFormattedText('%.1f', value) end -- the widget formats a secret
		end
		local maxTime = MaxTime()
		if remaining then
			entry.window:SetAlpha(OnLine(remaining, maxTime))
		else
			local curve = secret and entry.duration.EvaluateRemainingDuration and WindowCurve(maxTime)
			local shown = false
			if curve then
				local ok, alpha = pcall(entry.duration.EvaluateRemainingDuration, entry.duration, curve, 0)
				if ok then entry.window:SetAlpha(alpha); shown = true end
			end
			if not shown then entry.window:SetAlpha(entry.estimate and OnLine(entry.estimate, maxTime) or 1) end
		end
	end
end

driver:SetScript('OnUpdate', (function()
	local wait, sinceArrange = 0, 0
	return function(self, elapsed)
		wait = wait + elapsed
		if wait < 1 / 30 then return end
		local step = wait
		wait = 0
		if activeCount == 0 or not holder:IsVisible() then self:Hide() return end
		local now = GetTime()
		for index = 1, activeCount do Safe(Tick, entries[index], now) end
		sinceArrange = sinceArrange + step
		if sinceArrange >= 0.25 then
			sinceArrange = 0
			Safe(Arrange)
		end
		for index = 1, activeCount do Safe(Ease, entries[index], step) end
	end
end)())

-- Collecting -----------------------------------------------------------------------
local Collect
do
	local actionSpells, actionDirty = {}, true
	JI.MarkAuraTimelineActions = function() actionDirty = true end
	local function ActionSpells()
		if not actionDirty then return actionSpells end
		actionDirty = false
		wipe(actionSpells)
		local seen = {}
		local has = (C_ActionBar and C_ActionBar.HasAction) or HasAction
		for slot = 1, 180 do
			if has and Plain(has, slot) and GetActionInfo then
				local ok, kind, id, subType = pcall(GetActionInfo, slot)
				if ok and not IsSecret(kind) and not IsSecret(id) and id and not seen[id]
					and (kind == 'spell' or (kind == 'macro' and not IsSecret(subType) and subType == 'spell')) then
					seen[id] = true
					actionSpells[#actionSpells + 1] = id
				end
			end
		end
		return actionSpells
	end

	-- Remembered plainly, by aura and by spell, for when a fight hides lengths.
	local function Memory()
		local byAura, bySpell, count = {}, {}, 0
		return function(id, spellID)
			if count > 400 then wipe(byAura); wipe(bySpell); count = 0 end
			count = count + 1
			if not IsSecret(id) and id ~= nil then byAura[id] = true end
			if not IsSecret(spellID) and spellID ~= nil then bySpell[spellID] = true end
		end, function(id, spellID)
			if not IsSecret(id) and id ~= nil and byAura[id] then return true end
			if not IsSecret(spellID) and spellID ~= nil and bySpell[spellID] then return true end
			return false
		end
	end
	local RememberLong, KnownLong = Memory()
	local RememberLasting, KnownLasting = Memory()

	-- One aura as an item, or nil. Auras that last until cancelled never show.
	local function AuraItem(data, harmful)
		local length = data.duration
		local id, spellID = data.auraInstanceID, data.spellId
		if Blocked(spellID) then return nil end
		local plainLength = not IsSecret(length)
		if plainLength and (not length or length <= 0) then
			RememberLasting(id, spellID)
			return nil
		end
		if not plainLength and KnownLasting(id, spellID) then return nil end
		local longest = Clamp(DB().longBuffs, 0, 0, 36000)
		if not harmful and longest > 0 then
			if not plainLength then
				if KnownLong(id, spellID) then return nil end
			elseif length > longest then
				RememberLong(id, spellID)
				return nil
			end
		end
		local item = {icon = data.icon, kind = harmful and 'harm' or 'help'}
		item.auraID, item.apps = id, data.applications
		if not IsSecret(id) then item.identity = id end
		if C_UnitAuras.GetAuraDuration and (IsSecret(id) or id ~= nil) then
			local ok, duration = pcall(C_UnitAuras.GetAuraDuration, 'player', id)
			if ok and duration and duration.GetRemainingDuration then item.duration = duration end
		end
		if item.duration and not plainLength and item.duration.IsZero then
			local okZero, zero = pcall(item.duration.IsZero, item.duration)
			if okZero then
				if IsSecret(zero) then item.zeroFlag, item.hasZero = zero, true
				elseif zero then return nil end
			end
		end
		local expires = data.expirationTime
		if not item.duration then
			if IsSecret(expires) or not plainLength or not expires or expires <= 0 then return nil end
			item.expires = expires
		end
		if plainLength and not IsSecret(expires) and type(expires) == 'number' and expires > 0 then
			item.later = (expires - GetTime()) > MaxTime()
		end
		return item
	end

	local function CooldownItem(spellID)
		if Blocked(spellID) or not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
		local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
		if not ok or type(info) ~= 'table' then return nil end
		local isActive, onGCD, length = info.isActive, info.isOnGCD, info.duration
		if not IsSecret(isActive) and isActive == false then return nil end
		if not IsSecret(onGCD) and onGCD then return nil end
		if not IsSecret(length) then
			if not length or length <= 0 or length < Clamp(DB().minCooldown, 5, 0, 600) then return nil end
		end
		local icon
		if C_Spell.GetSpellTexture then
			local got, texture = pcall(C_Spell.GetSpellTexture, spellID)
			if got then icon = texture end
		end
		local item = {icon = icon, kind = 'cooldown', identity = 'cd'..spellID}
		if IsSecret(isActive) then item.activeFlag, item.hasActive = isActive, true end
		if IsSecret(onGCD) then item.gcdFlag, item.hasGCD = onGCD, true end
		if C_Spell.GetSpellCooldownDuration then
			local got, duration = pcall(C_Spell.GetSpellCooldownDuration, spellID)
			if got and duration and duration.GetRemainingDuration then item.duration = duration end
		end
		if item.duration and item.duration.IsZero then
			local okZero, zero = pcall(item.duration.IsZero, item.duration)
			if okZero then
				if IsSecret(zero) then item.zeroFlag, item.hasZero = zero, true elseif zero then return nil end
			end
		end
		-- Unknown whether it runs at all: shows only if it does, and uses no slot.
		item.uncounted = item.hasActive or item.hasZero
		if not item.duration then
			local start = info.startTime
			if IsSecret(start) or IsSecret(length) or not start or not length then return nil end
			item.expires = start + length
		end
		return item
	end

	-- What is on the line (or may be) first, then cooldowns, then auras waiting
	-- beyond the line, so slots go to what can be seen.
	function Collect()
		local items, db = {}, DB()
		local limit = floor(Clamp(db.maxEntries, 12, 1, 30) + 0.5)
		local counted = 0
		local function Add(item)
			if not item or counted >= limit then return end
			items[#items + 1] = item
			if not item.uncounted then counted = counted + 1 end
		end
		local now, later = {}, {}
		local function Scan(filter, harmful)
			for index = 1, 40 do
				local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, 'player', index, filter)
				if not ok or type(data) ~= 'table' then return end
				local built, item = pcall(AuraItem, data, harmful)
				if not built then
					if geterrorhandler then geterrorhandler()(item) end
				elseif item then
					local list = item.later and later or now
					list[#list + 1] = item
				end
			end
		end
		if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
			if db.buffs ~= 'off' then Scan(db.buffs == 'all' and 'HELPFUL' or 'HELPFUL|PLAYER', false) end
			if db.debuffs then Scan('HARMFUL', true) end
		end
		for _, item in ipairs(now) do Add(item) end
		if db.cooldowns then
			for _, spellID in ipairs(ActionSpells()) do
				if counted >= limit then break end
				local built, item = pcall(CooldownItem, spellID)
				if built then Add(item) elseif geterrorhandler then geterrorhandler()(item) end
			end
		end
		for _, item in ipairs(later) do Add(item) end
		return items
	end
end

-- Assigning ------------------------------------------------------------------------
local function Count(key, item)
	local text = ''
	if DB().counts and item.kind ~= 'cooldown' then
		local apps = item.apps
		if IsSecret(apps) then
			local api = C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount
			if api then
				local ok, shown = pcall(api, 'player', item.auraID, 2, 999)
				if ok then key.count:SetText(shown) return end
			end
		elseif type(apps) == 'number' and apps > 1 then
			text = tostring(apps)
		end
	end
	key.count:SetText(text)
end

local function Clear(entry)
	entry.bar:Hide()
	entry.duration, entry.expires, entry.identity, entry.last = nil, nil, nil, nil
	entry.estimate, entry.lane, entry.sGoal, entry.sNow, entry.fade = nil, nil, nil, nil, nil
end

-- Every field is reset, so a reused entry carries nothing over.
local function Assign(entry, item, seen)
	entry.duration, entry.expires, entry.last = item.duration, item.expires, nil
	entry.identity, entry.estimate = item.identity, nil
	entry.lane, entry.sGoal = nil, nil
	local id = item.identity
	entry.sNow = id and laneNow[id] or nil
	entry.fresh = (id ~= nil and not seen[id]) and true or nil
	entry.kind = item.kind
	local key = entry.key
	key.icon:SetTexture(item.icon)
	key.time:SetText('')
	key:SetAlpha(1)
	key.face:SetAlpha(1)
	Count(key, item)
	local top = MaxTime() * RANGE
	entry.bar:SetMinMaxValues(0, top)
	-- Until its first tick, the key waits out of sight past the line.
	entry.bar:SetValue(top, IMMEDIATE)
	entry.window:SetAlpha(0)
	entry.gate:SetAlpha(1)
	if item.hasZero and entry.gate.SetAlphaFromBoolean then entry.gate:SetAlphaFromBoolean(item.zeroFlag, 0, 1) end
	if item.hasActive and key.SetAlphaFromBoolean then key:SetAlphaFromBoolean(item.activeFlag, 1, 0) end
	if item.hasGCD and key.face.SetAlphaFromBoolean then key.face:SetAlphaFromBoolean(item.gcdFlag, 0, 1) end
	if entry.fresh and not DB().reduceMotion then
		entry.fade = 0
		entry.motion:SetAlpha(0)
	else
		entry.fade = nil
		entry.motion:SetAlpha(1)
	end
	LayoutEntry(entry)
	entry.bar:Show()
end

local function Prune(source, keep)
	for id in pairs(source) do if not keep[id] then source[id] = nil end end
end

local function Rebuild()
	if not holder then return end
	if not DB().enable and not previewing then outer:Hide() driver:Hide() return end
	outer:Show()
	if previewing then return end
	local seen = {}
	for index = 1, activeCount do
		local entry = entries[index]
		if entry.identity then seen[entry.identity] = true end
	end
	local items = Collect()
	local now, shown = {}, 0
	for _, item in ipairs(items) do
		local entry = entries[shown + 1] or NewEntry(shown + 1)
		if Safe(Assign, entry, item, seen) then
			shown = shown + 1
			if item.identity then now[item.identity] = true end
		else
			Clear(entry)
		end
	end
	for index = shown + 1, #entries do Clear(entries[index]) end
	activeCount = shown
	Prune(known, now); Prune(knownAt, now); Prune(prevLane, now); Prune(laneNow, now)
	if activeCount > 0 then
		local stamp = GetTime()
		for index = 1, activeCount do Safe(Tick, entries[index], stamp) end
		Safe(Arrange)
		driver:Show()
	else
		driver:Hide()
	end
end

local Queue
do
	local queued
	function Queue()
		if queued or not C_Timer then return end
		queued = true
		C_Timer.After(0, function()
			queued = nil
			Safe(Rebuild)
		end)
	end
end

-- The track ------------------------------------------------------------------------
local function Mark(pool, index, minor)
	local mark = pool[index]
	if not mark then
		mark = {tex = holder:CreateTexture(nil, 'ARTWORK')}
		mark.tex:SetTexture(WHITE)
		if not minor then mark.text = holder:CreateFontString(nil, 'OVERLAY') end
		pool[index] = mark
	end
	return mark
end

local function PlaceMark(mark, seconds, m, height, alpha)
	local db = DB()
	local fraction = Fraction(seconds)
	if db.reverse then fraction = 1 - fraction end
	local along = m.length * fraction
	local tex, toward = mark.tex, m.labelsUp
	tex:ClearAllPoints()
	Tint(tex, 'tickColor', alpha)
	if m.vertical then
		tex:SetSize(height, m.px)
		tex:SetPoint(toward and 'LEFT' or 'RIGHT', lane, 'BOTTOM', 0, along)
	else
		tex:SetSize(m.px, height)
		tex:SetPoint(toward and 'BOTTOM' or 'TOP', lane, 'LEFT', along, 0)
	end
	tex:SetShown(db.ticks and true or false)
	if mark.text then
		local text = mark.text
		Hud.SetFont(text, db.font, floor(Clamp(db.labelSize, 9, 6, 16) + 0.5), 'OUTLINE')
		local c = palette.labelColor
		text:SetTextColor(c[1], c[2], c[3], c[4] or 1)
		text:ClearAllPoints()
		if m.vertical then
			if toward then text:SetPoint('LEFT', tex, 'RIGHT', 2, 0) else text:SetPoint('RIGHT', tex, 'LEFT', -2, 0) end
		else
			if toward then text:SetPoint('BOTTOM', tex, 'TOP', 0, 1) else text:SetPoint('TOP', tex, 'BOTTOM', 0, -1) end
		end
		text:SetText(Label(seconds))
		text:SetShown(db.labels and true or false)
	end
end

-- The line: a hairline, a bordered bar, dashes, or nothing but the ticks.
local function LayoutLine(m)
	local db = DB()
	local style = db.lineStyle or 'solid'
	local weight = floor(Clamp(db.lineWeight, 1, 1, 6) + 0.5) * m.px
	local thickness = style == 'bar' and max(weight, 3 * m.px) or weight
	line:ClearAllPoints()
	if m.vertical then
		line:SetPoint('BOTTOM', lane, 'BOTTOM'); line:SetSize(thickness, m.length)
	else
		line:SetPoint('LEFT', lane, 'LEFT'); line:SetSize(m.length, thickness)
	end
	Tint(line, 'lineColor')
	line:SetShown(style == 'solid' or style == 'bar')
	line.shadow:ClearAllPoints()
	line.shadow:SetPoint('TOPLEFT', line, 'TOPLEFT', -m.px, m.px)
	line.shadow:SetPoint('BOTTOMRIGHT', line, 'BOTTOMRIGHT', m.px, -m.px)
	line.shadow:SetShown((style == 'solid' or style == 'bar') and db.lineShadow and true or false)
	Hud.PlaceBorder(line.edges, line, m.px, m.px)
	Hud.TintAll(line.edges, unpack(palette.borderColor))
	Hud.ShowAll(line.edges, style == 'bar')
	-- Dashes: 6-unit segments every 10 units.
	local count = style == 'dashed' and min(200, floor(m.length / 10)) or 0
	local dash = 6
	for index = 1, count do
		local piece = line.dashes[index]
		if not piece then
			piece = holder:CreateTexture(nil, 'BORDER')
			piece:SetTexture(WHITE)
			line.dashes[index] = piece
		end
		piece:ClearAllPoints()
		local offset = (index - 1) * 10
		if m.vertical then
			piece:SetSize(weight, dash); piece:SetPoint('BOTTOM', lane, 'BOTTOM', 0, offset)
		else
			piece:SetSize(dash, weight); piece:SetPoint('LEFT', lane, 'LEFT', offset, 0)
		end
		Tint(piece, 'lineColor')
		piece:Show()
	end
	for index = count + 1, #line.dashes do line.dashes[index]:Hide() end
	-- Caps: zero ("now") and the far end.
	local zeroPoint = m.vertical and (db.reverse and 'TOP' or 'BOTTOM') or (db.reverse and 'RIGHT' or 'LEFT')
	local farSide = m.vertical and (db.reverse and 'BOTTOM' or 'TOP') or (db.reverse and 'LEFT' or 'RIGHT')
	local cap = db.zeroCap or 'dot'
	caps.zero:ClearAllPoints()
	caps.zero:SetPoint('CENTER', lane, zeroPoint)
	if cap == 'bar' then
		local long, short = 12, max(2 * m.px, weight * 2)
		if m.vertical then caps.zero:SetSize(long, short) else caps.zero:SetSize(short, long) end
		caps.zero.tex:SetTexture(WHITE)
	else
		caps.zero:SetSize(7, 7)
		caps.zero.tex:SetTexture(ROUND)
	end
	caps.zero:SetShown(cap ~= 'none')
	Tint(caps.zero.tex, 'accentColor', 1)
	caps.far:ClearAllPoints(); caps.far:SetSize(4, 4); caps.far:SetPoint('CENTER', lane, farSide)
	Tint(caps.far.tex, 'lineColor')
	caps.far:SetShown(db.farCap and true or false)
end

local function LayoutTrack()
	local db = DB()
	ReadColors()
	local scale = Clamp(db.scale, 1, 0.5, 2)
	holder:SetScale(scale)
	outer:SetFrameStrata(db.strata or 'MEDIUM')
	holder:SetFrameStrata(db.strata or 'MEDIUM')
	local m = Metrics()
	m.px = Hud.Pixel(holder)
	metrics = m
	local length = m.length
	local upExt = m.upLanes > 0 and (m.baseUp + m.upLanes * m.pitch) or (m.labelsUp and m.labelBand + 2 or 4)
	local downExt = m.downLanes > 0 and (m.baseDown + m.downLanes * m.pitch) or ((not m.labelsUp) and m.labelBand + 2 or 4)
	lane:ClearAllPoints()
	if m.vertical then
		holder:SetSize(upExt + downExt, length + 12)
		outer:SetSize((upExt + downExt) * scale, (length + 12) * scale)
		lane:SetPoint('BOTTOMLEFT', holder, 'BOTTOMLEFT', downExt, 6)
		lane:SetSize(m.px, length)
	else
		holder:SetSize(length + 12, upExt + downExt)
		outer:SetSize((length + 12) * scale, (upExt + downExt) * scale)
		lane:SetPoint('BOTTOMLEFT', holder, 'BOTTOMLEFT', 6, downExt)
		lane:SetSize(length, m.px)
	end
	LayoutLine(m)
	-- The clip: the line plus a key's overhang at zero and half a key at the far
	-- end, so a key whose time left is the whole line still shows and anything
	-- longer slides out of sight. Across, it holds every lane.
	local over, farOver = m.cellAlong / 2 + 4, m.cellAlong / 2 + 1
	local up, down = upExt + 8, downExt + 8
	clip:ClearAllPoints()
	if m.vertical then
		if db.reverse then
			clip:SetPoint('TOPLEFT', lane, 'TOP', -down, over)
			clip:SetPoint('BOTTOMRIGHT', lane, 'TOP', up, -(length + farOver))
		else
			clip:SetPoint('BOTTOMLEFT', lane, 'BOTTOM', -down, -over)
			clip:SetPoint('TOPRIGHT', lane, 'BOTTOM', up, length + farOver)
		end
	elseif db.reverse then
		clip:SetPoint('BOTTOMRIGHT', lane, 'RIGHT', over, -down)
		clip:SetPoint('TOPLEFT', lane, 'RIGHT', -(length + farOver), up)
	else
		clip:SetPoint('BOTTOMLEFT', lane, 'LEFT', -over, -down)
		clip:SetPoint('TOPRIGHT', lane, 'LEFT', length + farOver, up)
	end
	-- Labelled marks, and minor ticks between them on the linear scale.
	local maxTime = MaxTime()
	local labelled, isLabel = {}, {}
	for _, seconds in ipairs(MARKS) do
		if seconds <= maxTime then labelled[#labelled + 1] = seconds; isLabel[seconds] = true end
	end
	if labelled[#labelled] ~= maxTime then labelled[#labelled + 1] = maxTime; isLabel[maxTime] = true end
	for index, seconds in ipairs(labelled) do
		PlaceMark(Mark(ticks, index), seconds, m, (seconds == 0 or seconds == maxTime) and 5 or 4, 0.8)
	end
	for index = #labelled + 1, #ticks do ticks[index].tex:Hide(); ticks[index].text:Hide() end
	local count, seconds = 0, 0
	while seconds < maxTime and count < 90 do
		local step = seconds < 10 and 1 or (seconds < 60 and 5 or (seconds < 300 and 30 or 60))
		seconds = seconds + step
		if seconds < maxTime and not isLabel[seconds] then
			count = count + 1
			PlaceMark(Mark(minors, count, true), seconds, m, 2, 0.35)
		end
	end
	for index = count + 1, #minors do minors[index].tex:Hide() end
	for index, entry in ipairs(entries) do
		entry.sNow = entry.sGoal or entry.sNow
		if index <= activeCount then LayoutEntry(entry) end
	end
	Safe(Arrange)
end

-- Placement ------------------------------------------------------------------------
local function ElvUIReady()
	local E = Hud.ElvUI()
	return E and E.CreateMover and E.Initialized and E or nil
end

local function EllesmereUnlock()
	local EUI = _G.EllesmereUI
	return type(EUI) == 'table' and EUI.RegisterUnlockElements and EUI.MakeUnlockElement and EUI or nil
end

-- With no host mover: the saved offset from the bottom of the screen.
local function ApplyFallback()
	local db = DB()
	local stored = db.unlockPosition
	outer:ClearAllPoints()
	if EllesmereUnlock() and type(stored) == 'table' and stored.point then
		outer:SetPoint(stored.point, UIParent, stored.relPoint or stored.point, stored.x or 0, stored.y or 0)
	else
		outer:SetPoint('BOTTOM', UIParent, 'BOTTOM', Clamp(db.x, 0, -4000, 4000), Clamp(db.y, 260, -4000, 4000))
	end
end

local moverState = {}
local function SetupMovers()
	if InCombatLockdown() then return end
	if Hud.ElvUI() and not ElvUIReady() then
		-- ElvUI is loaded but not initialized yet: its mover comes on login.
		if not moverState.elvui then ApplyFallback() end
		return
	end
	local E = ElvUIReady()
	if E then
		if not moverState.elvui then
			moverState.elvui = true
			ApplyFallback()
			E:CreateMover(outer, MOVER, 'Aura Timeline', nil, nil, nil, 'ALL,GENERAL',
				function() return not DB().enable end, 'jiberishicons,plus,auraTimeline')
			-- Show the sample keys while ElvUI's movers are out.
			hooksecurefunc(E, 'ToggleMovers', function(_, show) JI:SetAuraTimelinePreview(show and DB().enable) end)
		end
		local created = E.CreatedMovers and E.CreatedMovers[MOVER]
		if DB().enable and not created and E.DisabledMovers and E.DisabledMovers[MOVER] then E:EnableMover(MOVER)
		elseif not DB().enable and created then E:DisableMover(MOVER) end
		return
	end
	local EUI = EllesmereUnlock()
	if EUI and not moverState.ellesmere then
		moverState.ellesmere = true
		EUI:RegisterUnlockElements({EUI.MakeUnlockElement({
			key = UNLOCK_KEY, label = 'Aura Timeline', group = 'JiberishIcons', order = 900, noResize = true,
			getFrame = function() return outer end,
			getSize = function() return outer:GetWidth(), outer:GetHeight() end,
			isHidden = function() return not DB().enable end,
			savePos = function(_, point, relPoint, x, y)
				if type(point) == 'string' and type(x) == 'number' and type(y) == 'number' then
					DB().unlockPosition = {point = point, relPoint = relPoint or point, x = x, y = y}
				end
				if not EUI._unlockActive and not InCombatLockdown() then ApplyFallback() end
			end,
			loadPos = function()
				local stored = DB().unlockPosition
				if type(stored) ~= 'table' or not stored.point then return nil end
				return {point = stored.point, relPoint = stored.relPoint or stored.point, x = stored.x, y = stored.y}
			end,
			clearPos = function() DB().unlockPosition = nil end,
			applyPos = function() if not InCombatLockdown() then ApplyFallback() end end,
		})}, 'JiberishIcons')
		if EUI.RegisterUnlockModeListener then
			EUI:RegisterUnlockModeListener('JiberishIcons_AuraTimeline', function(on) JI:SetAuraTimelinePreview(on and DB().enable) end)
		end
	end
	ApplyFallback()
end

function JI:AuraTimelineMoverHost()
	if Hud.ElvUI() then return 'elvui' end
	if EllesmereUnlock() then return 'ellesmereui' end
	return nil
end

function JI:ToggleAuraTimelineMovers()
	if InCombatLockdown() then return end
	local E = ElvUIReady()
	if E and E.ToggleMoveMode then E:ToggleMoveMode() return end
	local EUI = EllesmereUnlock()
	if EUI and EUI.ToggleUnlockMode then EUI:ToggleUnlockMode() return end
	JI:SetAuraTimelinePreview(not previewing)
end

-- Preview: made-up entries counting down so the track and stacking show; the
-- last one waits past the line and slides on after a few seconds.
local FAKES = {
	{7.8, 'help', 136243}, {9.5, 'harm', 135987, 3}, {24, 'cooldown', 136085},
	{38, 'help', 135932}, {66, 'help', 136116},
}
function JI:SetAuraTimelinePreview(on)
	if not holder then return end
	previewing = on and true or false
	if not previewing then return Rebuild() end
	outer:Show()
	local stamp = GetTime()
	for index, fake in ipairs(FAKES) do
		local entry = entries[index] or NewEntry(index)
		local item = {icon = fake[3], kind = fake[2], apps = fake[4], identity = 'preview'..index, expires = stamp + fake[1]}
		Safe(Assign, entry, item, {})
	end
	for index = #FAKES + 1, #entries do Clear(entries[index]) end
	activeCount = #FAKES
	for index = 1, activeCount do Safe(Tick, entries[index], stamp) end
	Safe(Arrange)
	driver:Show()
end
function JI:IsAuraTimelinePreviewShown() return previewing end

-- Presets: complete looks for ElvUI and EllesmereUI interfaces.
JI.AuraTimelinePresets = {
	elvui = {keyStyle = 'square', borderWeight = 1, timeStyle = 'text', timeSize = 11, iconSize = 26, lineStyle = 'solid',
		lineWeight = 1, lineShadow = true, zeroCap = 'dot', farCap = true, ticks = true, labels = true, labelSize = 9,
		stems = true, spacing = 3, colors = 'host', kindBorders = true},
	ellesmereui = {keyStyle = 'round', borderWeight = 1, timeStyle = 'chip', timeSize = 9, iconSize = 24, lineStyle = 'bar',
		lineWeight = 2, lineShadow = false, zeroCap = 'bar', farCap = false, ticks = true, labels = true, labelSize = 8,
		stems = false, spacing = 4, colors = 'host', kindBorders = true},
	minimal = {keyStyle = 'borderless', borderWeight = 0, timeStyle = 'inside', timeSize = 11, iconSize = 24, lineStyle = 'dashed',
		lineWeight = 1, lineShadow = false, zeroCap = 'none', farCap = false, ticks = false, labels = false,
		stems = false, spacing = 2, colors = 'host', kindBorders = false},
}

function JI:ApplyAuraTimelinePreset(key)
	local preset = JI.AuraTimelinePresets[key]
	if not preset then return end
	local db = DB()
	db.preset = key
	for field, value in pairs(preset) do db[field] = value end
	JI:UpdateAuraTimeline()
end

-- Lifecycle ------------------------------------------------------------------------
local function Build()
	outer = CreateFrame('Frame', 'JiberishIconsAuraTimeline', UIParent)
	outer:SetFrameStrata('MEDIUM')
	outer:EnableMouse(false)
	outer:SetClampedToScreen(false)
	holder = CreateFrame('Frame', nil, outer)
	holder:SetPoint('CENTER', outer, 'CENTER', 0, 0)
	holder:EnableMouse(false)
	lane = CreateFrame('Frame', nil, holder)
	lane:EnableMouse(false)
	line = holder:CreateTexture(nil, 'BORDER')
	line:SetTexture(WHITE)
	line.shadow = holder:CreateTexture(nil, 'BACKGROUND')
	line.shadow:SetColorTexture(0, 0, 0, 0.55)
	line.edges = Hud.Border(holder, line, 'BACKGROUND')
	line.dashes = {}
	clip = CreateFrame('Frame', nil, holder)
	clip:SetClipsChildren(true)
	clip:EnableMouse(false)
	clip:SetFrameLevel(holder:GetFrameLevel() + 4)
	local function Cap()
		local cap = CreateFrame('Frame', nil, holder)
		cap:SetFrameLevel(holder:GetFrameLevel() + 3)
		cap:EnableMouse(false)
		cap.tex = cap:CreateTexture(nil, 'ARTWORK')
		cap.tex:SetAllPoints()
		cap.tex:SetTexture(WHITE)
		return cap
	end
	caps = {zero = Cap(), far = Cap()}
	-- After the whole UI was hidden (Alt+Z, a cinematic) the driver starts again.
	holder:HookScript('OnShow', function() if activeCount > 0 then driver:Show() end end)
	ticks, minors = {}, {}
	LayoutTrack()
	ApplyFallback()
end

local events
function JI:UpdateAuraTimeline()
	if not events then return end
	if not InCombatLockdown() then
		if not holder and DB().enable then Build() end
		if holder then
			Safe(LayoutTrack)
			SetupMovers()
			if not JI:AuraTimelineMoverHost() then ApplyFallback() end
		end
	end
	if previewing and holder and DB().enable then
		JI:SetAuraTimelinePreview(true)
	else
		previewing = false
		Queue()
	end
end

function JI:SetAuraTimelinePosition(x, y)
	if InCombatLockdown() then return end
	local db = DB()
	db.x, db.y = Clamp(tonumber(x), 0, -4000, 4000), Clamp(tonumber(y), 260, -4000, 4000)
	if holder and not JI:AuraTimelineMoverHost() then ApplyFallback() end
end

function JI:SetupAuraTimeline()
	if events then return end
	events = CreateFrame('Frame')
	events:RegisterUnitEvent('UNIT_AURA', 'player')
	for _, event in ipairs({'PLAYER_LOGIN', 'PLAYER_ENTERING_WORLD', 'SPELL_UPDATE_COOLDOWN', 'SPELLS_CHANGED',
		'ACTIONBAR_SLOT_CHANGED', 'PLAYER_TALENT_UPDATE', 'PLAYER_REGEN_ENABLED', 'UI_SCALE_CHANGED'}) do
		pcall(events.RegisterEvent, events, event)
	end
	events:SetScript('OnEvent', function(_, event, _, info)
		if event == 'UNIT_AURA' then
			-- Update info fields can be secret: then it counts as a full update.
			if type(info) == 'table' then
				local empty = true
				for _, field in ipairs({'isFullUpdate', 'addedAuras', 'updatedAuraInstanceIDs', 'removedAuraInstanceIDs'}) do
					local value = info[field]
					if IsSecret(value) or value then empty = false break end
				end
				if empty then return end
			end
		elseif event == 'ACTIONBAR_SLOT_CHANGED' or event == 'SPELLS_CHANGED' or event == 'PLAYER_TALENT_UPDATE' then
			JI.MarkAuraTimelineActions()
			if not DB().cooldowns then return end
		elseif event == 'SPELL_UPDATE_COOLDOWN' then
			if not DB().cooldowns then return end
		elseif event == 'PLAYER_LOGIN' or event == 'PLAYER_ENTERING_WORLD' or event == 'PLAYER_REGEN_ENABLED'
			or event == 'UI_SCALE_CHANGED' then
			-- Host movers exist only after the host has initialized.
			if C_Timer then C_Timer.After(0, function() JI:UpdateAuraTimeline() end) else JI:UpdateAuraTimeline() end
			return
		end
		if holder then Queue() end
	end)
	JI:UpdateAuraTimeline()
end
