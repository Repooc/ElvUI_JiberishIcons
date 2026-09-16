local JI = unpack(ElvUI_JiberishIcons)
local units = JI.dataHelper.ellesmereUnitList
local supported, frames, records, hookedEngines, hookedFrames = {}, {}, {}, {}, {}
local texturePaths = {}
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

local function Namespace()
	local eui = _G.EllesmereUI
	return eui and eui._ModuleNS and eui._ModuleNS.EllesmereUIUnitFrames
end

local function Settings(key)
	local db = JI.db and JI.db.ellesmereui
	return db and db[key] and db[key].icon
end

local function TexturePath(style)
	style = style or 'fabled'
	if texturePaths[style] then return texturePaths[style] end
	local packs = JI.mergedStylePacks.class
	local data = packs.styles[style]
	local path = data and ((data.path or packs.path)..style)
	if not path or not JI:IsValidTexturePath(path) then path = packs.path..'fabled' end
	texturePaths[style] = path
	return path
end

local function Paint(frame)
	local record = records[frame]
	if not record then return end
	local settings = Settings(record.key)
	local unit = frame._euiUnit
	local texture = record.texture
	if not settings or not settings.enable or frames[record.key] ~= frame or not frame:IsShown()
		or IsSecret(unit) or type(unit) ~= 'string' or unit == 'pet' or unit == 'vehicle' then
		texture:Hide()
		return
	end

	-- Never branch on restricted results or use a restricted class as a table key.
	local exists = UnitExists(unit)
	if IsSecret(exists) or not exists then texture:Hide(); return end
	local player = UnitIsPlayer(unit)
	if IsSecret(player) or not player then texture:Hide(); return end
	local _, class = UnitClass(unit)
	if IsSecret(class) or not class then texture:Hide(); return end
	local info = JI.dataHelper.class[class]
	if not info then texture:Hide(); return end

	texture:SetTexture(TexturePath(settings.style))
	texture:SetTexCoord(unpack(info.texCoords))
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
	wipe(texturePaths)
	local ns = Namespace()
	HookEngine(ns)
	if ns and ns.frames then
		for _, key in ipairs(units) do
			local frame = ns.frames[key]
			if frame then Bind(frame, key) end
		end
	end
	for key, frame in pairs(frames) do Layout(frame, key) end
end

function JI:SetupEllesmereUI()
	if driver or not JI:IsAddOnEnabled('EllesmereUIUnitFrames') then return end
	driver = CreateFrame('Frame')
	-- Use a separate event frame: AceEvent handlers here would replace Core's login handlers.
	for _, event in ipairs({ 'ADDON_LOADED', 'PLAYER_LOGIN', 'PLAYER_ENTERING_WORLD',
		'PLAYER_REGEN_ENABLED', 'PLAYER_TARGET_CHANGED', 'PLAYER_FOCUS_CHANGED',
		'UNIT_NAME_UPDATE', 'UNIT_CONNECTION', 'UNIT_FACTION', 'UNIT_FLAGS', 'UNIT_TARGET' }) do
		driver:RegisterEvent(event)
	end
	driver:SetScript('OnEvent', function(_, event, addon)
		if event == 'ADDON_LOADED' then
			if addon ~= 'EllesmereUIUnitFrames' then return end
			HookEngine(Namespace())
		elseif event ~= 'PLAYER_LOGIN' and event ~= 'PLAYER_ENTERING_WORLD' and event ~= 'PLAYER_REGEN_ENABLED' then
			for frame in pairs(records) do Paint(frame) end
			return
		end
		JI:UpdateEllesmereUI()
		QueueRefresh()
	end)
	JI:UpdateEllesmereUI()
	QueueRefresh()
end
