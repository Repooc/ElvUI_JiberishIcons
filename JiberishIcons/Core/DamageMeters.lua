local JI = unpack(JiberishIcons)

-- Meters describe the recorded combatant with a texture file ID, not a unit
-- token. Never substitute today's inspected build for a historical session.
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

local function IsSecret(value)
	return issecretvalue and issecretvalue(value)
end

local function Settings(key)
	return JI.db and JI.db.damageMeters and JI.db.damageMeters[key]
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

function JI:GetDamageMeterIcon(key, class, fileID)
	local settings = Settings(key)
	if not settings or not settings.enable or IsSecret(class) or type(class) ~= 'string' then return end
	local data, _, kind = JI:GetStyleInfo(settings.style)
	if not data or (kind ~= 'class' and kind ~= 'spec') then return end
	local specID
	if kind == 'spec' and not IsSecret(fileID) and type(fileID) == 'number' then
		local map = specsByTexture[class]
		specID = map and map[fileID]
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
	local icon, path, reverse = JI:GetDamageMeterIcon('blizzard', entry.classFilename, entry.specIconID)
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

local function BindBlizzardEntry(entry)
	if not entry or type(entry.UpdateIcon) ~= 'function' then return end
	HookOnce(entry, 'UpdateIcon', PaintBlizzard)
	PaintBlizzard(entry)
end

local function BindBlizzardWindow(window)
	-- Session rows and the pinned player use InitEntry. Spell-breakdown entries
	-- have their own owner and keep their native spell/creature artwork.
	HookOnce(window, 'InitEntry', function(_, entry) BindBlizzardEntry(entry) end)
	local scrollBox = window.GetScrollBox and window:GetScrollBox()
	if scrollBox and scrollBox.ForEachFrame then scrollBox:ForEachFrame(BindBlizzardEntry) end
	if window.GetLocalPlayerEntry then BindBlizzardEntry(window:GetLocalPlayerEntry()) end
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

local function PaintEllesmere(record)
	if record.painting then return end
	local bar, window = record.bar, record.window
	local class, specIcon = bar._cachedClass, bar._cachedSpecIcon
	if record.sticky then class, specIcon = window._stickyClassCache, window._stickySpecCache end
	local icon, path, reverse = JI:GetDamageMeterIcon('ellesmere', class, specIcon)
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
			PaintEllesmere(record)
		end)
		HookOnce(texture, 'SetTexCoord', function(_, ...)
			if record.painting then return end
			record.nativeCoords = {...}
			PaintEllesmere(record)
		end)
	end
	PaintEllesmere(record)
end

local function BindEllesmereWindow(window)
	for _, bar in ipairs(window.rowPool or {}) do BindEllesmereBar(window, bar, false) end
	BindEllesmereBar(window, window.stickyPlayer, true)
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

function JI:UpdateDamageMeters()
	if not JI.db then return end
	RefreshBlizzard()
	RefreshEllesmere()
end

function JI:SetupDamageMeters()
	if not driver then
		BuildSpecTextures()
		driver = CreateFrame('Frame')
		driver:RegisterEvent('ADDON_LOADED')
		driver:RegisterEvent('PLAYER_LOGIN')
		driver:SetScript('OnEvent', function(_, event, addon)
			if event == 'PLAYER_LOGIN' or addon == 'Blizzard_DamageMeter' or addon == 'EllesmereUIDamageMeters' then
				JI:UpdateDamageMeters()
			end
		end)
	end
	JI:UpdateDamageMeters()
end
