local JI = unpack(JiberishIcons)
local units = JI.dataHelper.ellesmereUnitList
local supported, frames, records, hookedEngines, hookedFrames = {}, {}, {}, {}, {}
local partyFrames, hookedParty = {}, {}
local driver, queued
local inverse = {
	TOPLEFT = 'BOTTOMRIGHT', TOP = 'BOTTOM', TOPRIGHT = 'BOTTOMLEFT',
	LEFT = 'RIGHT', CENTER = 'CENTER', RIGHT = 'LEFT',
	BOTTOMLEFT = 'TOPRIGHT', BOTTOM = 'TOP', BOTTOMRIGHT = 'TOPLEFT',
}
for _, unit in ipairs(units) do supported[unit] = true end

local function IsSecret(value)
	return issecretvalue and issecretvalue(value)
end

local function Namespace(party)
	local eui = _G.EllesmereUI
	return eui and eui._ModuleNS and eui._ModuleNS[party and 'EllesmereUIRaidFrames' or 'EllesmereUIUnitFrames']
end

local function Settings(key)
	local db = JI.db and JI.db.ellesmereui
	return db and db[key] and db[key].icon
end

local function Paint(frame)
	local record = records[frame]
	if not record then return end
	local settings = Settings(record.key)
	local party = record.key == 'party'
	local ns = party and Namespace(true)
	local unit
	if party then unit = frame:GetAttribute('unit') else unit = frame._euiUnit end
	local texture = record.texture
	local active = party and partyFrames[frame] or (not party and frames[record.key] == frame)
	if not settings or not settings.enable or not active or not frame:IsShown()
		or (party and (not ns or ns._partyPvActive or ns._partyFramesVisible == false))
		or IsSecret(unit) or type(unit) ~= 'string' or unit == 'pet' or unit == 'vehicle' then
		texture:Hide()
		return
	end

	-- Never branch on restricted results or use a restricted class as a table key.
	local exists = UnitExists(unit)
	if IsSecret(exists) or not exists then texture:Hide(); return end
	local player = UnitIsPlayer(unit)
	if IsSecret(player) or not player then texture:Hide(); return end
	local info, path = JI:GetUnitIcon(unit, settings.style)
	if not info then texture:Hide(); return end

	texture:SetTexture(path)
	texture:SetTexCoord(JI:GetIconTexCoords(info.texCoords, settings.reverse))
	texture:Show()
end

local function Layout(frame, key)
	local settings = Settings(key)
	local record = records[frame]
	if InCombatLockdown() then
		-- Existing textures may still repaint in combat. Creation/anchors wait for regen.
		if record then Paint(frame) end
		return
	end
	if not settings then return end
	if not record and settings.enable then
		local holder = CreateFrame('Frame', nil, frame)
		holder:EnableMouse(false)
		holder:SetFrameLevel(frame:GetFrameLevel() + 20)
		local texture = holder:CreateTexture(nil, 'OVERLAY')
		texture:SetAllPoints(holder)
		texture:Hide()
		record = { key = key, holder = holder, texture = texture }
		records[frame] = record
	end
	if not record then return end
	local anchor = inverse[settings.anchorPoint] and settings.anchorPoint or 'RIGHT'
	record.holder:SetSize(settings.size, settings.size)
	record.holder:ClearAllPoints()
	record.holder:SetPoint(inverse[anchor], frame, anchor, settings.xOffset, settings.yOffset)
	Paint(frame)
end

local function Bind(frame, key)
	if not supported[key] or not frame then return end
	local previous = frames[key]
	if previous and previous ~= frame and records[previous] then
		records[previous].texture:Hide()
		records[previous] = nil
	end
	frames[key] = frame
	if not hookedFrames[frame] then
		hookedFrames[frame] = true
		frame:HookScript('OnShow', function()
			if frames[key] == frame then Layout(frame, key) end
		end)
	end
	Layout(frame, key)
end

local function QueueRefresh()
	if queued then return end
	queued = true
	C_Timer.After(0, function()
		queued = nil
		JI:UpdateEllesmereUI()
	end)
end

