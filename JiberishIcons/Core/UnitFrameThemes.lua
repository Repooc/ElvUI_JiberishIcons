local JI = unpack(JiberishIcons)
local media = JI.MediaPath..[[Bushido\]]
local records, chrome, hooks, attachedFrames, predictionOwners = {}, {}, {}, {}, {}
local driver, queued
local shapes = {diagonal = true, diagonalback = true, chamfer = true}
local supported = {}
for _, unit in ipairs(JI.dataHelper.themeUnits) do supported[unit.key] = true end

local function Secret(value) return issecretvalue and issecretvalue(value) end
local function Number(value) return not Secret(value) and type(value) == 'number' and value == value and math.abs(value) < math.huge end
local function Bound(value, low, high, fallback)
	return Number(value) and math.max(low, math.min(high, value)) or fallback
end
local function Object(value, kind)
	if Secret(value) or (type(value) ~= 'table' and type(value) ~= 'userdata') then return false end
	if type(value.IsObjectType) ~= 'function' then return false end
	if value.IsForbidden and value:IsForbidden() then return false end
	return value:IsObjectType(kind or 'Frame')
end
local function Settings(host, key)
	local db = JI.db and JI.db.unitFrameThemes
	return db and db[host] and db[host][key]
end
local function Enabled(r)
	local db = Settings(r.host, r.key)
	return r.active and db and (db.theme == 'bushido' or db.theme == 'overwatch'), db
end
local function Smooth(texture)
	if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false); texture:SetTexelSnappingBias(0) end
end
local function Hook(owner, name, fn)
	if not owner or type(owner[name]) ~= 'function' then return end
	hooks[owner] = hooks[owner] or {}
	if hooks[owner][name] then return end
	hooks[owner][name] = true
	hooksecurefunc(owner, name, fn)
end
local function Queue()
	if queued or not driver then return end
	queued = true
	C_Timer.After(0, function() queued = nil; JI:UpdateUnitFrameThemes() end)
end

local function Unit(r)
	local unit
	if r.host == 'ellesmereui' then
		if r.key == 'party' or r.key == 'raid' then unit = r.frame:GetAttribute('unit')
		else unit = r.frame._euiUnit end
	else unit = r.frame.unit end
	if Secret(unit) then return end
	if not unit and r.frame.GetAttribute then unit = r.frame:GetAttribute('unit') end
	if not Secret(unit) and type(unit) == 'string' then return unit end
end
local function PaintCap(r)
	local on, db = Enabled(r)
	if not r.cap then return end
	local shown = r.bar:IsShown()
	if not on or db.theme ~= 'bushido' or not db.cap.enable or Secret(shown) or not shown then r.cap:Hide(); return end
	local color = db.cap.color
	local red, green, blue = color[1], color[2], color[3]
	if db.cap.colorMode == 'class' then
		local unit = Unit(r)
		local exists = unit and UnitExists(unit)
		local player = unit and UnitIsPlayer(unit)
		if not Secret(exists) and exists and not Secret(player) and player then
			local _, class = UnitClass(unit)
			local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
			local c = not Secret(class) and type(class) == 'string' and colors and colors[class]
			if c and Number(c.r) and Number(c.g) and Number(c.b) then red, green, blue = c.r, c.g, c.b end
		end
	end
	r.cap:SetVertexColor(red, green, blue, color[4])
	r.cap:Show()
end

local function Maskable(texture)
	return texture and type(texture.AddMaskTexture) == 'function' and type(texture.RemoveMaskTexture) == 'function'
end
local function Attach(r, texture)
	if not Maskable(texture) or r.attached[texture] then return end
	-- Three native mask slots are shared with the host and other addons.
	if texture.GetNumMaskTextures and texture:GetNumMaskTextures() >= 3 then return end
	texture:AddMaskTexture(r.mask); r.attached[texture] = true
