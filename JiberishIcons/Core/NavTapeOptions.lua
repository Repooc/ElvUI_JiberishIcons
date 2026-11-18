local JI = unpack(JiberishIcons)
local ACH = JI.Libs.ACH
local function DB() return JI.db.navTape end
local function Off() return not DB().enable end
local function NoYards() return Off() or not DB().yards end
local function NoMarker() return Off() or not DB().bearing end
local function NoLens() return NoMarker() or not DB().lens end
local function NotCustom() return DB().colors ~= 'custom' end

local function Get(info) return DB()[info[#info]] end
local function Set(info, value) DB()[info[#info]] = value; JI:UpdateNavTape() end

local root = ACH:Group('Nav tape', nil, 67, 'tab', Get, Set)
JI.Options.args.navTape = root
root.args.description = ACH:Description(function()
	local hosts = JI.NavTapeHosts and JI:NavTapeHosts() or {}
	local found = #hosts > 0 and ('Attached to '..table.concat(hosts, ' and ')..' nameplates.')
		or '|cffff6060Needs ElvUI or EllesmereUI nameplates.|r'
	return 'A row of hairline ticks on your target\'s nameplate: how far away it is, where it sits across your view, and whether it is targeting you. '..found
end, 0)
root.args.enable = ACH:Toggle('Enable nav tape', nil, 1)
root.args.preview = ACH:Execute(function() return JI:IsNavTapePreviewShown() and 'Hide preview' or 'Show preview' end,
	'A sample tape above the middle of your screen, with a unit wandering in and out of range. Entering combat hides it.',
	2, function() JI:ToggleNavTapePreview() end)
root.args.preset = ACH:Select('Preset', 'Sets ticks, marker, lens, backdrop and text at once; change any of them after.', 3,
	{elvui = 'ElvUI', ellesmereui = 'EllesmereUI', minimal = 'Minimal', instrument = 'Instrument', bold = 'Bold'},
	nil, nil, nil, function(_, value) JI:ApplyNavTapePreset(value) end, Off)

local general = ACH:Group('General', nil, 10)
root.args.general = general
general.args.show = ACH:Select('Show on', nil, 1, {target = 'Target', focus = 'Target and focus', enemies = 'Every enemy'},
	nil, nil, nil, nil, Off)
general.args.position = ACH:Select('Position', 'Above or below the plate\'s health bar.', 2, {above = 'Above health', below = 'Below health'},
	nil, nil, nil, nil, Off)
general.args.yOffset = ACH:Range('Vertical offset', 'Distance from the health bar, away from it. Raise it to clear names or auras.', 3,
	{min = -100, max = 100, step = 1}, nil, nil, nil, Off)
general.args.xOffset = ACH:Range('Horizontal offset', nil, 4, {min = -200, max = 200, step = 1}, nil, nil, nil, Off)
general.args.inset = ACH:Range('Inset', 'Pulls both ends in from the health bar\'s edges (negative widens it).', 5,
	{min = -20, max = 40, step = 1}, nil, nil, nil, Off)
general.args.level = ACH:Range('Frame level', 'Above the plate\'s own level; raise it to draw over auras.', 6,
	{min = 1, max = 50, step = 1}, nil, nil, nil, Off)
general.args.tape = ACH:Toggle('Tape motion', 'The ticks run past as the unit or your view moves, and ripple with the unit\'s speed.', 7,
	nil, nil, nil, nil, nil, Off)
general.args.reduceMotion = ACH:Toggle('Reduce motion', 'No easing, fades or ripples; the marker and text still update.', 8,
	nil, nil, nil, nil, nil, Off)

local distance = ACH:Group('Distance', nil, 20)
root.args.distance = distance
distance.args.yards = ACH:Toggle('Show distance', 'The distance by the ticks, or MELEE in melee reach.', 1, nil, nil, nil, nil, nil, Off)
distance.args.yardsStyle = ACH:Select('Shows', 'Bracket: "< 10 YD", "10-28 YD", "> 28 YD". Nearest: the nearest range it is within. Farthest: the farthest range it is beyond.',
	2, {bracket = 'Bracket (10-28)', single = 'Nearest', far = 'Farthest'}, nil, nil, nil, nil, NoYards)
distance.args.yardsPosition = ACH:Select('Place', nil, 3, {above = 'Above', below = 'Below', left = 'Left', right = 'Right'},
	nil, nil, nil, nil, NoYards)
distance.args.font = ACH:Select('Font', 'Host follows the ElvUI or EllesmereUI font.', 4, function()
	local values = {host = 'Host UI font'}
	local media = LibStub('LibSharedMedia-3.0', true)
	if media and media.HashTable then for name in pairs(media:HashTable('font')) do values[name] = name end end
	return values
end, nil, nil, nil, nil, NoYards)
distance.args.yardsSize = ACH:Range('Text size', nil, 5, {min = 6, max = 20, step = 1}, nil, nil, nil, NoYards)
distance.args.yardsOutline = ACH:Toggle('Outline', 'An outline around the digits, for bright ground.', 6, nil, nil, nil, nil, nil, NoYards)
distance.args.yardsSuffix = ACH:Toggle('YD suffix', 'Print "YD" after the number.', 7, nil, nil, nil, nil, nil, NoYards)
distance.args.meleeLamp = ACH:Toggle('Melee lamp', 'A small lamp beside MELEE.', 8, nil, nil, nil, nil, nil, NoYards)
distance.args.about = ACH:Description('Distance comes in steps, from whether your own spells reach the unit (one check per distinct range in your spellbook: harmful spells for enemies, helpful for friends, Auto Attack for melee) and, out of combat, the duel and follow distances. So it shows a bracket such as 10-28 YD, not exact yards. When the game keeps those answers secret in combat, the right bracket is still shown, straight from the answers.', 20)

local ticks = ACH:Group('Ticks', nil, 30)
root.args.ticks = ticks
ticks.args.tickStyle = ACH:Select('Style', nil, 1, {lines = 'Lines', dots = 'Dots', notches = 'Notches', bars = 'Bars'},
	nil, nil, nil, nil, Off)
ticks.args.ticks = ACH:Range('Count', 'How many ticks across the tape.', 2, {min = 8, max = 48, step = 1}, nil, nil, nil, Off)
ticks.args.tickMinor = ACH:Range('Minor height', 'In physical pixels.', 3, {min = 1, max = 12, step = 1}, nil, nil, nil, Off)
ticks.args.tickMajor = ACH:Range('Major height', 'In physical pixels.', 4, {min = 1, max = 16, step = 1}, nil, nil, nil, Off)
ticks.args.tickWeight = ACH:Range('Weight', 'Line width, or dot size, in physical pixels.', 5, {min = 1, max = 3, step = 1}, nil, nil, nil, Off)
ticks.args.majorEvery = ACH:Range('Major every', 'Every so many ticks is a major one.', 6, {min = 2, max = 12, step = 1}, nil, nil, nil, Off)
ticks.args.tapeWidth = ACH:Range('Tape width', 'Of the health bar.', 7, {min = 40, max = 100, step = 5}, nil, nil, nil, Off)
ticks.args.edgeFade = ACH:Toggle('Fade the ends', 'Ticks fade out toward both ends of the tape.', 8, nil, nil, nil, nil, nil, Off)
ticks.args.background = ACH:Select('Behind', 'Backdrop uses the host UI\'s backdrop and border colors.', 9,
	{none = 'Nothing', baseline = 'Baseline', backdrop = 'Backdrop'}, nil, nil, nil, nil, Off)
ticks.args.backdropAlpha = ACH:Range('Backdrop opacity', nil, 10, {min = 0, max = 1, step = 0.05, isPercent = true}, nil, nil, nil,
	function() return Off() or DB().background ~= 'backdrop' end)

local marker = ACH:Group('Marker', nil, 40)
root.args.marker = marker
marker.args.bearing = ACH:Toggle('Marker', 'A marker on the tape at where the unit is across your view.', 1, nil, nil, nil, nil, nil, Off)
marker.args.markerStyle = ACH:Select('Style', nil, 2, {caret = 'Caret', line = 'Line', dot = 'Dot', diamond = 'Diamond'},
	nil, nil, nil, nil, NoMarker)
marker.args.markerSize = ACH:Range('Size', nil, 3, {min = 2, max = 6, step = 1}, nil, nil, nil, NoMarker)
marker.args.facing = ACH:Toggle('Targeting you', 'The marker changes color while the unit is targeting you.', 4, nil, nil, nil, nil, nil, NoMarker)
marker.args.lens = ACH:Toggle('Lens', 'Ticks near the marker lift and light.', 5, nil, nil, nil, nil, nil, NoMarker)
marker.args.lensLift = ACH:Range('Lens lift', '0 lights the ticks without lifting them. In physical pixels.', 6,
	{min = 0, max = 10, step = 1}, nil, nil, nil, NoLens)
marker.args.about = ACH:Description('An enemy\'s facing and position cannot be read by any addon. The marker shows where the plate is across your screen, and the ticks move with it.', 20)

local palette = ACH:Group('Colors', nil, 50)
root.args.colors = palette
palette.args.colors = ACH:Select('Colors', 'Host follows ElvUI\'s value color or EllesmereUI\'s accent; Class tints the lens and marker with your class color; Custom uses the colors below.',
	1, {host = 'Host UI', class = 'Class', custom = 'Custom'}, nil, nil, nil, nil, Off)
local names = {
	{'tickColor', 'Ticks'}, {'majorColor', 'Major ticks'}, {'lensColor', 'Lens'}, {'markerColor', 'Marker'},
	{'alertColor', 'Targeting you'}, {'yardsColor', 'Distance'}, {'meleeColor', 'Melee'}, {'baseColor', 'Baseline'},
}
for index, entry in ipairs(names) do
	local field = entry[1]
	palette.args[field] = ACH:Color(entry[2], nil, 1 + index, nil, nil,
		function() return unpack(DB()[field]) end,
		function(_, r, g, b) DB()[field] = {r, g, b, 1}; JI:UpdateNavTape() end, Off, NotCustom)
end
