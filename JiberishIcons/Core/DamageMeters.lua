local JI = unpack(JiberishIcons)

-- Prefer recorded specialization textures. Forever reports class textures
-- instead (for example PALADIN 626003); only its live Current/Overall views may
-- supplement those with a verified unit's talents. Never infer historical specs.
local specTextures = {
	[250] = 135770, [251] = 135773, [252] = 135775,
	[577] = 1247264, [581] = 1247265, [1480] = 7455385,
	[102] = 136096, [103] = 132115, [104] = 132276, [105] = 136041,
	[1467] = 4511811, [1468] = 4511812, [1473] = 5198700,
	[253] = 461112, [254] = 236179, [255] = 461113,
	[62] = 135932, [63] = 135810, [64] = 135846,
	[268] = 608951, [270] = 608952, [269] = 608953,
	[65] = 135920, [66] = 236264, [70] = 135873,
	[256] = 135940, [257] = 237542, [258] = 136207,
	[259] = 236270, [260] = 236286, [261] = 132320,
	[262] = 136048, [263] = 237581, [264] = 136052,
	[265] = 136145, [266] = 136172, [267] = 136186,
	[71] = 132355, [72] = 132347, [73] = 132341,
}
local specsByTexture = {}
local hooked = setmetatable({}, { __mode = 'k' })
local driver
local refreshQueued
local dataRefreshQueued

local function IsSecret(value)
	return issecretvalue and issecretvalue(value)
end

local function Settings(key)
	return JI.db and JI.db.damageMeters and JI.db.damageMeters[key]
end

local function UsesForeverTalents()
	if not GetBuildInfo then return false end
	local _, _, _, interface = GetBuildInfo()
	return type(interface) == 'number' and interface >= 16000 and interface < 20000
end