local function BindParty(ns)
	for frame in pairs(partyFrames) do partyFrames[frame] = nil end
	if ns and ns._partyAllButtons then
		for _, frame in ipairs(ns._partyAllButtons) do
			partyFrames[frame] = true
			if not hookedFrames[frame] then
				hookedFrames[frame] = true
				frame:HookScript('OnShow', function() Layout(frame, 'party') end)
				-- Secure headers can reassign a button while in combat. Only repaint
				-- our texture; never alter the header, unit attribute or secure layout.
				frame:HookScript('OnAttributeChanged', function(_, name)
					if not IsSecret(name) and name == 'unit' then Paint(frame) end
				end)
			end
			Layout(frame, 'party')
		end
	end
	for frame, record in pairs(records) do
		if record.key == 'party' and not partyFrames[frame] then record.texture:Hide() end
	end
end

local function HookParty(ns)
	if not ns then return end
	local hooks = hookedParty[ns] or {}
	hookedParty[ns] = hooks
	for _, name in ipairs({'_CreatePartyHeader', '_RebuildPartyUnitMap', '_UpdateAllPartyButtons',
		'_LayoutPartyFrames', '_UpdatePartyVisibility', 'ReloadPartyFrames'}) do
		if type(ns[name]) == 'function' and not hooks[name] then
			hooks[name] = true
			hooksecurefunc(ns, name, QueueRefresh)
		end
	end
end

local function HookEngine(ns)
	local engine = ns and ns.Engine
	if not engine or hookedEngines[engine] or type(engine.RepaintAll) ~= 'function'
		or type(engine.Attach) ~= 'function' or type(engine.AttachPolled) ~= 'function' then return end
	hookedEngines[engine] = true
	-- Capture newly built frames before ns.frames is exposed by the deferred options setup.
	local function Attached(frame, unit)
		if IsSecret(unit) or not supported[unit] then return end
		Bind(frame, unit)
		QueueRefresh()
	end
	hooksecurefunc(engine, 'Attach', Attached)
	hooksecurefunc(engine, 'AttachPolled', Attached)
	-- Includes target/focus swaps, vehicles, OnShow, and the existing ToT/FoT identity poll.
	hooksecurefunc(engine, 'RepaintAll', Paint)
end

function JI:UpdateEllesmereUI()
	if not driver then return end
	JI:ClearIconStyleCache()
	local ns = Namespace()
	HookEngine(ns)
	if ns and ns.frames then
		for _, key in ipairs(units) do
			local frame = ns.frames[key]
			if frame then Bind(frame, key) end
		end
	end
	for key, frame in pairs(frames) do Layout(frame, key) end
	local party = Namespace(true)
	HookParty(party)
	BindParty(party)
end

function JI:RefreshEllesmereSpecializations()
	for frame in pairs(records) do Paint(frame) end
end

function JI:SetupEllesmereUI()
	if driver or not (JI:IsAddOnEnabled('EllesmereUIUnitFrames') or JI:IsAddOnEnabled('EllesmereUIRaidFrames')) then return end
	driver = CreateFrame('Frame')
	-- Use a separate event frame: AceEvent handlers here would replace Core's login handlers.
	for _, event in ipairs({ 'ADDON_LOADED', 'PLAYER_LOGIN', 'PLAYER_ENTERING_WORLD',
		'PLAYER_REGEN_ENABLED', 'PLAYER_TARGET_CHANGED', 'PLAYER_FOCUS_CHANGED',
		'GROUP_ROSTER_UPDATE', 'UNIT_NAME_UPDATE', 'UNIT_CONNECTION', 'UNIT_FACTION', 'UNIT_FLAGS', 'UNIT_TARGET' }) do
		driver:RegisterEvent(event)
	end
	driver:SetScript('OnEvent', function(_, event, addon)
		if event == 'ADDON_LOADED' then
			if addon ~= 'EllesmereUIUnitFrames' and addon ~= 'EllesmereUIRaidFrames' then return end
			HookEngine(Namespace())
		elseif event ~= 'PLAYER_LOGIN' and event ~= 'PLAYER_ENTERING_WORLD' and event ~= 'PLAYER_REGEN_ENABLED'
			and event ~= 'GROUP_ROSTER_UPDATE' then
			for frame in pairs(records) do Paint(frame) end
			return
		end
		JI:UpdateEllesmereUI()
		QueueRefresh()
	end)
	JI:UpdateEllesmereUI()
	QueueRefresh()
end
