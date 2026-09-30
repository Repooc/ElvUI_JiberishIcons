local JI = unpack(JiberishIcons)

-- WoW exposes one shared inspection at a time. Cache only GUID-matched replies,
-- and leave manual inspection windows and other addons' requests alone.
local cache, requests = {}, {}
local enabled, timer, timerDue, pending, observedGUID, observedUntil
local lastRequest, sequence = -math.huge, 0
local CACHE_SECONDS, CACHE_RETENTION, RETRY_SECONDS, TIMEOUT, THROTTLE = 60, 300, 30, 5, 2
local Pump

local function IsSecret(value)
	return issecretvalue and issecretvalue(value)
end

local function Identity(unit)
	if IsSecret(unit) or type(unit) ~= 'string' or not UnitGUID then return end
	local exists, player = UnitExists(unit), UnitIsPlayer(unit)
	if IsSecret(exists) or not exists or IsSecret(player) or not player then return end
	local guid = UnitGUID(unit)
	local _, class = UnitClass(unit)
	if IsSecret(guid) or type(guid) ~= 'string' or IsSecret(class) or type(class) ~= 'string' then return end
	return guid, class
end

local function InspectWindowOpen()
	if InspectFrame and InspectFrame:IsShown() then return true end
	if PlayerSpellsFrame and PlayerSpellsFrame.IsInspecting then
		local inspecting = PlayerSpellsFrame:IsInspecting()
		return IsSecret(inspecting) or inspecting
	end
end

local function Store(guid, class, spec, fallback, seconds)
	local now, count, oldest, oldestTime = GetTime(), 0, nil, math.huge
	local previous = cache[guid]
	-- A failed background refresh must not discard a recently confirmed build.
	-- Its original hard expiry still applies, even after repeated failures.
	if not spec and not fallback and previous and previous.class == class
		and previous.expires > now and (previous.spec or previous.fallback) then
		previous.retryAfter = now + seconds
		return
	end
	for key, entry in pairs(cache) do
		if entry.expires <= now then cache[key] = nil
		else
			count = count + 1
			if entry.expires < oldestTime then oldest, oldestTime = key, entry.expires end
		end
	end
	if count >= 100 and not cache[guid] then cache[oldest] = nil end
	cache[guid] = {class = class, spec = spec, fallback = fallback, freshUntil = now + seconds,
		expires = now + ((spec or fallback) and CACHE_RETENTION or seconds)}
end

function JI:GetCachedInspection(unit)
	if not enabled then return end
	local guid, class = Identity(unit)
	local entry = guid and cache[guid]
	if entry and entry.class == class and entry.expires > GetTime() then
		if entry.freshUntil <= GetTime() then JI:RequestSpecializationInspection(unit) end
		return entry.spec, entry.fallback
	end
end

local function StopWhenIdle()
	if not next(requests) and timer then timer:Cancel(); timer, timerDue = nil, nil end
end

function JI:RememberPublicSpecialization(unit, spec)
	if not enabled or IsSecret(spec) then return end
	local guid, class = Identity(unit)
	local info = JI.dataHelper.specialization[spec]
	if not guid or not info or info.class ~= class then return end
	local entry = cache[guid]
	-- Preserve a newer direct Retail result if the inspect API later loses it.
	-- Repeated identical reads do not keep extending the cache's lifetime.
	if not entry or entry.class ~= class or entry.spec ~= spec or entry.expires <= GetTime() then
		Store(guid, class, spec, false, CACHE_SECONDS)
	end
	requests[guid] = nil
	StopWhenIdle()
end

local function Schedule(delay)
	if not next(requests) then StopWhenIdle(); return end
	local due = GetTime() + delay
	if timer and timerDue <= due then return end
	if timer then timer:Cancel() end
	timerDue = due
	timer = C_Timer.NewTimer(delay, function()
		timer, timerDue = nil, nil
		Pump()
	end)
end