local meterUnits = {'player'}
for i = 1, 4 do meterUnits[#meterUnits + 1] = 'party'..i end
for i = 1, 40 do meterUnits[#meterUnits + 1] = 'raid'..i end
meterUnits[#meterUnits + 1], meterUnits[#meterUnits + 2] = 'target', 'focus'

local function IsLiveSession(sessionType, sessionID)
	if IsSecret(sessionID) or (sessionID ~= nil and sessionID ~= 0) or IsSecret(sessionType) then return end
	local types = Enum and Enum.DamageMeterSessionType
	return types and (sessionType == types.Current or sessionType == types.Overall)
end

local function ForeverMeterSpec(class, fileID, source, sessionType, sessionID, window, meterType)
	if not UsesForeverTalents() or not JI.GetUnitSpecialization or not IsLiveSession(sessionType, sessionID) then return end
	if IsSecret(source) or type(source) ~= 'table' then return end
	-- Do not resolve pets or restricted identities as players.
	local creature, pet, own = source.sourceCreatureID, source.threatPet, source.isLocalPlayer
	if IsSecret(own) or IsSecret(pet) or pet then return end
	if not IsSecret(creature) and creature ~= nil and creature ~= 0 then return end
	local function ReadUnit(unit)
		local exists, player = UnitExists(unit), UnitIsPlayer(unit)
		if IsSecret(exists) or not exists or IsSecret(player) or not player then return end
		local _, token = UnitClass(unit)
		if IsSecret(token) or token ~= class then return end
		local specID = JI:GetUnitSpecialization(unit)
		if IsSecret(specID) or type(specID) ~= 'number' then return end
		local info = JI.dataHelper.specialization[specID]
		return info and info.class == class and specID or nil
	end
	-- isLocalPlayer and a public Player GUID identify players independently of
	-- sourceCreatureID. That unrelated field can itself be secret (including nil)
	-- during combat; rejecting it makes confirmed icons alternate with Regalia.
	if own == true then return ReadUnit('player') end
	local guid = source.sourceGUID
	if IsSecret(guid) then
		if JI.GetPartyMeterSpecialization then
			return JI:GetPartyMeterSpecialization(window, class, fileID, source, sessionType, sessionID, meterType)
		end
		return
	end
	if type(guid) ~= 'string' or guid:sub(1, 7) ~= 'Player-' or not UnitGUID then return end
	for _, unit in ipairs(meterUnits) do
		local unitGUID = UnitGUID(unit)
		if not IsSecret(unitGUID) and unitGUID == guid then
			local spec = ReadUnit(unit)
			if spec then return spec end
			break
		end
	end
	-- A transient unit API failure must not discard a still-valid result for
	-- this exact public combatant. Expiry and explicit invalidation still apply.
	if JI.GetCachedInspectionByGUID then return JI:GetCachedInspectionByGUID(guid, class) end
end

local function AddSpecTexture(id, fileID)
	if IsSecret(fileID) or type(fileID) ~= 'number' or fileID <= 0 then return end
	local class = JI.dataHelper.specialization[id].class
	specsByTexture[class] = specsByTexture[class] or {}
	specsByTexture[class][fileID] = id
end

local function BuildSpecTextures()
	local getter = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID) or GetSpecializationInfoByID
	for id, fileID in pairs(specTextures) do
		AddSpecTexture(id, fileID)
		if getter then
			local ok, _, _, _, currentIcon = pcall(getter, id)
			if ok then AddSpecTexture(id, currentIcon) end
		end
	end
end

function JI:GetDamageMeterIcon(key, class, fileID, source, sessionType, sessionID, window, meterType)
	local settings = Settings(key)
	if not settings or not settings.enable or IsSecret(class) or type(class) ~= 'string' then return end
	local data, _, kind = JI:GetStyleInfo(settings.style)
	if not data or (kind ~= 'class' and kind ~= 'spec') then return end
	local specID
	if kind == 'spec' and not IsSecret(fileID) and type(fileID) == 'number' then
		local map = specsByTexture[class]
		specID = map and map[fileID]
	end
	if kind == 'spec' and not specID and not IsSecret(fileID) then
		specID = ForeverMeterSpec(class, fileID, source, sessionType, sessionID, window, meterType)
	end
	-- Missing/unknown spec data is a class crest, never a guessed specialization.
	local style = kind == 'spec' and not specID and 'fabledregalia' or settings.style
	local icon, path = JI:GetIdentityIcon(class, nil, style, specID)
	return icon, path, settings.reverse
end

local function HookOnce(object, method, callback)
	if not object or type(object[method]) ~= 'function' then return end
	local methods = hooked[object]
	if not methods then methods = {}; hooked[object] = methods end
	if methods[method] then return end
	methods[method] = true
	hooksecurefunc(object, method, callback)
end

local function PaintBlizzard(entry)
	local texture = entry.GetIcon and entry:GetIcon()
	if not texture then return end
	local window = entry.jiberishMeterWindow
	local source = entry.jiberishMeterSource
	if entry.GetElementData then
		local element = entry:GetElementData()
		if IsSecret(element) or element ~= nil then source = element end
	end
	if not IsSecret(source) and source == nil then source = entry end
	local sessionType = window and window.GetSessionType and window:GetSessionType()
	local sessionID = window and window.GetSessionID and window:GetSessionID()
	local meterType = window and window.GetDamageMeterType and window:GetDamageMeterType()
	local icon, path, reverse = JI:GetDamageMeterIcon('blizzard', entry.classFilename, entry.specIconID, source, sessionType, sessionID, window, meterType)
	if icon then
		if not entry.jiberishMeterIcon then
			entry.jiberishMeterNativeCoords = { texture:GetTexCoord() }
		end
		entry.jiberishMeterIcon = true
		texture:SetTexture(path)
		texture:SetTexCoord(JI:GetIconTexCoords(icon.texCoords, reverse))
	elseif entry.jiberishMeterIcon then
		entry.jiberishMeterIcon = nil
		-- Blizzard memoizes the native texture. Clear that memo before restoring,
		-- even if disabling the pack leaves the same combatant in this row.
		entry.iconTexture, entry.iconAtlasElement = nil, nil
		texture:SetTexCoord(unpack(entry.jiberishMeterNativeCoords))
		entry:UpdateIcon()
	end
end

local function BindBlizzardEntry(entry, window, source)
	if not entry or type(entry.UpdateIcon) ~= 'function' then return end
	entry.jiberishMeterWindow, entry.jiberishMeterSource = window, source
	HookOnce(entry, 'UpdateIcon', PaintBlizzard)
	PaintBlizzard(entry)
end

local function CaptureBlizzardParty(window)
	local settings = Settings('blizzard')
	if not UsesForeverTalents() or InCombatLockdown() or not settings or not settings.enable
		or not JI.CapturePartyMeterSnapshot or not window.GetCombatSession then return end
	local _, _, kind = JI:GetStyleInfo(settings.style)
	if kind ~= 'spec' then return end
	if window.IsEditing then
		local editing = window:IsEditing()
		if IsSecret(editing) or editing then return end
	end
	JI:CapturePartyMeterSnapshot(window, window:GetCombatSession(), window:GetSessionType(),
		window.GetSessionID and window:GetSessionID(), window.GetDamageMeterType and window:GetDamageMeterType())
end

local function BindBlizzardWindow(window)
	-- Session rows and the pinned player use InitEntry. Spell-breakdown entries
	-- have their own owner and keep their native spell/creature artwork.
	HookOnce(window, 'InitEntry', function(_, entry, source) BindBlizzardEntry(entry, window, source) end)
	HookOnce(window, 'Refresh', CaptureBlizzardParty)
	CaptureBlizzardParty(window)
	local scrollBox = window.GetScrollBox and window:GetScrollBox()
	if scrollBox and scrollBox.ForEachFrame then
		scrollBox:ForEachFrame(function(entry, source) BindBlizzardEntry(entry, window, source) end)
	end
	if window.GetLocalPlayerEntry then
		local entry = window:GetLocalPlayerEntry()
		BindBlizzardEntry(entry, window, entry and entry.jiberishMeterSource)
	end
end

local function RefreshBlizzard()
	local meter = _G.DamageMeter
	if not meter or type(meter.ForEachSessionWindow) ~= 'function' then return end
	HookOnce(meter, 'SetupSessionWindow', function() meter:ForEachSessionWindow(BindBlizzardWindow) end)
	HookOnce(meter, 'OnEditModeEnter', function() meter:ForEachSessionWindow(BindBlizzardWindow) end)
	HookOnce(meter, 'OnEditModeExit', function() meter:ForEachSessionWindow(BindBlizzardWindow) end)
	meter:ForEachSessionWindow(BindBlizzardWindow)
end

local function EllesmereNamespace()
	local eui = _G.EllesmereUI
	return eui and eui._ModuleNS and eui._ModuleNS.EllesmereUIDamageMeters
end

local QueueEllesmereWindow

local function PaintEllesmere(record)
	if record.painting then return end
	local bar, window = record.bar, record.window
	local class, specIcon = bar._cachedClass, bar._cachedSpecIcon
	if record.sticky then class, specIcon = window._stickyClassCache, window._stickySpecCache end
	local icon, path, reverse = JI:GetDamageMeterIcon('ellesmere', class, specIcon, bar._src, window.curSession, window.curSessionID, window, window.curDMType)
	local texture = bar.classIcon
	record.painting = true
	if icon then
		record.applied = true
		texture:SetTexture(path)
		texture:SetTexCoord(JI:GetIconTexCoords(icon.texCoords, reverse))
	elseif record.applied then
		record.applied = nil
		texture:SetTexture(record.nativeTexture)
		texture:SetTexCoord(unpack(record.nativeCoords))
	end
	record.painting = nil
end

local function BindEllesmereBar(window, bar, sticky)
	local texture = bar and bar.classIcon
	if not texture or not texture.GetTexCoord then return end
	local record = bar.jiberishMeterIcon
	if not record then
		record = { bar = bar, window = window, sticky = sticky,
			nativeTexture = texture:GetTexture(), nativeCoords = { texture:GetTexCoord() } }
		bar.jiberishMeterIcon = record
		-- ResolveIcon is private to Ellesmere. Post-hook only these player-icon
		-- textures; this also catches deferred paints and sticky-row scrolling.
		HookOnce(texture, 'SetTexture', function(_, nativeTexture)
			if record.painting then return end
			record.nativeTexture = nativeTexture
			if UsesForeverTalents() then QueueEllesmereWindow(window) else PaintEllesmere(record) end
		end)
		HookOnce(texture, 'SetTexCoord', function(_, ...)
			if record.painting then return end
			record.nativeCoords = {...}
			if UsesForeverTalents() then QueueEllesmereWindow(window) else PaintEllesmere(record) end
		end)
	end
	PaintEllesmere(record)
end

local function BindEllesmereWindow(window)
	if UsesForeverTalents() then
		-- Same-class Forever rows all share a class texture. Ellesmere can recycle
		-- them without SetTexture, and assigns _src only AFTER its icon pass.
		HookOnce(window, 'Refresh', function() QueueEllesmereWindow(window) end)
		HookOnce(window, 'QueueRepopulate', function() QueueEllesmereWindow(window) end)
		local settings = Settings('ellesmere')
		local _, _, kind = JI:GetStyleInfo(settings and settings.style)
		if settings and settings.enable and kind == 'spec' and JI.CapturePartyMeterSnapshot then
			JI:CapturePartyMeterSnapshot(window, window._lastSession, window.curSession, window.curSessionID, window.curDMType)
		end
	end
	for _, bar in ipairs(window.rowPool or {}) do BindEllesmereBar(window, bar, false) end
	BindEllesmereBar(window, window.stickyPlayer, true)
end

QueueEllesmereWindow = function(window)
	if window.jiberishMeterRefreshQueued then return end
	window.jiberishMeterRefreshQueued = true
	C_Timer.After(0, function()
		window.jiberishMeterRefreshQueued = nil
		BindEllesmereWindow(window)
	end)
end

local function RefreshEllesmere()
	local ns = EllesmereNamespace()
	if not ns or type(ns._windows) ~= 'table' then return end
	local function BindWindows()
		for _, window in ipairs(ns._windows) do BindEllesmereWindow(window) end
	end
	-- Runs after staggered login creation, adding/removing windows, and rebuilding
	-- on a profile change. No polling or replacement of Ellesmere's renderer.
	HookOnce(ns, 'RegisterDMUnlock', BindWindows)
	BindWindows()
end

local function UsesSpecPack(key)
	local settings = Settings(key)
	if not settings or not settings.enable then return end
	local _, _, kind = JI:GetStyleInfo(settings.style)
	return kind == 'spec'
end

local function ForEachLiveSpecWindow(blizzard, ellesmere)
	local meter = _G.DamageMeter
	if UsesSpecPack('blizzard') and meter and type(meter.ForEachSessionWindow) == 'function' then
		meter:ForEachSessionWindow(function(window)
			if window.GetSessionType and IsLiveSession(window:GetSessionType(), window.GetSessionID and window:GetSessionID()) then
				blizzard(window)
			end
		end)
	end
	local ns = EllesmereNamespace()
	if UsesSpecPack('ellesmere') and ns and type(ns._windows) == 'table' then
		for _, window in ipairs(ns._windows) do
			if IsLiveSession(window.curSession, window.curSessionID) then ellesmere(window) end
		end
	end
end

local function PrimeForeverMeterUnits()
	if not UsesForeverTalents() or not UnitGUID or not JI.GetUnitSpecialization then return end
	local active
	local function Found() active = true end
	ForEachLiveSpecWindow(Found, Found)
	if not active then return end
	-- Obtain talents before a combat row is needed. Restricted meter GUIDs must
	-- never prevent public party tokens from entering the shared inspect queue.
	local seen = {}
	local selfGUID = UnitGUID('player')
	if not IsSecret(selfGUID) and type(selfGUID) == 'string' then seen[selfGUID] = true end
	for _, unit in ipairs(meterUnits) do
		local exists, player, guid = UnitExists(unit), UnitIsPlayer(unit), UnitGUID(unit)
		if not IsSecret(exists) and exists and not IsSecret(player) and player
			and not IsSecret(guid) and type(guid) == 'string' and not seen[guid] then
			seen[guid] = true
			JI:GetUnitSpecialization(unit)
		end
	end
end

local function QueueFreshMeterData()
	if not UsesForeverTalents() or dataRefreshQueued then return end
	dataRefreshQueued = true
	-- Existing row tables can remain secret after combat ends. Fetch new native
	-- data after restrictions lift instead of repeatedly repainting those tables.
	C_Timer.After(0.5, function()
		dataRefreshQueued = nil
		if InCombatLockdown() then return end
		ForEachLiveSpecWindow(function(window)
			if window.Refresh then window:Refresh(true) end -- retain scroll position
		end, function(window)
			if window.Refresh then window.Refresh() end -- Ellesmere uses a closure
		end)
		JI:UpdateDamageMeters()
	end)
end

function JI:UpdateDamageMeters()
	if not JI.db then return end
	RefreshBlizzard()
	RefreshEllesmere()
	PrimeForeverMeterUnits()
end

function JI:RefreshDamageMeterSpecializations()
	if not driver or not UsesForeverTalents() or refreshQueued then return end
	-- Repaint after talent/inspection events and the provider's own row updates.
	refreshQueued = true
	C_Timer.After(0, function()
		refreshQueued = nil
		JI:UpdateDamageMeters()
	end)
end

function JI:SetupDamageMeters()
	if not driver then
		BuildSpecTextures()
		driver = CreateFrame('Frame')
		driver:RegisterEvent('ADDON_LOADED')
		driver:RegisterEvent('PLAYER_LOGIN')
		driver:RegisterEvent('PLAYER_REGEN_ENABLED')
		for _, event in ipairs({'GROUP_ROSTER_UPDATE', 'PLAYER_ENTERING_WORLD', 'PLAYER_SPECIALIZATION_CHANGED', 'DAMAGE_METER_RESET'}) do
			if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid(event) then
				pcall(driver.RegisterEvent, driver, event)
			end
		end
		if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid('ADDON_RESTRICTION_STATE_CHANGED') then
			pcall(driver.RegisterEvent, driver, 'ADDON_RESTRICTION_STATE_CHANGED')
		end
		driver:SetScript('OnEvent', function(_, event, addon, state)
			if event == 'PLAYER_LOGIN' or addon == 'Blizzard_DamageMeter' or addon == 'EllesmereUIDamageMeters' then
				JI:UpdateDamageMeters()
			elseif event == 'PLAYER_REGEN_ENABLED' then
				QueueFreshMeterData()
			elseif event == 'GROUP_ROSTER_UPDATE' or event == 'PLAYER_ENTERING_WORLD'
				or event == 'PLAYER_SPECIALIZATION_CHANGED' or event == 'DAMAGE_METER_RESET' then
				if JI.InvalidatePartyMeterSnapshots then JI:InvalidatePartyMeterSnapshots() end
				QueueFreshMeterData()
			elseif event == 'ADDON_RESTRICTION_STATE_CHANGED' and Enum and Enum.AddOnRestrictionState
				and not IsSecret(state) and state == Enum.AddOnRestrictionState.Inactive then
				-- The active-state API always returns false during this event;
				-- use its explicit state so activation never triggers a refresh.
				QueueFreshMeterData()
			end
		end)
	end
	JI:UpdateDamageMeters()
end