end
local function Detach(r)
	for texture in pairs(r.attached) do texture:RemoveMaskTexture(r.mask) end
	r.attached = {}
	r.border:Hide()
	for _, tick in ipairs(r.ticks) do tick:Hide() end
end
local function Restore(r)
	r.active, r.shaped = false, false
	Detach(r)
	if r.cap then r.cap:Hide() end
end

-- Hide only dedicated border/backdrop objects, never a unit button or bar.
-- Observe later host alpha writes so disabling the theme restores its latest
-- appearance, including edits made while Bushido was enabled.
local function HideChrome(object)
	if not (Object(object) or Object(object, 'Texture')) or not object.GetAlpha then return end
	local c = chrome[object]
	if not c then
		c = {}; chrome[object] = c
		Hook(object, 'SetAlpha', function(_, alpha)
			if c.writing then return end
			c.alpha = alpha
			if c.active then
				c.writing = true; object:SetAlpha(0); c.writing = nil
			end
		end)
	end
	if not c.active then c.alpha = object:GetAlpha() end
	c.active, c.seen, c.writing = true, true, true
	object:SetAlpha(0); c.writing = nil
end
local function RestoreChrome(object, c)
	c.active, c.writing = false, true
	object:SetAlpha(c.alpha); c.writing = nil
end

local backdropEdges = {'TopEdge', 'BottomEdge', 'LeftEdge', 'RightEdge',
	'TopLeftCorner', 'TopRightCorner', 'BottomLeftCorner', 'BottomRightCorner'}
local function Backdrop(r, backdrop, replaceBorder)
	if not Object(backdrop) then return end
	-- Eltruism paints gradients on Center as well as bg/backdropTex. Keep that
	-- surface and its host alpha; suppress only the rectangular edge regions.
	Attach(r, backdrop.Center)
	if not replaceBorder then return end
	if Maskable(backdrop.Center) then
		for _, field in ipairs(backdropEdges) do HideChrome(backdrop[field]) end
	else HideChrome(backdrop) end
	HideChrome(backdrop.iborder)
	HideChrome(backdrop.oborder)
	HideChrome(backdrop.eltruismuniversalborders)
	HideChrome(backdrop.shadow)
end

local borderNames = {player = 'Player', target = 'Target', targettarget = 'TargetTarget',
	focus = 'Focus', focustarget = 'FocusTarget', pet = 'Pet'}
local function EltruismBorder(frame, bar, key, power)
	local name = frame.GetName and frame:GetName()
	local stem = borderNames[key]
	local border
	if stem then border = _G['Eltruism'..stem..(power and 'PowerBorder' or 'Border')]
	elseif not power and type(name) == 'string' then
		local raid, raidGroup, button = name:match('^ElvUF_Raid(%d)Group(%d+)UnitButton(%d+)$')
		if raid then border = _G['EltruismRaid'..raid..'Group'..raidGroup..'Border'..button]
		else
			local group, index
			index = name:match('^ElvUF_PartyGroup1UnitButton(%d+)$')
			if index then border = _G['EltruismPartyBorder'..index]
			else
				group, index = name:match('^ElvUF_(Boss)(%d+)$')
				if not group then group, index = name:match('^ElvUF_(Arena)(%d+)$') end
				if group then border = _G['Eltruism'..group..'Border'..index] end
			end
		end
	end
	-- Never touch another unit's artwork or cast/class/portrait borders.
	if Object(border) and border.GetParent and (border:GetParent() == bar or border:GetParent() == frame) then
		HideChrome(border)
	end
end

