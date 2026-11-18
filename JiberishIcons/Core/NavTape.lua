-- Nameplate nav tape: a row of hairline ticks on the target's nameplate with the
-- distance beside it. A marker rides the tape to where the unit is across your
-- screen, ticks near it lift and light (the lens), and the tape scrolls as the
-- unit or your view moves.
--
-- What the game lets an addon know, and so what this shows:
--   * Distance comes in brackets, from whether your own spells (and, out of
--     combat, the interact distances) reach the unit: "< 10 YD", "10-28 YD".
--     When those answers are secret, every bracket label is stacked in one place
--     and each is shown or hidden straight from the answers through
--     SetAlphaFromBoolean, so the right one reads without Lua seeing it.
--   * Facing: an enemy's facing is not readable. The marker shows where the plate
--     is across the screen and changes color while the unit targets you.
--
-- Hosts: ElvUI's oUF nameplates (E.NamePlates) and EllesmereUINameplates. Their
-- plates are found from the nameplate unit token; their files and frames are
-- never changed. Our tapes live in a side table keyed by the host plate.
local JI = unpack(JiberishIcons)
local Hud = JI.Hud

local CreateFrame, GetTime, InCombatLockdown = CreateFrame, GetTime, InCombatLockdown
local floor, max, min, abs, sin, pi = math.floor, math.max, math.min, math.abs, math.sin, math.pi
local IsSecret, Plain, Clamp = Hud.IsSecret, Hud.Plain, Hud.Clamp
local WHITE, ROUND = Hud.WHITE, Hud.ROUND

local function DB() return JI.db.navTape end
local function Reduced() return DB().reduceMotion end
local function Num(value, fallback, low, high) return floor(Clamp(value, fallback, low, high) + 0.5) end

