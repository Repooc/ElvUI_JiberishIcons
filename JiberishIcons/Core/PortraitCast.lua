local JI = unpack(JiberishIcons)
local casts, driver = {}, nil
local points = {CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
	TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true}

local function IsSecret(value) return issecretvalue and issecretvalue(value) end
local function PublicNumber(value) return not IsSecret(value) and type(value) == 'number' end
local function Settings(frame) return JI.db.portraits[frame.key].cast end
local function Enabled(frame)
	local db = JI.db.portraits[frame.key]
	return db.enable and db.cast.enable and (db.shape == 'circle' or db.shape == 'circlethin') and frame.visible
end

function JI:StopPortraitCast(frame)
	local cast = frame.cast
	if not cast then return end
	cast.active, cast.duration, cast.endTime, cast.preview = nil, nil, nil, nil
	cast.ring:Clear(); cast.ring:Hide()
	cast.spell:Hide(); cast.name:Hide(); cast.time:Hide()
end

local function ReadCast(unit)
	local name, texture, startMS, endMS, empowering, _
	if UnitCastingInfo then name, _, texture, startMS, endMS = UnitCastingInfo(unit)
	elseif unit == 'player' and CastingInfo then name, _, texture, startMS, endMS = CastingInfo() end
	local channel = false
	if not IsSecret(name) and not name then
		if UnitChannelInfo then
			name, _, texture, startMS, endMS, _, _, _, empowering = UnitChannelInfo(unit)
		elseif unit == 'player' and ChannelInfo then name, _, texture, startMS, endMS = ChannelInfo() end
		channel = true
	end
	if not IsSecret(name) and not name then return end
	local empower = not IsSecret(empowering) and empowering == true
	local durationAPI
	if empower then durationAPI = UnitEmpoweredChannelDuration
	elseif channel then durationAPI = UnitChannelDuration
	else durationAPI = UnitCastingDuration end
	local duration = durationAPI and durationAPI(unit)
	return {name = name, texture = texture, startMS = startMS, endMS = endMS,
		channel = channel and not empower, empower = empower, duration = duration}
end

local function UpdateTime(frame)
	local cast, db = frame.cast, Settings(frame)
	if not cast.active then return end
	local remaining
	if cast.duration and cast.duration.GetRemainingDuration then
		remaining = cast.duration:GetRemainingDuration()
	elseif cast.endTime then remaining = math.max(0, cast.endTime - GetTime()) end
	if PublicNumber(remaining) and remaining <= 0 then
		if cast.preview and JI:ArePortraitsUnlocked() then JI:UpdatePortraitCast(frame)
		else JI:StopPortraitCast(frame) end
		return
	end
	if db.showTime and (IsSecret(remaining) or type(remaining) == 'number') then
		-- Formatting is performed by the native widget, not Lua string/math on
		-- restricted durations. The native cooldown animates the ring itself.
		cast.time:SetFormattedText('%.1f', remaining)
		cast.time:Show()
	else cast.time:Hide() end
end

function JI:UpdatePortraitCast(frame)
	local cast = frame.cast
	if not cast then return end
	if not Enabled(frame) then JI:StopPortraitCast(frame); return end
	local info = ReadCast(frame.key)
	if not info and JI:ArePortraitsUnlocked() then
		info = {name = 'Cast preview', texture = [[Interface\Icons\INV_Misc_QuestionMark]],
			startMS = GetTime() * 1000, endMS = (GetTime() + 4) * 1000, preview = true}
	end
	if not info then JI:StopPortraitCast(frame); return end
	local db = Settings(frame)
	cast.active, cast.duration, cast.endTime, cast.preview = nil, nil, nil, info.preview
	cast.channel = info.channel
	cast.ring:SetReverse(not info.channel)
	cast.ring:SetSwipeColor(unpack(info.channel and db.channelColor or db.color))
	if info.duration and cast.ring.SetCooldownFromDurationObject then
		cast.duration = info.duration
		cast.ring:SetCooldownFromDurationObject(info.duration, true)
	elseif PublicNumber(info.startMS) and PublicNumber(info.endMS) and info.endMS > info.startMS then
		local endMS = info.endMS
		if info.empower and GetUnitEmpowerHoldAtMaxTime then
			local hold = GetUnitEmpowerHoldAtMaxTime(frame.key)
			if PublicNumber(hold) then endMS = endMS + hold end
		end
		cast.endTime = endMS / 1000
		if cast.endTime <= GetTime() then JI:StopPortraitCast(frame); return end
		cast.ring:SetCooldown(info.startMS / 1000, (endMS - info.startMS) / 1000)
	else
		-- Older clients without a duration object need readable timestamps.
		JI:StopPortraitCast(frame); return
	end
	cast.active = true
	cast.ring:Show()
	cast.name:SetText(info.name); cast.name:SetShown(db.showName)
	cast.spell:Hide()
	if db.spellIcon and (IsSecret(info.texture) or info.texture) then
		cast.spell:SetTexture(info.texture)
		cast.spell:Show()
	end
	UpdateTime(frame)