local function Capture(frame, bar, host, key, power)
	local r = records[bar]
	if not r then
		r = {frame = frame, bar = bar, host = host, key = key, power = power, attached = {}, ticks = {}}
		r.mask = bar:CreateMaskTexture()
		r.mask:SetAllPoints(bar); Smooth(r.mask)
		r.border = bar:CreateTexture(nil, 'OVERLAY', nil, 7)
		r.border:SetAllPoints(bar); Smooth(r.border)
		records[bar] = r
		bar:HookScript('OnSizeChanged', Queue)
		bar:HookScript('OnShow', function() PaintCap(r); Queue() end)
		bar:HookScript('OnHide', function() if r.cap then r.cap:Hide() end end)
		Hook(bar, 'SetStatusBarTexture', function()
			if r.shaped then Attach(r, bar:GetStatusBarTexture()) end
		end)
		Hook(bar, 'SetOrientation', Queue)
		if not power then
			-- A sibling keeps the end cap outside the status bar's clipping tree.
			r.overlay = CreateFrame('Frame', nil, frame)
			r.overlay:EnableMouse(false); r.overlay:SetAllPoints(bar)
			r.overlay:SetClipsChildren(false)
			r.cap = r.overlay:CreateTexture(nil, 'OVERLAY')
			r.cap:SetTexture(media..'BushidoEndPoint.tga', 'CLAMP', 'CLAMP', 'LINEAR')
			Smooth(r.cap)
			frame:HookScript('OnShow', function() PaintCap(r); Queue() end)
			frame:HookScript('OnAttributeChanged', function(_, name)
				if not Secret(name) and name == 'unit' then PaintCap(r) end
			end)
		end
	end
	r.frame, r.host, r.key = frame, host, key
	return r
end

local function Prediction(r, bar)
	if not Object(bar, 'StatusBar') then return end
	predictionOwners[bar] = r
	Attach(r, bar:GetStatusBarTexture()); Attach(r, bar._bg)
	-- Prediction textures can be replaced independently of the health texture.
	Hook(bar, 'SetStatusBarTexture', function()
		local owner = predictionOwners[bar]
		if owner and owner.shaped then Attach(owner, bar:GetStatusBarTexture()); Attach(owner, bar._bg) end
	end)
end

local function Divisions(r, db, w, h, vertical, ratio)
	local count = db.theme == 'bushido' and not r.power and db.divisions or 0
	if count ~= 5 and count ~= 10 and count ~= 20 then count = 0 end
	local length, cross = vertical and h or w, vertical and w or h
	local width = Bound(db.divisionWidth, 1, 6, 1)
	local start, step, angle = 0, length / math.max(1, count), 0
	if r.shaped and (db.shape == 'diagonal' or db.shape == 'diagonalback') then
		local shear = .45 * length / ratio
		angle = math.atan(shear / cross) * (db.shape == 'diagonalback' and -1 or 1)
		local inset = .043 * math.sqrt(1 + .45^2) * length / ratio
		local span = length - shear - 2 * inset
		width = math.min(width, span / math.max(1, count) * .65 * math.cos(angle))
		local gap = width / math.cos(angle)
		start, step = shear / 2 + inset - gap / 2, (span + gap) / math.max(1, count)
	end
	for i = 1, 19 do
		local tick = r.ticks[i]
		if i < count then
			if not tick then
				tick = r.bar:CreateTexture(nil, 'OVERLAY', nil, 6)
				tick:SetTexture(media..'divider.tga', 'CLAMP', 'CLAMP', 'LINEAR')
				Smooth(tick); r.ticks[i] = tick
			end
			tick:ClearAllPoints()
			tick:SetSize(width * 3, cross / math.cos(angle) + 4)
			tick:SetPoint('CENTER', r.bar, vertical and 'BOTTOM' or 'LEFT',
				vertical and 0 or start + step * i, vertical and start + step * i or 0)
			tick:SetRotation(angle + (vertical and math.pi / 2 or 0))
			tick:SetVertexColor(unpack(db.divisionColor))
			if r.shaped then Attach(r, tick) end
			tick:Show()
		elseif tick then tick:Hide() end
	end
end