-- Range checks -------------------------------------------------------------------
-- One check per distinct spell range, from the player's own spellbook: harmful
-- spells measure enemies, helpful spells friends. Auto Attack is melee. Spells
-- with a minimum range are left out: being out of their range says nothing.
local checkers, BuildCheckers, ChecksFor, Ask, Bracket, YardsText
local MELEE, AUTO_ATTACK = 5, 6603
do
	local CLASS_SPELLS = {
		DEATHKNIGHT = {49576, 47541}, DEMONHUNTER = {185123, 183752, 204021}, EVOKER = {362969},
		DRUID = {5176, 339, 6795, 33786, 22568, 8921}, HUNTER = {466930, 75}, MAGE = {44614, 11366, 118, 116, 133, 44425},
		MONK = {115546, 115078, 100780, 117952}, PALADIN = {853, 35395, 62124, 183218, 20271, 20473},
		PRIEST = {589, 8092, 585}, ROGUE = {185565, 36554, 185763, 2094, 921}, SHAMAN = {370, 8042, 117014, 188196, 73899},
		WARRIOR = {355, 5246}, WARLOCK = {686, 5782, 232670, 234153},
	}
	-- Out of combat only: the game's interact distances (duel, follow).
	local INTERACT = {{index = 3, range = 10}, {index = 4, range = 28}}
	local IsSpellInRange = (C_Spell and C_Spell.IsSpellInRange) or _G.IsSpellInRange
	local harmChecks, helpChecks = {}, {}
	checkers = harmChecks

	local function Known(spell)
		if IsPlayerSpell and Plain(IsPlayerSpell, spell) then return true end
		local book = C_SpellBook and C_SpellBook.IsSpellKnown
		return book and Plain(book, spell) and true or false
	end

	local function SpellRange(spell)
		local info = C_Spell and C_Spell.GetSpellInfo and Plain(C_Spell.GetSpellInfo, spell)
		if type(info) ~= 'table' then return nil end
		local low, high = info.minRange, info.maxRange
		if IsSecret(low) or IsSecret(high) or type(high) ~= 'number' then return nil end
		if type(low) == 'number' and low > 0 then return nil end
		return high > 0 and high or MELEE
	end

	local function SpellbookSpells(visit)
		local book = C_SpellBook
		if book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo then
			local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
			local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
			for line = 1, Plain(book.GetNumSpellBookSkillLines) or 0 do
				local info = Plain(book.GetSpellBookSkillLineInfo, line)
				if type(info) == 'table' and not IsSecret(info.itemIndexOffset) and not IsSecret(info.numSpellBookItems) then
					local first = (info.itemIndexOffset or 0) + 1
					for slot = first, first + (info.numSpellBookItems or 0) - 1 do
						local item = Plain(book.GetSpellBookItemInfo, slot, bank)
						if type(item) == 'table' and not IsSecret(item.spellID) and not IsSecret(item.isPassive)
							and not IsSecret(item.itemType) and (not spellType or item.itemType == spellType)
							and item.spellID and not item.isPassive then
							visit(item.spellID)
						end
					end
				end
			end
			return
		end
		if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
			for tab = 1, Plain(GetNumSpellTabs) or 0 do
				local ok, _, _, offset, count = pcall(GetSpellTabInfo, tab)
				if ok and not IsSecret(offset) and not IsSecret(count) and type(offset) == 'number' and type(count) == 'number' then
					for slot = offset + 1, offset + count do
						local okItem, kind, id = pcall(GetSpellBookItemInfo, slot, 'spell')
						if okItem and not IsSecret(kind) and not IsSecret(id) and kind == 'SPELL' and type(id) == 'number' then visit(id) end
					end
				end
			end
		end
	end

	local function Add(list, byRange, entry)
		if byRange[entry.range] then return end
		byRange[entry.range] = true
		list[#list + 1] = entry
	end

	local function Nearest(a, b) return a.range < b.range end

	function BuildCheckers()
		wipe(harmChecks); wipe(helpChecks)
		local harmRange, helpRange = {}, {}
		if IsSpellInRange then Add(harmChecks, harmRange, {spell = AUTO_ATTACK, range = MELEE}) end
		local isHarmful = C_Spell and C_Spell.IsSpellHarmful
		local isHelpful = C_Spell and C_Spell.IsSpellHelpful
		SpellbookSpells(function(spell)
			local range = SpellRange(spell)
			if not range or range > 100 then return end
			if isHarmful and Plain(isHarmful, spell) then Add(harmChecks, harmRange, {spell = spell, range = range}) end
			if isHelpful and Plain(isHelpful, spell) then Add(helpChecks, helpRange, {spell = spell, range = range}) end
		end)
		-- The class list, for anything the spellbook didn't answer.
		local _, class = UnitClass('player')
		for _, spell in ipairs(not IsSecret(class) and CLASS_SPELLS[class] or {}) do
			local range = Known(spell) and SpellRange(spell)
			if range then Add(harmChecks, harmRange, {spell = spell, range = range}) end
		end
		for _, interact in ipairs(INTERACT) do
			Add(harmChecks, harmRange, {index = interact.index, range = interact.range})
			Add(helpChecks, helpRange, {index = interact.index, range = interact.range})
		end
		table.sort(harmChecks, Nearest)
		table.sort(helpChecks, Nearest)
		checkers = harmChecks
	end

	-- Harmful spells for enemies, helpful ones for anyone you can't attack.
	function ChecksFor(unit)
		local hostile = Plain(UnitCanAttack, 'player', unit)
		checkers = (hostile == false and #helpChecks > 0) and helpChecks or harmChecks
	end

	-- Fills answers with each check's answer; true when any is secret. Checks
	-- that can't be asked now (interact distances in combat) answer nil.
	function Ask(unit, answers)
		local secret, fighting = false, InCombatLockdown()
		for index, checker in ipairs(checkers) do
			local ok, answer
			if checker.spell then
				if IsSpellInRange then ok, answer = pcall(IsSpellInRange, checker.spell, unit) end
			elseif not fighting and CheckInteractDistance then
				ok, answer = pcall(CheckInteractDistance, unit, checker.index)
			end
			if not ok then answer = nil end
			answers[index] = answer
			if IsSecret(answer) then secret = true end
		end
		for index = #checkers + 1, #answers do answers[index] = nil end
		return secret
	end

	-- Plain answers only: the farthest range the unit is beyond and the nearest
	-- range it is within.
	function Bracket(answers)
		local low, high
		for index, checker in ipairs(checkers) do
			local answer = answers[index]
			if answer == true or answer == 1 then
				if not high or checker.range < high then high = checker.range end
			elseif answer == false or answer == 0 then
				if not low or checker.range > low then low = checker.range end
			end
		end
		if low and high and low >= high then low = nil end
		return low, high
	end

	-- In melee reach: MELEE. Otherwise by the style: the bracket ("10-28 YD",
	-- "< 10 YD", "> 28 YD"), the nearest range only, or the farthest known.
	function YardsText(low, high)
		if high and high <= MELEE then return 'MELEE', true end
		local db = DB()
		local yd = db.yardsSuffix == false and '' or ' YD'
		local style = db.yardsStyle or 'bracket'
		if style == 'single' then
			if high then return format('%d%s', high, yd), false end
			if low then return format('%d+%s', low, yd), false end
		elseif style == 'far' then
			if low then return format('> %d%s', low, yd), false end
			if high then return format('< %d%s', high, yd), false end
		else
			if low and low <= MELEE then low = nil end
			if low and high then return format('%d-%d%s', low, high, yd), false end
			if high then return format('< %d%s', high, yd), false end
			if low then return format('> %d%s', low, yd), false end
		end
		return '--'..yd, false
	end
end

-- Look --------------------------------------------------------------------------
local colors = {}
local ReadColors, PaintText, Lamp
do
	local ROLES = {tickColor = 'dim', majorColor = 'text', lensColor = 'accent', markerColor = 'accent',
		alertColor = 'alert', yardsColor = 'text', baseColor = 'dim', meleeColor = 'alert'}
	local CLASSED = {lensColor = true, markerColor = true}

	function ReadColors()
		local db = DB()
		for key, role in pairs(ROLES) do
			local c = colors[key] or {}
			if db.colors == 'custom' and type(db[key]) == 'table' then
				c[1], c[2], c[3] = Hud.Saved(db[key], role)
			elseif db.colors == 'class' and CLASSED[key] then
				c[1], c[2], c[3] = Hud.ClassColor()
			else
				c[1], c[2], c[3] = Hud.Color(role)
			end
			colors[key] = c
		end
	end

	function PaintText(text, melee)
		local c = melee and colors.meleeColor or colors.yardsColor
		if c then text:SetTextColor(c[1], c[2], c[3]) end
	end

	-- A round lamp with a soft halo, shown beside MELEE.
	function Lamp(parent)
		local lamp = CreateFrame('Frame', nil, parent)
		lamp:SetSize(7, 7)
		lamp.halo = lamp:CreateTexture(nil, 'ARTWORK')
		lamp.halo:SetTexture(ROUND)
		lamp.halo:SetPoint('CENTER')
		lamp.halo:SetSize(11, 11)
		lamp.halo:SetBlendMode('ADD')
		lamp.dot = lamp:CreateTexture(nil, 'OVERLAY')
		lamp.dot:SetTexture(ROUND)
		lamp.dot:SetAllPoints()
		lamp:Hide()
		return lamp
	end
end

local function PaintLamp(lamp)
	local c = colors.meleeColor or {1, 0.24, 0.2}
	lamp.dot:SetVertexColor(c[1], c[2], c[3], 1)
	lamp.halo:SetVertexColor(c[1], c[2], c[3], 0.45)
end

-- The tape -----------------------------------------------------------------------
local bars = setmetatable({}, {__mode = 'k'}) -- host plate -> its tape
local active = {} -- tapes being shown
local preview

local RIPPLE = 2
local EDGE_FADE = 0.2 -- of the width, where ticks fade at each end
local LENS_SPAN = 4.5 -- in tick spacings either side of the marker
local PARALLAX = 1.6
local MAX_ROWS = 6

local function Snap(value, px) return floor(value / px + 0.5) * px end

local Marker, LayoutMarker
do
	-- A caret, a hairline, a dot or a diamond over a hairline through the tape.
	function Marker(parent)
		local m = CreateFrame('Frame', nil, parent)
		m.rows = {}
		for row = 1, MAX_ROWS do
			local piece = m:CreateTexture(nil, 'OVERLAY', nil, 3)
			piece:SetTexture(WHITE)
			m.rows[row] = piece
		end
		m.line = m:CreateTexture(nil, 'OVERLAY', nil, 2)
		m.line:SetTexture(WHITE)
		m.dot = m:CreateTexture(nil, 'OVERLAY', nil, 3)
		m.dot:SetTexture(ROUND)
		m.diamond = m:CreateTexture(nil, 'OVERLAY', nil, 3)
		m.diamond:SetTexture(WHITE)
		return m
	end

	-- Returns the height of the marker's head above the tape.
	function LayoutMarker(m, style, size, px, tapeHeight, color)
		for _, piece in ipairs(m.rows) do piece:Hide() end
		m.dot:Hide(); m.diamond:Hide()
		local head, wide = 0, px
		if style == 'caret' then
			for row = 1, size do
				local piece = m.rows[row]
				piece:ClearAllPoints()
				piece:SetSize((2 * (size - row) + 1) * px, px)
				piece:SetPoint('TOP', m, 'TOP', 0, -(row - 1) * px)
				piece:Show()
			end
			head, wide = size * px, (2 * size - 1) * px
		elseif style == 'dot' then
			local d = (2 * size - 1) * px
			m.dot:ClearAllPoints(); m.dot:SetSize(d, d); m.dot:SetPoint('TOP', m, 'TOP', 0, 0); m.dot:Show()
			head, wide = d + px, d
		elseif style == 'diamond' then
			local d = (2 * size - 1) * px
			local side = max(px, floor(d / 1.414 / px + 0.5) * px)
			m.diamond:ClearAllPoints(); m.diamond:SetSize(side, side)
			m.diamond:SetRotation(pi / 4)
			m.diamond:SetPoint('CENTER', m, 'TOP', 0, -d / 2); m.diamond:Show()
			head, wide = d + px, d
		end
		local lineWidth = style == 'line' and max(1, floor(size / 2)) * px or px
		m.line:ClearAllPoints()
		m.line:SetSize(lineWidth, tapeHeight)
		m.line:SetPoint('TOP', m, 'TOP', 0, -head)
		local r, g, b = color[1], color[2], color[3]
		for _, piece in ipairs(m.rows) do piece:SetVertexColor(r, g, b) end
		m.line:SetVertexColor(r, g, b); m.dot:SetVertexColor(r, g, b); m.diamond:SetVertexColor(r, g, b)
		m:SetSize(max(wide, lineWidth), head + tapeHeight)
		return head
	end
end

local function Build(parent)
	local bar = CreateFrame('Frame', nil, parent or UIParent)
	bar:EnableMouse(false)
	bar:Hide()
	-- Behind the tape: an optional host-colored backdrop, or a hairline baseline.
	bar.back = CreateFrame('Frame', nil, bar)
	bar.back.fill = bar.back:CreateTexture(nil, 'BACKGROUND')
	bar.back.fill:SetTexture(WHITE)
	bar.back.fill:SetAllPoints()
	bar.back.edges = Hud.Border(bar.back)
	bar.back:Hide()
	bar.base = bar:CreateTexture(nil, 'ARTWORK')
	bar.base:SetTexture(WHITE)
	bar.base:Hide()
	-- The distance: plain answers write one string; secret answers light one of
	-- a stack of bracket labels (see ShowSecret).
	bar.yards = bar:CreateFontString(nil, 'OVERLAY')
	bar.yards:SetWordWrap(false)
	bar.lamp = Lamp(bar)
	bar.lamp:SetPoint('RIGHT', bar.yards, 'LEFT', -3, 0)
	bar.layerHolder = CreateFrame('Frame', nil, bar)
	bar.layers = {}
	-- Clipped, so ticks scroll in and out under the fade.
	bar.tape = CreateFrame('Frame', nil, bar)
	bar.tape:SetFrameLevel(bar.back:GetFrameLevel() + 2)
	bar.tape:SetClipsChildren(true)
	bar.strip = CreateFrame('Frame', nil, bar.tape)
	bar.strip:SetSize(1, 1)
	bar.ticks = {}
	-- The marker, and a second one shown while the unit targets you. Each has
	-- its own frame so a secret targeting answer can switch them unread.
	bar.marker = CreateFrame('Frame', nil, bar)
	bar.marker:SetFrameLevel(bar.tape:GetFrameLevel() + 3)
	bar.calm = Marker(bar.marker)
	bar.alert = Marker(bar.marker)
	bar.alert:SetAlpha(0)
	bar.at, bar.goal, bar.speed, bar.wave, bar.fade = 0, 0, 0, 0, 1
	bar.answers = {}
	return bar
end

local function TickTexture(tick, style)
	tick:SetTexture(style == 'dots' and ROUND or WHITE)
	tick:SetRotation(style == 'notches' and pi / 4 or 0)
end

local function LayoutTicks(bar)
	local db, px, width = DB(), bar.px, bar.tapeW
	local wanted = Num(db.ticks, 24, 8, 48)
	local spacing = max(3 * px, Snap(width / wanted, px))
	local total = floor(width / spacing) + 3
	local style = bar.tickStyle
	local weight = bar.tickWeight * px
	if style == 'bars' then weight = max(2 * px, Snap(spacing * 0.45, px)) end
	bar.spacing, bar.tickCount = spacing, total
	for index = 1, total do
		local tick = bar.ticks[index]
		if not tick then
			tick = bar.strip:CreateTexture(nil, 'ARTWORK')
			if tick.SetSnapToPixelGrid then tick:SetSnapToPixelGrid(false); tick:SetTexelSnappingBias(0) end
			bar.ticks[index] = tick
		end
		if bar.tickStyles[index] ~= style then bar.tickStyles[index] = style; TickTexture(tick, style) end
		tick:ClearAllPoints()
		local x = (index - 1) * spacing
		if style == 'notches' then
			tick:SetPoint('CENTER', bar.strip, 'BOTTOMLEFT', x, 0)
		elseif style == 'dots' then
			tick:SetPoint('BOTTOM', bar.strip, 'BOTTOMLEFT', x, 0)
		else
			tick:SetPoint('BOTTOMLEFT', bar.strip, 'BOTTOMLEFT', x, 0)
			tick:SetWidth(weight)
		end
		tick:SetHeight(bar.minorH * px)
		if style == 'dots' or style == 'notches' then tick:SetWidth(bar.minorH * px) end
		bar.tickHeights[index], bar.tickYs[index] = nil, nil
		tick:Show()
	end
	for index = total + 1, #bar.ticks do bar.ticks[index]:Hide() end
end

-- Where the distance sits: above or below the tape, or beside it.
local function AnchorText(region, pos, tape, head, px)
	region:ClearAllPoints()
	if pos == 'below' then region:SetPoint('TOP', tape, 'BOTTOM', 0, -2 * px)
	elseif pos == 'left' then region:SetPoint('RIGHT', tape, 'LEFT', -4 * px, 0)
	elseif pos == 'right' then region:SetPoint('LEFT', tape, 'RIGHT', 4 * px, 0)
	else region:SetPoint('BOTTOM', tape, 'TOP', 0, head + 2 * px) end
end

local function FontText(text, db, pos)
	Hud.SetFont(text, db.font, Num(db.yardsSize, 10, 6, 20), db.yardsOutline and 'OUTLINE' or '')
	text:SetJustifyH(pos == 'left' and 'RIGHT' or pos == 'right' and 'LEFT' or 'CENTER')
end

local function Layout(bar)
	local db = DB()
	ReadColors()
	local scale, rawWidth = Plain(bar.GetEffectiveScale, bar), Plain(bar.GetWidth, bar)
	if not scale then return end
	bar.tickStyles = bar.tickStyles or {}
	bar.tickHeights, bar.tickYs = bar.tickHeights or {}, bar.tickYs or {}
	local px = Hud.Pixel(bar)
	bar.px, bar.scale = px, scale
	local width = Snap(max(type(rawWidth) == 'number' and rawWidth or 0, 40), px)
	-- The measured width, unclamped, is what the driver compares against.
	bar.width, bar.rawWidth = width, type(rawWidth) == 'number' and rawWidth or 0
	bar.tickStyle = db.tickStyle or 'lines'
	bar.tickWeight = Num(db.tickWeight, 1, 1, 3)
	bar.minorH = Num(db.tickMinor, 3, 1, 12)
	bar.majorH = max(bar.minorH, Num(db.tickMajor, 6, 1, 16))
	bar.majorEvery = Num(db.majorEvery, 5, 2, 12)
	bar.lift = (db.lens and db.bearing) and Num(db.lensLift, 4, 0, 10) or 0
	if bar.tickStyle == 'dots' then
		bar.dotMinor = (bar.tickWeight + 1) * px
		bar.dotMajor = (bar.tickWeight + 2) * px
	end
	local ripple = (bar.lift > 0 and db.tape) and RIPPLE or 0
	local tallest = bar.tickStyle == 'dots' and bar.tickWeight + 2 or bar.majorH
	local tapeHeight = (tallest + bar.lift + ripple) * px
	local pos = db.yardsPosition or 'above'
	local size = Num(db.yardsSize, 10, 6, 20)
	local textH = db.yards and size + 3 or 0
	local side = db.yards and (pos == 'left' or pos == 'right')
	local textW = side and Snap(size * 6.2, px) or 0
	local avail = width - (side and textW + 4 * px or 0)
	local tapeW = Snap(avail * Clamp(db.tapeWidth, 100, 40, 100) / 100, px)
	bar.tapeW = tapeW
	local markerStyle, markerSize = db.markerStyle or 'caret', Num(db.markerSize, 3, 2, MAX_ROWS)
	local head = LayoutMarker(bar.calm, markerStyle, markerSize, px, tapeHeight, colors.markerColor)
	LayoutMarker(bar.alert, markerStyle, markerSize, px, tapeHeight, colors.alertColor)
	if not db.bearing then head = 0 end
	local x = Snap((avail - tapeW) / 2, px) + ((pos == 'left' and side) and textW + 4 * px or 0)
	bar.tape:ClearAllPoints()
	if side then
		bar:SetHeight(max(textH, head + tapeHeight))
		bar.tape:SetPoint('BOTTOMLEFT', bar, 'BOTTOMLEFT', x, 0)
	elseif pos == 'below' then
		bar:SetHeight(head + tapeHeight + 2 * px + textH)
		bar.tape:SetPoint('TOPLEFT', bar, 'TOPLEFT', x, -head)
	else
		bar:SetHeight(textH + head + tapeHeight + 2 * px)
		bar.tape:SetPoint('BOTTOMLEFT', bar, 'BOTTOMLEFT', x, 0)
	end
	bar.tape:SetSize(tapeW, tapeHeight)
	FontText(bar.yards, db, pos)
	AnchorText(bar.yards, pos, bar.tape, head, px)
	bar.yards:SetShown(db.yards and not bar.secret and true or false)
	PaintText(bar.yards, bar.isMelee)
	PaintLamp(bar.lamp)
	if not db.yards then bar.lamp:Hide() end
	bar.layerHolder:SetSize(side and textW or tapeW, max(textH, 1))
	AnchorText(bar.layerHolder, pos, bar.tape, head, px)
	bar.layerHolder:SetShown(db.yards and true or false)
	for _, layer in ipairs(bar.layers) do
		FontText(layer.label, db, pos)
		layer.label:ClearAllPoints()
		layer.label:SetPoint(pos == 'left' and 'RIGHT' or pos == 'right' and 'LEFT' or 'CENTER')
		PaintText(layer.label, layer.melee)
		PaintLamp(layer.lamp)
	end
	bar.text, bar.signature = nil, nil
	-- Behind the tape.
	local background = db.background or 'none'
	bar.base:ClearAllPoints()
	bar.base:SetPoint('BOTTOMLEFT', bar.tape, 'BOTTOMLEFT', 0, 0)
	bar.base:SetSize(tapeW, px)
	bar.base:SetVertexColor(colors.baseColor[1], colors.baseColor[2], colors.baseColor[3], 0.8)
	bar.base:SetShown(background == 'baseline')
	if background == 'backdrop' then
		local br, bg, bb = Hud.Color('backdrop')
		bar.back.fill:SetVertexColor(br, bg, bb, Clamp(db.backdropAlpha, 0.6, 0, 1))
		Hud.TintAll(bar.back.edges, Hud.Color('border'))
		Hud.PlaceBorder(bar.back.edges, bar.back, px)
		bar.back:ClearAllPoints()
		bar.back:SetPoint('TOPLEFT', bar.tape, 'TOPLEFT', -3 * px, 2 * px)
		bar.back:SetPoint('BOTTOMRIGHT', bar.tape, 'BOTTOMRIGHT', 3 * px, -2 * px)
		bar.back:Show()
	else
		bar.back:Hide()
	end
	bar.marker:SetSize(1, 1)
	for _, marker in ipairs({bar.calm, bar.alert}) do
		marker:ClearAllPoints()
		marker:SetPoint('BOTTOM', bar.marker, 'CENTER', 0, 0)
	end
	bar.marker:SetShown(db.bearing and true or false)
	LayoutTicks(bar)
	bar.stripX, bar.markerX, bar.dirty = nil, nil, true
end

-- Above or below the host plate's health bar.
local function Place(bar, plate, anchor)
	local db = DB()
	bar:SetParent(plate)
	bar:SetFrameLevel((Plain(plate.GetFrameLevel, plate) or 1) + Num(db.level, 10, 1, 50))
	bar:ClearAllPoints()
	local inset, x, y = Num(db.inset, 2, -20, 40), Num(db.xOffset, 0, -200, 200), Num(db.yOffset, 14, -100, 100)
	if db.position == 'below' then
		bar:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', inset + x, -y)
		bar:SetPoint('TOPRIGHT', anchor, 'BOTTOMRIGHT', -inset + x, -y)
	else
		bar:SetPoint('BOTTOMLEFT', anchor, 'TOPLEFT', inset + x, y)
		bar:SetPoint('BOTTOMRIGHT', anchor, 'TOPRIGHT', -inset + x, y)
	end
	Layout(bar)
end

-- Drawing ------------------------------------------------------------------------
local function ScrollOf(bar)
	if not DB().tape or Reduced() then return 0 end
	local scroll = bar.screenX and bar.screenX * PARALLAX or 0
	if bar.heading then scroll = scroll + bar.heading * (bar.tapeW or bar.width) / (pi / 2) end
	return scroll
end

local function Draw(bar)
	local px, width, spacing = bar.px, bar.tapeW, bar.spacing
	if not (px and width and spacing) then return end
	local stripX = Snap(-(ScrollOf(bar) % spacing), px)
	if stripX ~= bar.stripX then
		bar.stripX = stripX
		bar.strip:ClearAllPoints()
		bar.strip:SetPoint('BOTTOMLEFT', bar.tape, 'BOTTOMLEFT', stripX, 0)
		bar.dirty = true
	end
	local db = DB()
	local markerX = Snap(width / 2 + bar.at * (width / 2 - 4 * px), px)
	if markerX ~= bar.markerX then
		bar.markerX = markerX
		bar.marker:ClearAllPoints()
		bar.marker:SetPoint('CENTER', bar.tape, 'BOTTOMLEFT', markerX + px / 2, 0)
		bar.dirty = true
	end
	local moving = bar.speed > 0 and db.tape and not Reduced()
	if not (bar.dirty or moving or bar.rippling) then return end
	bar.dirty, bar.rippling = nil, moving or nil
	local first = floor(ScrollOf(bar) / spacing)
	local liftMax = bar.lift or 0
	local lens = db.lens and db.bearing
	local fade = db.edgeFade ~= false and EDGE_FADE * width or nil
	local reach = LENS_SPAN * spacing
	local style, every = bar.tickStyle, bar.majorEvery
	local minorC, majorC, lensC = colors.tickColor, colors.majorColor, colors.lensColor
	local heights, ys = bar.tickHeights, bar.tickYs
	for index = 1, bar.tickCount do
		local tick = bar.ticks[index]
		local x = stripX + (index - 1) * spacing
		local major = (first + index - 1) % every == 0
		local edge = fade and min(1, max(0, x / fade), max(0, (width - x) / fade)) or 1
		local near = 0
		if lens then
			local distance = abs(x - markerX)
			if distance < reach then
				near = 1 - distance / reach
				near = near * near * (3 - 2 * near)
			end
		end
		local lift = near * liftMax
		if moving and liftMax > 0 then lift = lift + near * RIPPLE * (0.5 + 0.5 * sin(bar.wave - (index + first) * 0.9)) end
		if style == 'dots' then
			local d = major and bar.dotMajor or bar.dotMinor
			if heights[index] ~= d then heights[index] = d; tick:SetSize(d, d) end
			local y = floor(lift + 0.5) * px
			if ys[index] ~= y then
				ys[index] = y
				tick:ClearAllPoints()
				tick:SetPoint('BOTTOM', bar.strip, 'BOTTOMLEFT', (index - 1) * spacing, y)
			end
		elseif style == 'notches' then
			local side = floor(((major and bar.majorH or bar.minorH) + lift) * 1.414 + 0.5) * px
			if heights[index] ~= side then heights[index] = side; tick:SetSize(side, side) end
		else
			local height = floor((major and bar.majorH or bar.minorH) + lift + 0.5) * px
			if heights[index] ~= height then heights[index] = height; tick:SetHeight(height) end
		end
		local base = major and 0.85 or 0.45
		tick:SetAlpha(edge * (base + (1 - base) * near))
		local c = major and majorC or minorC
		local r, g, b = c[1], c[2], c[3]
		tick:SetVertexColor(r + (lensC[1] - r) * near, g + (lensC[2] - g) * near, b + (lensC[3] - b) * near)
	end
end

-- Distance labels ----------------------------------------------------------------
local function ShowPlain(bar, low, high)
	if bar.secret then
		bar.secret = nil
		for _, layer in ipairs(bar.layers) do layer.gate:Hide() end
		bar.yards:SetShown(DB().yards and true or false)
	end
	local text, melee = YardsText(low, high)
	if text ~= bar.text then
		bar.text = text
		bar.yards:SetText(text)
		bar.isMelee = melee
		PaintText(bar.yards, melee)
		bar.lamp:SetShown(melee and DB().meleeLamp ~= false)
	end
end

-- One label per bracket the answers can tell apart, all in one place. Label k
-- reads "within check k": its own alpha comes from that answer, and its gate
-- hides it when the unit is also within check k-1. The last label, beyond
-- every check, is gated by the farthest one.
local function Layer(bar, index)
	local layer = bar.layers[index]
	if layer then return layer end
	local gate = CreateFrame('Frame', nil, bar.layerHolder)
	gate:SetAllPoints()
	local label = gate:CreateFontString(nil, 'OVERLAY')
	label:SetWordWrap(false)
	local db = DB()
	local pos = db.yardsPosition or 'above'
	FontText(label, db, pos)
	label:SetPoint(pos == 'left' and 'RIGHT' or pos == 'right' and 'LEFT' or 'CENTER')
	local lamp = Lamp(gate)
	lamp:SetPoint('RIGHT', label, 'LEFT', -3, 0)
	PaintLamp(lamp)
	layer = {gate = gate, label = label, lamp = lamp}
	bar.layers[index] = layer
	return layer
end

local function ShowSecret(bar, answers)
	local holder = bar.layerHolder
	if not (holder.SetAlphaFromBoolean and bar.yards.SetAlphaFromBoolean) then
		bar.yards:SetText('')
		bar.text = nil
		return
	end
	if not bar.secret then
		bar.secret = true
		bar.yards:Hide()
		bar.lamp:Hide()
		bar.text = nil
	end
	local usable, signature = bar.usable or {}, ''
	wipe(usable)
	for index, checker in ipairs(checkers) do
		local answer = answers[index]
		if IsSecret(answer) or answer ~= nil then
			usable[#usable + 1] = index
			signature = signature..checker.range..','
		end
	end
	bar.usable = usable
	local count = #usable
	if signature ~= bar.signature then
		bar.signature = signature
		for k = 1, count + 1 do
			local layer = Layer(bar, k)
			local range = checkers[usable[k]] and checkers[usable[k]].range
			local below = checkers[usable[k - 1]] and checkers[usable[k - 1]].range
			local text, melee = YardsText(below, k <= count and range or nil)
			layer.label:SetText(text)
			layer.melee = melee
			PaintText(layer.label, melee)
			layer.lamp:SetShown(melee and DB().meleeLamp ~= false)
		end
	end
	for k = 1, #bar.layers do
		local layer = bar.layers[k]
		if k > count + 1 then
			layer.gate:Hide()
		else
			layer.gate:Show()
			local own, lower = answers[usable[k]], answers[usable[k - 1]]
			if k > count then layer.label:SetAlpha(1)
			else layer.label:SetAlphaFromBoolean(own, 1, 0) end
			if not IsSecret(lower) and lower == nil then layer.gate:SetAlpha(1)
			else layer.gate:SetAlphaFromBoolean(lower, 0, 1) end
		end
	end
end

local function SetFacing(bar, value)
	if not DB().facing then
		bar.calm:SetAlpha(1); bar.alert:SetAlpha(0)
		return
	end
	if IsSecret(value) and bar.alert.SetAlphaFromBoolean then
		bar.alert:SetAlphaFromBoolean(value, 1, 0)
		bar.calm:SetAlphaFromBoolean(value, 0, 1)
	else
		local on = value == true
		bar.alert:SetAlpha(on and 1 or 0)
		bar.calm:SetAlpha(on and 0 or 1)
	end
end

-- Sensing ------------------------------------------------------------------------
-- Where the plate is across the screen (-1..1), and its centre in tape units.
local function Screen(bar)
	local plate = bar:GetParent()
	local x = plate and Plain(plate.GetCenter, plate)
	if type(x) ~= 'number' then return nil end
	local scale = Plain(plate.GetEffectiveScale, plate)
	local screen = UIParent:GetWidth() * UIParent:GetEffectiveScale()
	if not scale or screen <= 0 or not bar.scale then return nil end
	local physical = x * scale
	return min(max((physical - screen / 2) / (screen / 2), -1), 1), physical / bar.scale
end

local SAMPLE_RANGES = {5, 8, 10, 15, 20, 25, 30, 35, 40}
local function Sense(bar)
	if bar.isPreview then
		-- A unit wandering in and out of range across your view.
		local t = GetTime()
		local distance = 21 + 19 * sin(t * 0.55)
		local low, high
		for _, range in ipairs(SAMPLE_RANGES) do
			if range >= distance then high = high or range else low = range end
		end
		ShowPlain(bar, low, high)
		bar.speed = abs(sin(t * 0.55)) > 0.3 and 7 or 0
		SetFacing(bar, sin(t * 0.8) > 0.4)
		return
	end
	local unit = bar.unit
	if not unit then return end
	if DB().yards then
		ChecksFor(unit)
		if Ask(unit, bar.answers) then ShowSecret(bar, bar.answers) else ShowPlain(bar, Bracket(bar.answers)) end
	end
	-- The answer may be secret: it goes to SetFacing untested.
	local ok, targeting = pcall(UnitIsUnit, unit..'target', 'player')
	if not ok then targeting = false end
	SetFacing(bar, targeting)
	local speed = Plain(GetUnitSpeed, unit)
	bar.speed = type(speed) == 'number' and speed or 0
end

-- The driver: senses a few tapes about 15 times a second and draws every frame,
-- only while a tape is shown.
local driver = CreateFrame('Frame')
local Wake
do
	local sinceSense, lastFacing, unwrapped, cursor = 1, nil, 0, nil
	local SENSE_PER_TICK = 3

	local function Safe(func, ...)
		local ok, err = pcall(func, ...)
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end

	local function SenseSome()
		if preview and active[preview] and preview:IsVisible() then Safe(Sense, preview) end
		if cursor ~= nil and not active[cursor] then cursor = nil end
		local sensed, start = 0, cursor
		repeat
			cursor = next(active, cursor)
			if cursor and cursor ~= preview and cursor:IsVisible() then
				Safe(Sense, cursor)
				sensed = sensed + 1
			end
		until sensed >= SENSE_PER_TICK or cursor == start or (cursor == nil and start == nil)
	end

	local function Step(_, elapsed)
		if not next(active) then driver:SetScript('OnUpdate', nil) return end
		elapsed = min(elapsed, 0.1)
		sinceSense = sinceSense + elapsed
		if sinceSense >= 1 / 15 then
			sinceSense = 0
			SenseSome()
		end
		-- Your heading, unwrapped, so turning through north doesn't jump the tape.
		local facing = Plain(GetPlayerFacing)
		local heading
		if type(facing) == 'number' then
			if lastFacing then
				local delta = facing - lastFacing
				if delta > pi then delta = delta - 2 * pi elseif delta < -pi then delta = delta + 2 * pi end
				unwrapped = unwrapped + delta
			end
			lastFacing, heading = facing, unwrapped
		else
			lastFacing = nil
		end
		local now = GetTime()
		local ease = Reduced() and 1 or min(1, elapsed * 10)
		for bar in pairs(active) do
			if bar:IsVisible() then
				-- A plate's scale or width changes (targeting, distance scaling): re-measure.
				local scale, width = Plain(bar.GetEffectiveScale, bar), Plain(bar.GetWidth, bar)
				if (scale and (not bar.scale or abs(scale - bar.scale) > 0.0001))
					or (width and bar.rawWidth and bar.px and abs(width - bar.rawWidth) > bar.px) then
					Safe(Layout, bar)
				end
				if bar.isPreview then
					bar.goal = sin(now * 0.35) * 0.85
					bar.screenX = (bar.screenX or 0) + elapsed * 40 * sin(now * 0.3)
					bar.heading = nil
				else
					local bearing, screenX = Screen(bar)
					if bearing then bar.goal, bar.screenX = bearing, screenX end
					bar.heading = heading
				end
				bar.at = bar.at + (bar.goal - bar.at) * ease
				bar.wave = bar.wave + elapsed * min(bar.speed, 14) * 0.9
				if bar.fade < 1 then
					bar.fade = Reduced() and 1 or min(1, bar.fade + elapsed / 0.15)
					bar:SetAlpha(bar.fade)
				end
				Draw(bar)
			end
		end
	end

	function Wake()
		if next(active) then driver:SetScript('OnUpdate', Step) end
	end
end

-- Hosts --------------------------------------------------------------------------
-- Each adapter turns a nameplate unit token into the host's plate frame and the
-- health bar to sit on, and hooks the host's plate and target changes.
local Queue
local adapters = {}
do
	local function Hook(owner, method, fn)
		if type(owner) == 'table' and type(rawget(owner, method) or owner[method]) == 'function' then
			hooksecurefunc(owner, method, fn)
			return true
		end
	end

	adapters.elvui = {
		Module = function()
			local E = Hud.ElvUI()
			local NP = E and E.NamePlates
			return (NP and type(NP.Plates) == 'table') and NP or nil
		end,
		Plate = function(self, base)
			local NP = self.Module()
			local plate = NP and base and base.unitFrame
			if not plate or NP.Plates[plate] == nil or not plate.Health then return nil end
			if plate.widgetsOnly or plate.isGameObject or plate.frameType == 'PLAYER' then return nil end
			local ok, db = pcall(NP.PlateDB, NP, plate)
			if ok and type(db) == 'table' and db.nameOnly then return nil end
			return plate, plate.Health
		end,
		Hook = function(self)
			local NP = self.Module()
			if not NP or self.hooked then return NP ~= nil end
			self.hooked = true
			-- Creation, configuration and target changes; ElvUI's driver keeps its
			-- own copies of the add/remove callbacks, so those come from our events.
			for _, method in ipairs({'StylePlate', 'UpdatePlate', 'TargetChanged', 'SetupTarget', 'ConfigureAll'}) do
				Hook(NP, method, function() Queue() end)
			end
			return true
		end,
	}

	local function EllesmereNS()
		local EUI = _G.EllesmereUI
		local registry = type(EUI) == 'table' and rawget(EUI, '_ModuleNS')
		return type(registry) == 'table' and rawget(registry, 'EllesmereUINameplates') or nil
	end

	adapters.ellesmereui = {
		Module = function()
			local ns = EllesmereNS()
			return (ns and type(rawget(ns, 'plates')) == 'table') and ns or nil
		end,
		Plate = function(self, base, unit)
			local ns = self.Module()
			if not ns then return nil end
			local plate = rawget(ns, 'plates')[unit]
			local friendly = rawget(ns, 'friendlyPlates')
			if not plate and type(friendly) == 'table' then plate = friendly[unit] end
			if type(plate) ~= 'table' or not plate.health or (plate.nameplate and plate.nameplate ~= base) then return nil end
			return plate, plate.health
		end,
		Hook = function(self)
			local ns = self.Module()
			if not ns or self.hooked then return ns ~= nil end
			self.hooked = true
			-- Its plates mix this table in when first acquired; hooking it first
			-- reaches every plate, and our own events cover any made before.
			local internals = rawget(ns, '_npInternals')
			local frame = type(internals) == 'table' and rawget(internals, 'NameplateFrame')
			for _, method in ipairs({'SetUnit', 'ClearUnit', 'ApplyTarget'}) do
				Hook(frame, method, function() Queue() end)
			end
			for _, name in ipairs({'RefreshAllSettings'}) do Hook(ns, name, function() Queue() end) end
			return true
		end,
	}
end

local function ActiveAdapters()
	local list = {}
	for _, key in ipairs({'elvui', 'ellesmereui'}) do
		local adapter = adapters[key]
		if adapter:Module() then list[#list + 1] = adapter end
	end
	return list
end

-- Which plates carry a tape ------------------------------------------------------
local units = {} -- nameplate unit tokens seen
local function PlateFor(unit)
	if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
	local ok, base = pcall(C_NamePlate.GetNamePlateForUnit, unit)
	return ok and base or nil
end

local function Wants(base, unit)
	local db = DB()
	if not db.enable or not base then return false end
	if base == PlateFor('player') then return false end
	if base == PlateFor('target') then return true end
	if db.show == 'focus' and base == PlateFor('focus') then return true end
	if db.show == 'enemies' then return Plain(UnitCanAttack, 'player', unit) == true end
	return false
end

local function Detach(bar)
	active[bar] = nil
	bar.unit = nil
	bar:Hide()
end

local function Attach(plate, anchor, unit)
	local bar = bars[plate]
	if not bar then bar = Build(plate); bars[plate] = bar end
	local fresh = bar.unit ~= unit or not bar:IsShown()
	bar.unit = unit
	bar:Show()
	Place(bar, plate, anchor)
	if fresh then
		bar.speed, bar.text = 0, nil
		local bearing, screenX = Screen(bar)
		bar.goal, bar.screenX = bearing or 0, screenX
		bar.at = bar.goal
		Sense(bar)
		bar.fade = Reduced() and 1 or 0
		bar:SetAlpha(bar.fade)
	end
	active[bar] = true
	return bar
end

local function Rescan()
	local seen = {}
	if DB().enable then
		local hosts = ActiveAdapters()
		for unit in pairs(units) do
			local base = PlateFor(unit)
			if not base then
				units[unit] = nil
			elseif Wants(base, unit) then
				for _, adapter in ipairs(hosts) do
					local plate, anchor = adapter:Plate(base, unit)
					if plate then
						local ok, bar = pcall(Attach, plate, anchor, unit)
						if ok and bar then seen[bar] = true elseif not ok and geterrorhandler then geterrorhandler()(bar) end
						break
					end
				end
			end
		end
	end
	for bar in pairs(active) do
		if bar ~= preview and not seen[bar] then Detach(bar) end
	end
	Wake()
end

do
	local queued
	function Queue()
		if queued or not C_Timer then return end
		queued = true
		-- After the host's own handlers for the same event have run.
		C_Timer.After(0, function()
			queued = nil
			local ok, err = pcall(Rescan)
			if not ok and geterrorhandler then geterrorhandler()(err) end
		end)
	end
end

local function ScanTokens()
	for index = 1, 40 do
		local unit = 'nameplate'..index
		if PlateFor(unit) then units[unit] = true end
	end
end

-- Preview --------------------------------------------------------------------------
local function HidePreview()
	if not preview then return end
	active[preview] = nil
	preview:Hide()
	if preview.stand then preview.stand:Hide() end
end

local function ShowPreview()
	if not preview then
		preview = Build(UIParent)
		preview.isPreview = true
		preview:SetFrameStrata('HIGH')
		-- A plate-sized strip to sit on, in the host's colors.
		local stand = CreateFrame('Frame', nil, UIParent)
		stand:SetFrameStrata('HIGH')
		stand.fill = stand:CreateTexture(nil, 'BACKGROUND')
		stand.fill:SetTexture(WHITE)
		stand.fill:SetAllPoints()
		stand.health = stand:CreateTexture(nil, 'ARTWORK')
		stand.health:SetTexture(WHITE)
		stand.edges = Hud.Border(stand)
		preview.stand = stand
	end
	local stand = preview.stand
	stand:ClearAllPoints()
	stand:SetPoint('CENTER', UIParent, 'CENTER', 0, 160)
	stand:SetSize(150, 14)
	stand.fill:SetVertexColor(Hud.Color('backdrop'))
	stand.health:ClearAllPoints()
	stand.health:SetPoint('TOPLEFT'); stand.health:SetPoint('BOTTOMLEFT')
	stand.health:SetWidth(150 * 0.68)
	stand.health:SetVertexColor(0.78, 0.25, 0.25)
	Hud.TintAll(stand.edges, Hud.Color('border'))
	Hud.PlaceBorder(stand.edges, stand, Hud.Pixel(stand))
	stand:Show()
	preview:Show()
	Place(preview, UIParent, stand)
	preview:SetFrameStrata('HIGH')
	preview.speed, preview.at, preview.goal, preview.fade = 0, 0, 0, 1
	preview:SetAlpha(1)
	active[preview] = true
	Wake()
end

function JI:IsNavTapePreviewShown() return preview and active[preview] and true or false end

function JI:ToggleNavTapePreview()
	if JI:IsNavTapePreviewShown() then HidePreview() elseif not InCombatLockdown() then ShowPreview() end
end

-- Presets set the look in one go; every setting can still be changed after.
JI.NavTapePresets = {
	elvui = {ticks = 24, tickStyle = 'lines', tickMinor = 3, tickMajor = 6, tickWeight = 1, majorEvery = 5, lens = true,
		lensLift = 4, edgeFade = true, tapeWidth = 100, markerStyle = 'caret', markerSize = 3, background = 'backdrop',
		backdropAlpha = 0.6, yardsSize = 10, yardsOutline = true, yardsPosition = 'above', colors = 'host'},
	ellesmereui = {ticks = 30, tickStyle = 'lines', tickMinor = 2, tickMajor = 5, tickWeight = 1, majorEvery = 6, lens = true,
		lensLift = 3, edgeFade = true, tapeWidth = 90, markerStyle = 'line', markerSize = 2, background = 'baseline',
		yardsSize = 9, yardsOutline = false, yardsPosition = 'right', colors = 'host'},
	minimal = {ticks = 14, tickStyle = 'lines', tickMinor = 2, tickMajor = 4, tickWeight = 1, majorEvery = 7, lens = false,
		edgeFade = true, tapeWidth = 80, markerStyle = 'line', markerSize = 2, background = 'none', yardsSize = 9,
		yardsOutline = true, yardsPosition = 'above'},
	instrument = {ticks = 40, tickStyle = 'notches', tickMinor = 2, tickMajor = 5, tickWeight = 1, majorEvery = 5, lens = true,
		lensLift = 3, edgeFade = false, tapeWidth = 100, markerStyle = 'caret', markerSize = 3, background = 'baseline',
		yardsSize = 10, yardsOutline = true, yardsPosition = 'above'},
	bold = {ticks = 16, tickStyle = 'bars', tickMinor = 4, tickMajor = 7, tickWeight = 3, majorEvery = 4, lens = true,
		lensLift = 5, edgeFade = true, tapeWidth = 100, markerStyle = 'diamond', markerSize = 4, background = 'backdrop',
		backdropAlpha = 0.75, yardsSize = 12, yardsOutline = true, yardsPosition = 'above'},
}

function JI:ApplyNavTapePreset(key)
	local preset = JI.NavTapePresets[key]
	if not preset then return end
	local db = DB()
	db.preset = key
	for field, value in pairs(preset) do db[field] = value end
	JI:UpdateNavTape()
end

-- Lifecycle ------------------------------------------------------------------------
local events
function JI:UpdateNavTape()
	if not events then return end
	ReadColors()
	for _, bar in pairs(bars) do
		if bar:IsShown() then
			local ok, err = pcall(Layout, bar)
			if not ok and geterrorhandler then geterrorhandler()(err) end
		end
	end
	if not DB().enable then
		for bar in pairs(active) do if bar ~= preview then Detach(bar) end end
	end
	if preview and preview:IsShown() then ShowPreview() end
	for _, adapter in ipairs(ActiveAdapters()) do adapter:Hook() end
	Queue()
end

function JI:NavTapeHosts()
	local names = {}
	for _, key in ipairs({'elvui', 'ellesmereui'}) do
		if adapters[key]:Module() then names[#names + 1] = key == 'elvui' and 'ElvUI' or 'EllesmereUI' end
	end
	return names
end

function JI:SetupNavTape()
	if events then return end
	events = CreateFrame('Frame')
	BuildCheckers()
	for _, event in ipairs({'NAME_PLATE_UNIT_ADDED', 'NAME_PLATE_UNIT_REMOVED', 'PLAYER_TARGET_CHANGED', 'PLAYER_FOCUS_CHANGED',
		'PLAYER_ENTERING_WORLD', 'SPELLS_CHANGED', 'PLAYER_SPECIALIZATION_CHANGED', 'TRAIT_CONFIG_UPDATED',
		'PLAYER_REGEN_DISABLED', 'UI_SCALE_CHANGED'}) do
		pcall(events.RegisterEvent, events, event)
	end
	events:SetScript('OnEvent', function(_, event, unit)
		if event == 'NAME_PLATE_UNIT_ADDED' then
			if not IsSecret(unit) and type(unit) == 'string' then units[unit] = true end
		elseif event == 'NAME_PLATE_UNIT_REMOVED' then
			if not IsSecret(unit) and type(unit) == 'string' then units[unit] = nil end
		elseif event == 'PLAYER_REGEN_DISABLED' then
			HidePreview()
			return
		elseif event == 'PLAYER_ENTERING_WORLD' then
			ScanTokens()
			BuildCheckers()
			for _, adapter in ipairs(ActiveAdapters()) do adapter:Hook() end
		elseif event ~= 'PLAYER_TARGET_CHANGED' and event ~= 'PLAYER_FOCUS_CHANGED' and event ~= 'UI_SCALE_CHANGED' then
			BuildCheckers()
			for _, bar in pairs(bars) do bar.signature = nil end
		end
		Queue()
	end)
	for _, adapter in ipairs(ActiveAdapters()) do adapter:Hook() end
	ScanTokens()
	Queue()
end