end

local events = {'UNIT_SPELLCAST_START', 'UNIT_SPELLCAST_STOP', 'UNIT_SPELLCAST_FAILED',
	'UNIT_SPELLCAST_INTERRUPTED', 'UNIT_SPELLCAST_DELAYED', 'UNIT_SPELLCAST_CHANNEL_START',
	'UNIT_SPELLCAST_CHANNEL_UPDATE', 'UNIT_SPELLCAST_CHANNEL_STOP', 'UNIT_SPELLCAST_EMPOWER_START',
	'UNIT_SPELLCAST_EMPOWER_UPDATE', 'UNIT_SPELLCAST_EMPOWER_STOP'}

local function SetupDriver()
	if driver then return end
	driver = CreateFrame('Frame')
	for _, event in ipairs(events) do
		if C_EventUtils and C_EventUtils.IsEventValid then
			if C_EventUtils.IsEventValid(event) then driver:RegisterEvent(event) end
		else pcall(driver.RegisterEvent, driver, event) end
	end
	driver:SetScript('OnEvent', function(_, _, unit)
		if IsSecret(unit) or type(unit) ~= 'string' then return end
		local frame = casts[unit]
		-- Read current API state instead of matching potentially secret cast IDs.
		-- A late stop event must not clear a newer cast on this unit token.
		if frame then JI:UpdatePortraitCast(frame) end
	end)
end

function JI:CreatePortraitCast(frame)
	if frame.key ~= 'player' and frame.key ~= 'target' then return end
	if frame.cast then return end
	local ring = CreateFrame('Cooldown', nil, frame, 'CooldownFrameTemplate')
	ring:SetAllPoints(frame); ring:EnableMouse(false)
	ring:SetDrawEdge(false); ring:SetDrawBling(false); ring:SetDrawSwipe(true)
	ring:SetHideCountdownNumbers(true)
	if ring.SetUseCircularEdge then ring:SetUseCircularEdge(true) end
	-- The swipe texture is an annulus, so progress never shades the portrait.
	local textFrame = CreateFrame('Frame', nil, frame)
	textFrame:SetAllPoints(frame); textFrame:EnableMouse(false)
	local cast = {ring = ring, textFrame = textFrame,
		name = textFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall'),
		time = textFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall'),
		spell = frame:CreateTexture(nil, 'ARTWORK', nil, 2)}
	frame.cast = cast
	cast.spell:SetAllPoints(frame); cast.spell:SetTexCoord(.08, .92, .08, .92)
	cast.spell:AddMaskTexture(frame.mask)
	if cast.spell.SetSnapToPixelGrid then cast.spell:SetSnapToPixelGrid(false); cast.spell:SetTexelSnappingBias(0) end
	ring:SetScript('OnCooldownDone', function()
		if not cast.active then return end
		if cast.preview and JI:ArePortraitsUnlocked() then JI:UpdatePortraitCast(frame)
		else JI:StopPortraitCast(frame) end
	end)
	local elapsed = 0
	-- This script only runs while a cast's cooldown is shown.
	ring:HookScript('OnUpdate', function(_, delta)
		elapsed = elapsed + delta
		if elapsed >= .05 then elapsed = 0; UpdateTime(frame) end
	end)
	casts[frame.key] = frame
	JI:StopPortraitCast(frame)
	SetupDriver()
end

function JI:LayoutPortraitCast(frame, texture)
	local cast = frame.cast
	if not cast then return end
	local db = Settings(frame)
	cast.ring:SetFrameLevel(frame:GetFrameLevel() + 1)
	cast.textFrame:SetFrameLevel(frame:GetFrameLevel() + 2)
	if texture then cast.ring:SetSwipeTexture(texture, unpack(cast.channel and db.channelColor or db.color)) end
	local media = LibStub('LibSharedMedia-3.0', true)
	local font = db.font ~= '__default' and media and media.Fetch and media:Fetch('font', db.font, true)
	font = font or STANDARD_TEXT_FONT or [[Fonts\FRIZQT__.TTF]]
	for _, entry in ipairs({{cast.name, 'name'}, {cast.time, 'time'}}) do
		local text, prefix = entry[1], entry[2]
		local point = points[db[prefix..'Point']] and db[prefix..'Point'] or 'CENTER'
		text:SetFont(font, db.fontSize, db.outline)
		text:SetTextColor(unpack(db.textColor)); text:SetJustifyH('CENTER'); text:SetWordWrap(false)
		text:SetWidth(db.textWidth)
		text:ClearAllPoints(); text:SetPoint('CENTER', frame, point, db[prefix..'X'], db[prefix..'Y'])
	end
end