local function Skin(frame, bar, host, key, power, background)
	if not Object(bar, 'StatusBar') or not bar.CreateMaskTexture then return end
	local db = Settings(host, key)
	local r = records[bar]
	if not db or (db.theme ~= 'bushido' and db.theme ~= 'overwatch') or (power and not db.shapePower) then
		if r then Restore(r) end
		return
	end
	local w, h = bar:GetWidth(), bar:GetHeight()
	if not Number(w) or not Number(h) or w <= 0 or h <= 0 then
		if r then Restore(r) end
		return
	end
	r = Capture(frame, bar, host, key, power)
	r.seen, r.active = true, true
	local vertical = bar:GetOrientation() == 'VERTICAL'
	local ratio = math.max(1, math.min(32, math.floor((vertical and h / w or w / h) + .5)))
	Detach(r)
	r.shaped = db.theme == 'overwatch' or shapes[db.shape] and true or false
	local fill = bar:GetStatusBarTexture()
	if not Maskable(fill) or (fill.GetNumMaskTextures and fill:GetNumMaskTextures() >= 3) then
		-- Preserve an already fully-masked host texture and its native border.
		r.shaped = false
	end
	if r.shaped then
		local borderSuffix = ''
		local path = media..(db.shape == 'diagonalback' and 'diagonal' or db.shape)..'-'..ratio
		if db.theme == 'overwatch' then
			local count = db.segments == 5 and 5 or db.segments == 10 and 10 or 20
			local gaps = {'-narrow', '', '-gap3', '-gap4', '-wide', '-gap6'}
			local gap = gaps[db.segmentSpacing] or (db.segmentGap == 'narrow' and '-narrow' or db.segmentGap == 'wide' and '-wide' or '')
			local width = math.floor(Bound(db.segmentBorderWidth, .5, 3, 1)*2+.5)
			borderSuffix = width == 2 and '' or '-'..width
			path = JI.MediaPath..[[Overwatch\segments-]]..count..gap..(db.segmentStyle == 'rounded' and '-rounded' or '')
		end
		local reverse = db.theme == 'overwatch' and db.reverseSegments or db.theme ~= 'overwatch' and db.shape == 'diagonalback'
		-- MaskTexture does not reliably implement Texture's UV transforms.
		-- Use pixel-identical baked orientations, leaving every mask at its
		-- default coordinates. Borders can safely use normal texture UVs.
		if vertical then
			if reverse then r.border:SetTexCoord(0,0,1,0,0,1,1,1)
			else r.border:SetTexCoord(1,0,0,0,1,1,0,1) end
		else r.border:SetTexCoord(reverse and 1 or 0, reverse and 0 or 1, 0, 1) end
		local maskSuffix = (reverse and '-reverse' or '')..(vertical and '-vertical' or '')
		r.mask:SetTexture(path..'-mask'..maskSuffix..'.tga', 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE', 'LINEAR')
		r.border:SetTexture(path..'-border'..borderSuffix..'.tga', 'CLAMP', 'CLAMP', 'LINEAR')
		r.border:SetAlpha(db.theme == 'overwatch' and Bound(db.segmentBorderOpacity, 0, 1, .6) or 1)
		r.border:SetVertexColor(unpack(db.borderColor)); r.border:SetShown(db.theme ~= 'overwatch' or db.segmentOutline)
		Attach(r, bar:GetStatusBarTexture()); Attach(r, bar.bg); Attach(r, bar.backdropTex); Attach(r, background)
		Backdrop(r, bar.backdrop, db.replaceBorder)
		if db.replaceBorder then
			HideChrome(bar.shadow)
			HideChrome(bar.eltruismuniversalborders)
			if host == 'elvui' then EltruismBorder(frame, bar, key, power) end
		end
	end
	Divisions(r, db, w, h, vertical, ratio)
	if r.cap then
		r.overlay:SetFrameStrata(bar:GetFrameStrata())
		r.overlay:SetFrameLevel(math.max(frame:GetFrameLevel(), bar:GetFrameLevel()) + 10)
		local cap = db.cap
		local size = h * Bound(cap.scale, .5, 4, 2.2)
		r.cap:ClearAllPoints(); r.cap:SetSize(size * Bound(cap.width, .5, 2, 1), size)
		r.cap:SetPoint('CENTER', bar, cap.side == 'LEFT' and 'LEFT' or 'RIGHT',
			Bound(cap.x, -200, 200, 0), Bound(cap.y, -200, 200, 0))
		local flip = (cap.side == 'LEFT') ~= cap.mirror
		r.cap:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
		PaintCap(r)
	end
	return r
end

local function Apply(frame, host, key, data)
	if not Object(frame) or not supported[key] then return end
	local health, power = data and data.health or frame.Health, data and data.power or frame.Power
	local r = Skin(frame, health, host, key, false, data and data.bg)
	local p = Skin(frame, power, host, key, true, data and data.powerBg)
	local db = Settings(host, key)
	if r and r.shaped then
		local pred = frame.HealthPrediction
		if pred then
			for _, field in ipairs({'healingPlayer', 'healingOther', 'damageAbsorb', 'healAbsorb'}) do Prediction(r, pred[field]) end
		end
		local absorb = data and data.absorbBar or pred and pred.damageAbsorb
		if absorb then
			for _, bar in ipairs({absorb, absorb._forward or false, absorb._healAbsorb or false, absorb._healPred or false}) do
				if bar then Prediction(r, bar) end
			end
		end
		if frame.Cutaway then Attach(r, frame.Cutaway.Health) end
		if db.replaceBorder then
			HideChrome(frame.unifiedBorder)
			if data then HideChrome(data.borderFrame) end
			if host == 'elvui' then
				HideChrome(frame.shadow)
				HideChrome(frame.backdrop)
				HideChrome(frame.eltruismuniversalborders)
			end
		end
	end
	if p and p.shaped then
		if frame.Cutaway then Attach(p, frame.Cutaway.Power) end
		if db.replaceBorder and data then HideChrome(data.powerBorderFrame) end
	end
end

local function Category(frame)
	-- ElvUI supplies stable categories even when a secure header swaps units.
	local key = frame.unitframeType
	if Secret(key) or type(key) ~= 'string' or frame.isChild then return end
	if key == 'raid1' or key == 'raid2' or key == 'raid3' then return 'raid' end
	if supported[key] then return key end
end
local function Namespace(raid)
	local eui = _G.EllesmereUI
	return eui and eui._ModuleNS and eui._ModuleNS[raid and 'EllesmereUIRaidFrames' or 'EllesmereUIUnitFrames']
end
local function Discover()
	local E = _G.ElvUI and _G.ElvUI[1]
	if JI:IsAddOnEnabled('ElvUI') and E then
		local UF = E.UnitFrames
		for _, name in ipairs({'ConfigureFrame', 'CreateAndUpdateUF', 'CreateAndUpdateHeaderGroup', 'Update_AllFrames', 'LoadUnits'}) do
			Hook(UF, name, Queue)
		end
		-- Cosmetic objects can be created after ElvUI's layout has completed.
		-- Hook configuration entry points, not per-health-update gradient paths.
		for _, name in ipairs({'Borders', 'PartyBorders', 'PetBorders', 'Shadows', 'RaidShadows', 'CustomTexture'}) do
			Hook(_G.ElvUI_EltreumUI, name, Queue)
		end
		local seen = {}
		local function Visit(frame)
			if Object(frame) and not seen[frame] then
				seen[frame] = true; Apply(frame, 'elvui', Category(frame))
			end
		end
		for _, frame in pairs(E.oUF and E.oUF.objects or {}) do Visit(frame) end
		for _, frame in pairs(UF and UF.units or {}) do Visit(frame) end
	end
	local ns, raid = Namespace(), Namespace(true)
	-- Ellesmere's Blizzard/Classic art kits own their own silhouettes.
	local nativeEUI = ns and (not ns.UF_Style or ns.UF_Style() == 'eui')
	if ns and nativeEUI and JI:IsAddOnEnabled('EllesmereUIUnitFrames') then
		for _, name in ipairs({'Attach', 'AttachPolled'}) do
			Hook(ns.Engine, name, function(frame, unit)
				if Secret(unit) or type(unit) ~= 'string' or not Object(frame) then return end
				local key = unit:match('^boss%d+$') and 'boss' or unit
				if supported[key] then attachedFrames[frame] = key; Queue() end
			end)
		end
		Hook(ns.Engine, 'RepaintAll', function(frame)
			local r = frame and records[frame.Health]
			if r then PaintCap(r) end
		end)
		Hook(ns, 'ReloadFrames', function()
			Queue()
			-- Ellesmere's public entry point arms a throttled layout.
			C_Timer.After(.2, Queue)
		end)
		local seenKeys = {}
		for unit, frame in pairs(ns.frames or {}) do
			if type(unit) == 'string' and Object(frame) then
				local key = unit:match('^boss%d+$') and 'boss' or unit
				if supported[key] then seenKeys[unit] = frame; Apply(frame, 'ellesmereui', key) end
			end
		end
		for frame, key in pairs(attachedFrames) do
			local unit = frame._euiUnit
			if not Secret(unit) and (not seenKeys[unit] or seenKeys[unit] == frame) then Apply(frame, 'ellesmereui', key)
			else attachedFrames[frame] = nil end
		end
	end
	if raid and JI:IsAddOnEnabled('EllesmereUIRaidFrames') then
		for _, name in ipairs({'_CreatePartyHeader', '_RebuildPartyUnitMap', '_UpdateAllPartyButtons',
			'_LayoutPartyFrames', '_LayoutGroupsImpl', '_BuildHeaderSet', 'ReloadPartyFrames', 'ReloadFrames',
			'_UpdateAllButtons'}) do Hook(raid, name, Queue) end
		if type(raid.GetFFD) == 'function' then
			for _, group in ipairs({{'party', raid._partyAllButtons}, {'raid', raid._allButtons}}) do
				for _, frame in ipairs(group[2] or {}) do
					if Object(frame) then
						local data = raid.GetFFD(frame)
						if type(data) == 'table' then Apply(frame, 'ellesmereui', group[1], data) end
					end
				end
			end
		end
	end
end

function JI:UpdateUnitFrameThemes()
	if not driver or not JI.db then return end
	if InCombatLockdown() then
		for _, r in pairs(records) do PaintCap(r) end
		return
	end
	for _, r in pairs(records) do r.seen = false end
	for _, c in pairs(chrome) do c.seen = false end
	Discover()
	for _, r in pairs(records) do if not r.seen then Restore(r) end end
	for object, c in pairs(chrome) do if c.active and not c.seen then RestoreChrome(object, c) end end
end

function JI:SetupUnitFrameThemes()
	if driver then return end
	driver = CreateFrame('Frame')
	for _, event in ipairs({'ADDON_LOADED', 'PLAYER_LOGIN', 'PLAYER_ENTERING_WORLD', 'PLAYER_REGEN_ENABLED',
		'GROUP_ROSTER_UPDATE', 'PLAYER_TARGET_CHANGED', 'PLAYER_FOCUS_CHANGED', 'UNIT_TARGET', 'UNIT_NAME_UPDATE',
		'UNIT_FACTION', 'UNIT_CONNECTION', 'UI_SCALE_CHANGED', 'DISPLAY_SIZE_CHANGED'}) do driver:RegisterEvent(event) end
	driver:SetScript('OnEvent', function(_, event)
		if event == 'PLAYER_TARGET_CHANGED' or event == 'PLAYER_FOCUS_CHANGED' or event:find('^UNIT_') then
			for _, r in pairs(records) do PaintCap(r) end
		else Queue() end
	end)
	JI:UpdateUnitFrameThemes()
	C_Timer.After(1, Queue)
end
