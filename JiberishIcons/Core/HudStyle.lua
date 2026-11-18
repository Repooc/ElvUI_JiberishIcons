-- Shared look for the nav tape and aura timeline: fonts, colors and pixel sizes
-- read from whichever host UI is loaded (ElvUI first, then EllesmereUI), so the
-- two features match the rest of the interface. Only host media and settings
-- are read; nothing is written to the host or to any Blizzard frame.
local JI = unpack(JiberishIcons)
local Hud = {}
JI.Hud = Hud

local WHITE = [[Interface\Buttons\WHITE8X8]]
local ROUND = [[Interface\CharacterFrame\TempPortraitAlphaMask]]
Hud.WHITE, Hud.ROUND = WHITE, ROUND

local function IsSecret(value) return issecretvalue and issecretvalue(value) or false end
Hud.IsSecret = IsSecret

-- A call whose answer is used only when it is plain.
function Hud.Plain(func, ...)
	if type(func) ~= 'function' then return nil end
	local ok, value = pcall(func, ...)
	if not ok or IsSecret(value) then return nil end
	return value
end

function Hud.Clamp(value, fallback, low, high)
	if IsSecret(value) or type(value) ~= 'number' or value ~= value then value = fallback end
	return math.max(low, math.min(high, value))
end

local function ElvUI()
	local engine = _G.ElvUI
	return type(engine) == 'table' and JI:IsAddOnEnabled('ElvUI') and engine[1] or nil
end
Hud.ElvUI = ElvUI

function Hud.Host()
	if ElvUI() then return 'elvui' end
	if type(_G.EllesmereUI) == 'table' then return 'ellesmereui' end
	return nil
end

local function Parts(color)
	if type(color) ~= 'table' then return nil end
	local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
	if type(r) == 'number' and type(g) == 'number' and type(b) == 'number' then return r, g, b end
end

local FALLBACK = {
	accent = {0.09, 0.51, 0.82}, border = {0, 0, 0}, backdrop = {0.06, 0.06, 0.07},
	text = {0.96, 0.96, 0.96}, dim = {0.55, 0.57, 0.6}, alert = {1, 0.24, 0.2},
}

-- One of accent, border, backdrop, text, dim or alert, as r, g, b.
function Hud.Color(role)
	local E = ElvUI()
	if E and E.media then
		local media = E.media
		local source = (role == 'accent' and media.rgbvaluecolor) or (role == 'border' and media.bordercolor)
			or (role == 'backdrop' and media.backdropcolor)
		local r, g, b = Parts(source)
		if r then return r, g, b end
	elseif type(_G.EllesmereUI) == 'table' then
		local EUI = _G.EllesmereUI
		local r, g, b
		if role == 'accent' then r, g, b = Parts(EUI.ELLESMERE_GREEN)
		elseif role == 'backdrop' then r, g, b = Parts(EUI.DARK_BG) end
		if r then return r, g, b end
	end
	local c = FALLBACK[role] or FALLBACK.text
	return c[1], c[2], c[3]
end

function Hud.ClassColor()
	local _, class = UnitClass('player')
	local colors = (_G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS)
	local c = not IsSecret(class) and class and colors and colors[class]
	if c then return c.r, c.g, c.b end
	return Hud.Color('accent')
end

-- The host's font, or a LibSharedMedia font chosen by name.
function Hud.Font(choice)
	if choice and choice ~= 'host' then
		local media = LibStub('LibSharedMedia-3.0', true)
		local path = media and media.Fetch and media:Fetch('font', choice, true)
		if path then return path end
	end
	local E = ElvUI()
	if E and E.media and E.media.normFont then return E.media.normFont end
	local EUI = _G.EllesmereUI
	if type(EUI) == 'table' and EUI.GetFontPath then
		local ok, path = pcall(EUI.GetFontPath, nil)
		if ok and type(path) == 'string' then return path end
	end
	return STANDARD_TEXT_FONT or [[Fonts\FRIZQT__.TTF]]
end

-- SetFont's own result is never read (it can be secret); an unusable path is
-- caught by asking the string for its font afterwards.
function Hud.SetFont(text, choice, size, outline)
	local ok = pcall(text.SetFont, text, Hud.Font(choice), size, outline or '')
	if not ok or not Hud.Plain(text.GetFont, text) then
		text:SetFont(STANDARD_TEXT_FONT or [[Fonts\FRIZQT__.TTF]], size, outline or '')
	end
	text:SetShadowColor(0, 0, 0, 1)
	text:SetShadowOffset(outline and outline ~= '' and 0 or 1, outline and outline ~= '' and 0 or -1)
end

-- One physical pixel in a frame's own units.
function Hud.Pixel(frame)
	local scale = frame and Hud.Plain(frame.GetEffectiveScale, frame) or 1
	local height = GetPhysicalScreenSize and select(2, GetPhysicalScreenSize())
	if type(height) ~= 'number' or height <= 0 or type(scale) ~= 'number' or scale <= 0 then return 1 end
	return 768 / height / scale
end

-- A 1 px border made of four textures around a region; returns the textures.
function Hud.Border(frame, owner, layer)
	local edges = {}
	for index = 1, 4 do
		local edge = frame:CreateTexture(nil, layer or 'BORDER', nil, 1)
		edge:SetTexture(WHITE)
		edges[index] = edge
	end
	Hud.PlaceBorder(edges, owner or frame, 1)
	return edges
end

function Hud.PlaceBorder(edges, owner, px, inset)
	inset = inset or 0
	local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
	for _, edge in ipairs(edges) do edge:ClearAllPoints() end
	top:SetPoint('TOPLEFT', owner, 'TOPLEFT', -inset, inset); top:SetPoint('TOPRIGHT', owner, 'TOPRIGHT', inset, inset); top:SetHeight(px)
	bottom:SetPoint('BOTTOMLEFT', owner, 'BOTTOMLEFT', -inset, -inset); bottom:SetPoint('BOTTOMRIGHT', owner, 'BOTTOMRIGHT', inset, -inset); bottom:SetHeight(px)
	left:SetPoint('TOPLEFT', owner, 'TOPLEFT', -inset, inset); left:SetPoint('BOTTOMLEFT', owner, 'BOTTOMLEFT', -inset, -inset); left:SetWidth(px)
	right:SetPoint('TOPRIGHT', owner, 'TOPRIGHT', inset, inset); right:SetPoint('BOTTOMRIGHT', owner, 'BOTTOMRIGHT', inset, -inset); right:SetWidth(px)
end

function Hud.TintAll(textures, r, g, b, a)
	for _, texture in ipairs(textures) do texture:SetVertexColor(r, g, b, a or 1) end
end

function Hud.ShowAll(textures, shown)
	for _, texture in ipairs(textures) do texture:SetShown(shown and true or false) end
end

-- A saved {r, g, b, a} color, or the fallback role.
function Hud.Saved(color, role)
	if type(color) == 'table' and type(color[1]) == 'number' then return color[1], color[2], color[3], color[4] or 1 end
	local r, g, b = Hud.Color(role)
	return r, g, b, 1
end

-- Text in the options for both hosts' movers.
function Hud.MoverHint()
	local host = Hud.Host()
	if host == 'elvui' then return 'ElvUI movers' end
	if host == 'ellesmereui' then return 'EllesmereUI Unlock Mode' end
	return 'the position sliders below'
end
