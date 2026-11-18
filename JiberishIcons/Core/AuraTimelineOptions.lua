local JI = unpack(JiberishIcons)
local ACH = JI.Libs.ACH
local function DB() return JI.db.auraTimeline end
local function Off() return not DB().enable end
local function Locked() return Off() or InCombatLockdown() end
local function NotCustom() return DB().colors ~= 'custom' end

local function Get(info) return DB()[info[#info]] end
local function Set(info, value) DB()[info[#info]] = value; JI:UpdateAuraTimeline() end

local function Fonts()
	local values = {host = 'Host UI font'}
	local media = LibStub('LibSharedMedia-3.0', true)
	if media and media.HashTable then for name in pairs(media:HashTable('font')) do values[name] = name end end
	return values
end

local root = ACH:Group('Aura timeline', nil, 68, 'tab', Get, Set)
JI.Options.args.auraTimeline = root
root.args.description = ACH:Description('Your own buffs and ability cooldowns ride a line toward zero, each on a key with its time beside it. Only what has less time left than the line\'s length shows: a longer timer slides on from the far end once it drops onto the line, and auras that last until cancelled never show. Keys that would overlap stack into lanes. The game moves the keys itself, so this keeps working when it hides exact times in combat.', 0)
root.args.enable = ACH:Toggle('Enable aura timeline', nil, 1)
root.args.move = ACH:Execute(function()
	local host = JI.AuraTimelineMoverHost and JI:AuraTimelineMoverHost()
	if host == 'elvui' then return 'Toggle ElvUI movers' end
	if host == 'ellesmereui' then return 'EllesmereUI Unlock Mode' end
	return JI:IsAuraTimelinePreviewShown() and 'Hide preview' or 'Show preview'
end, 'Place the timeline with your UI\'s own movers. Sample keys count down while the movers are out.', 2,
	function() JI:ToggleAuraTimelineMovers() end, nil, nil, nil, nil, nil, Locked)
root.args.preview = ACH:Execute(function() return JI:IsAuraTimelinePreviewShown() and 'Hide preview' or 'Show preview' end,
	'Sample keys counting down, so you can see the skin without casting anything.', 3,
	function() JI:SetAuraTimelinePreview(not JI:IsAuraTimelinePreviewShown()) end, nil, nil, nil, nil, nil, Locked,
	function() return not JI:AuraTimelineMoverHost() end)
root.args.preset = ACH:Select('Preset', 'A complete look for ElvUI or EllesmereUI interfaces; change any part after.', 4,
	{elvui = 'ElvUI', ellesmereui = 'EllesmereUI', minimal = 'Minimal'}, nil, nil, nil,
	function(_, value) JI:ApplyAuraTimelinePreset(value) end, Off)

local tracked = ACH:Group('Tracked', nil, 10)
root.args.tracked = tracked
tracked.args.buffs = ACH:Select('Buffs', 'Yours: auras you cast. All: every timed buff on you.', 1, {mine = 'Yours', all = 'All', off = 'None'},
	nil, nil, nil, nil, Off)
tracked.args.longBuffs = ACH:Range('Longest buff', 'Optional: buffs that last longer than this are never tracked (0 keeps them all; they still show only once their time left is on the line).',
	2, {min = 0, max = 3600, step = 30}, nil, nil, nil, Off)
tracked.args.cooldowns = ACH:Toggle('Cooldowns', 'Spells on your action bars while they cool down.', 3, nil, nil, nil, nil, nil, Off)
tracked.args.minCooldown = ACH:Range('Shortest cooldown', 'Shorter cooldowns are left out when the game tells their length.', 4,
	{min = 0, max = 30, step = 1}, nil, nil, nil, Off, function() return not DB().cooldowns end)
tracked.args.debuffs = ACH:Toggle('Debuffs on you', 'Harmful auras, with a red edge.', 5, nil, nil, nil, nil, nil, Off)
tracked.args.maxEntries = ACH:Range('Most keys', nil, 6, {min = 4, max = 20, step = 1}, nil, nil, nil, Off)
tracked.args.blacklist = ACH:Input('Hidden spells', 'Spell IDs to leave off, separated by commas or spaces.', 7, nil, 'full', nil, nil, Off)

local lineGroup = ACH:Group('Line', nil, 20)
root.args.line = lineGroup
lineGroup.args.maxTime = ACH:Range('Length (seconds)', 'How many seconds the whole line stands for. Only times shorter than this show.', 1,
	{min = 10, max = 600, step = 5}, nil, nil, nil, Off)
lineGroup.args.length = ACH:Range('Size', 'The line\'s length on screen.', 2, {min = 80, max = 1200, step = 2}, nil, nil, nil, Off)
lineGroup.args.orientation = ACH:Select('Direction', nil, 3, {horizontal = 'Across', vertical = 'Up'}, nil, nil, nil, nil, Off)
lineGroup.args.reverse = ACH:Toggle('Zero at the far end', 'Keys run toward the right (or the top).', 4, nil, nil, nil, nil, nil, Off)
lineGroup.args.lineStyle = ACH:Select('Line style', nil, 5, {solid = 'Hairline', bar = 'Bordered bar', dashed = 'Dashed', none = 'None'},
	nil, nil, nil, nil, Off)
lineGroup.args.lineWeight = ACH:Range('Line weight', 'In physical pixels.', 6, {min = 1, max = 6, step = 1}, nil, nil, nil, Off)
lineGroup.args.lineShadow = ACH:Toggle('Shadow', 'A dark edge around the line for contrast against the world.', 7, nil, nil, nil, nil, nil, Off)
lineGroup.args.zeroCap = ACH:Select('Zero mark', nil, 8, {dot = 'Dot', bar = 'Bar', none = 'None'}, nil, nil, nil, nil, Off)
lineGroup.args.farCap = ACH:Toggle('Far end mark', nil, 9, nil, nil, nil, nil, nil, Off)
lineGroup.args.ticks = ACH:Toggle('Scale ticks', nil, 10, nil, nil, nil, nil, nil, Off)
lineGroup.args.labels = ACH:Toggle('Scale labels', '0, 5S, 30S, 1M and so on beside the ticks.', 11, nil, nil, nil, nil, nil, Off)
lineGroup.args.labelSize = ACH:Range('Label size', nil, 12, {min = 6, max = 16, step = 1}, nil, nil, nil,
	function() return Off() or not DB().labels end)

local keys = ACH:Group('Keys', nil, 30)
root.args.keys = keys
keys.args.keyStyle = ACH:Select('Key style', nil, 1, {square = 'Square', round = 'Round', borderless = 'Borderless'}, nil, nil, nil, nil, Off)
keys.args.iconSize = ACH:Range('Key size', nil, 2, {min = 12, max = 64, step = 1}, nil, nil, nil, Off)
keys.args.borderWeight = ACH:Range('Border', 'In physical pixels; 0 hides it.', 3, {min = 0, max = 4, step = 1}, nil, nil, nil,
	function() return Off() or DB().keyStyle == 'borderless' end)
keys.args.kindBorders = ACH:Toggle('Color cooldowns', 'Cooldown keys take the accent color on their border.', 4, nil, nil, nil, nil, nil,
	function() return Off() or DB().keyStyle == 'borderless' end)
keys.args.timeStyle = ACH:Select('Time', nil, 5, {text = 'Text under key', chip = 'Time chip', inside = 'On the icon', none = 'None'},
	nil, nil, nil, nil, Off)
keys.args.timeSize = ACH:Range('Time size', nil, 6, {min = 6, max = 20, step = 1}, nil, nil, nil,
	function() return Off() or DB().timeStyle == 'none' end)
keys.args.counts = ACH:Toggle('Stack counts', nil, 7, nil, nil, nil, nil, nil, Off)
keys.args.font = ACH:Select('Font', 'Host follows the ElvUI or EllesmereUI font.', 8, Fonts, nil, nil, nil, nil, Off)
keys.args.stems = ACH:Toggle('Stems', 'A hairline from each key to its point on the line.', 9, nil, nil, nil, nil, nil, Off)
keys.args.lanes = ACH:Range('Lanes', 'How many keys may stack at one spot.', 10, {min = 1, max = 6, step = 1}, nil, nil, nil, Off)
keys.args.stack = ACH:Select('Stack', 'Which side of the line the lanes grow on.', 11, {up = 'Up (or right)', down = 'Down (or left)', both = 'Both sides'},
	nil, nil, nil, nil, Off)
keys.args.spacing = ACH:Range('Lane spacing', nil, 12, {min = 0, max = 20, step = 1}, nil, nil, nil, Off)
keys.args.reduceMotion = ACH:Toggle('Reduce motion', 'Keys change lanes and appear without easing or fades.', 13, nil, nil, nil, nil, nil, Off)

local frame = ACH:Group('Frame', nil, 40)
root.args.frame = frame
frame.args.scale = ACH:Range('Scale', nil, 1, {min = 0.5, max = 2, step = 0.05, isPercent = true}, nil, nil, nil, Locked)
frame.args.strata = ACH:Select('Frame layer', nil, 2, {LOW = 'Low', MEDIUM = 'Medium', HIGH = 'High'}, nil, nil, nil, nil, Locked)
frame.args.positionHint = ACH:Description(function()
	return 'Placement uses '..JI.Hud.MoverHint()..'.'
end, 3)
for index, field in ipairs({'x', 'y'}) do
	frame.args[field] = ACH:Range(field == 'x' and 'Horizontal offset' or 'Vertical offset', 'From the bottom middle of the screen.',
		3 + index, {min = -4000, max = 4000, softMin = -1500, softMax = 1500, step = 1}, nil, nil,
		function(_, value) JI:SetAuraTimelinePosition(field == 'x' and value or DB().x, field == 'y' and value or DB().y) end,
		Locked, function() return JI:AuraTimelineMoverHost() ~= nil end)
end

local colors = ACH:Group('Colors', nil, 50)
root.args.colors = colors
colors.args.colors = ACH:Select('Colors', 'Host follows ElvUI\'s border, backdrop and value colors or EllesmereUI\'s accent; Class uses your class color for accents; Custom uses the colors below.',
	1, {host = 'Host UI', class = 'Class', custom = 'Custom'}, nil, nil, nil, nil, Off)
local fields = {
	{'lineColor', 'Line'}, {'tickColor', 'Ticks'}, {'labelColor', 'Labels'}, {'accentColor', 'Accent'},
	{'borderColor', 'Key border'}, {'harmColor', 'Debuff border'}, {'cooldownColor', 'Cooldown border'},
	{'textColor', 'Text'}, {'chipColor', 'Key and chip backdrop'},
}
for index, entry in ipairs(fields) do
	local field = entry[1]
	colors.args[field] = ACH:Color(entry[2], nil, 1 + index, true, nil,
		function() return unpack(DB()[field]) end,
		function(_, r, g, b, a) DB()[field] = {r, g, b, a or 1}; JI:UpdateAuraTimeline() end, Off, NotCustom)
end