Pump = function()
	local now = GetTime()
	for guid, job in pairs(requests) do
		local current, class = Identity(job.unit)
		if current ~= guid or class ~= job.class then
			requests[guid] = nil
			if pending and pending.guid == guid then pending = nil end
		end
	end
	StopWhenIdle()
	if not next(requests) then return end
	-- Do not initiate requests in combat or while the user is inspecting talents.
	if InCombatLockdown() or InspectWindowOpen() then
		for _, job in pairs(requests) do job.deadline = now + 30 end
		Schedule(1)
		return
	end
	if pending then
		if pending.expires > now then Schedule(pending.expires - now); return end
		pending = nil
	end
	local readyAt = math.max(lastRequest + THROTTLE, observedUntil or 0)
	if readyAt > now then Schedule(readyAt - now); return end
	local targetGUID, focusGUID = Identity('target'), Identity('focus')
	local selected, selectedPriority
	for guid, job in pairs(requests) do
		local priority = job.attempts > 0 and 3 or (guid == targetGUID and 0 or (guid == focusGUID and 1 or 2))
		if job.attempts >= 3 or now >= job.deadline then
			Store(guid, job.class, nil, nil, RETRY_SECONDS)
			requests[guid] = nil
		elseif not selected or priority < selectedPriority or (priority == selectedPriority and job.order < selected.order) then
			local can = CanInspect(job.unit, false)
			local range = not CheckInteractDistance or CheckInteractDistance(job.unit, 1)
			if not IsSecret(can) and can and not IsSecret(range) and range then selected, selectedPriority = job, priority end
		end
	end
	if selected then
		selected.attempts = selected.attempts + 1
		-- Move retries behind other party members so one failed player cannot block them.
		sequence = sequence + 1; selected.order = sequence
		pending = {guid = selected.guid, expires = now + TIMEOUT}
		lastRequest = now
		NotifyInspect(selected.unit)
	end
	Schedule(selected and TIMEOUT or 1)
end

function JI:RequestSpecializationInspection(unit)
	if not enabled then return end
	local guid, class = Identity(unit)
	if not guid then return end
	local entry = cache[guid]
	local now = GetTime()
	if entry and entry.class == class and (entry.freshUntil > now or (entry.retryAfter and entry.retryAfter > now)) then return end
	local job = requests[guid]
	if job then
		-- A party token survives target changes, so prefer it over a volatile target.
		if unit:match('^party%d+$') or unit:match('^raid%d+$') then job.unit = unit end
		if Identity(job.unit) ~= guid then job.unit = unit; Schedule(0) end
		return
	end
	sequence = sequence + 1
	requests[guid] = {guid = guid, unit = unit, class = class, attempts = 0, order = sequence, deadline = GetTime() + 30}
	Schedule(0)
end

function JI:OnSpecializationInspectEvent(event, value)
	if not enabled then return end
	if event == 'PLAYER_ENTERING_WORLD' then
		-- Unit tokens and the shared inspect buffer reset on zoning, but GUID-scoped
		-- results remain useful for group members. Nothing persists across reloads.
		wipe(requests); pending, observedGUID, observedUntil = nil, nil, nil
		StopWhenIdle()
	elseif event == 'PLAYER_SPECIALIZATION_CHANGED' then
		local guid = Identity(value)
		if guid then
			cache[guid], requests[guid] = nil, nil
			-- A reply to the pre-change request must not repopulate the old build.
			if observedGUID == guid then observedGUID = nil end
			if pending and pending.guid == guid then pending = nil end
			Schedule(0)
		end
	elseif event == 'INSPECT_READY' then
		if IsSecret(value) or type(value) ~= 'string' or value ~= observedGUID then return end
		local job = requests[value]
		if job then
			local guid, class = Identity(job.unit)
			if guid == value and class == job.class then
				-- Guard API availability differences without exposing a Lua error in game.
				local ok, spec, fallback = pcall(JI.ReadInspectedSpecialization, JI, job.unit)
				local info = ok and spec and JI.dataHelper.specialization[spec]
				if (info and info.class == class) or (ok and fallback == true) then
					Store(value, class, spec, fallback, CACHE_SECONDS)
					requests[value] = nil
				end
			end
		end
		if pending and pending.guid == value then pending = nil end
		observedGUID, observedUntil = nil, nil
		Schedule(0)
	elseif event == 'PLAYER_TARGET_CHANGED' or event == 'PLAYER_FOCUS_CHANGED' or event == 'PLAYER_REGEN_ENABLED' then
		Schedule(0)
	end
end

function JI:SetupSpecializationInspection()
	if enabled or not (NotifyInspect and CanInspect and UnitGUID and GetTime and C_Timer and C_Timer.NewTimer) then return end
	enabled = true
	hooksecurefunc('NotifyInspect', function(unit)
		observedGUID = Identity(unit)
		lastRequest, observedUntil = GetTime(), GetTime() + TIMEOUT
		if pending and pending.guid ~= observedGUID then pending = nil end
	end)
	if ClearInspectPlayer then
		hooksecurefunc('ClearInspectPlayer', function()
			observedGUID, observedUntil, pending = nil, nil, nil
			Schedule(0)
		end)
	end
	JI:RefreshSpecializationIcons()
end
