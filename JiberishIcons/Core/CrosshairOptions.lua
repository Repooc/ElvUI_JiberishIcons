local JI = unpack(JiberishIcons)
local ACH = JI.Libs.ACH
local function DB() return JI.db.crosshair end
local function Disabled() return InCombatLockdown() or not DB().enable end
local function GCDDisabled() return Disabled() or not DB().gcd.enable end

local root = ACH:Group('Crosshair', nil, 66, nil,
	function(info) return DB()[info[#info]] end,
	function(info, value) DB()[info[#info]] = value; JI:UpdateCrosshair() end,
	function() return InCombatLockdown() end)
JI.Options.args.crosshair = root
root.args.description = ACH:Description('Place a crosshair over your character to keep track of your position. This is a fixed screen marker: use Unlock and preview to align it with your preferred camera view. Locked crosshairs let mouse clicks pass through. Placement and appearance can be changed out of combat.', 0)
root.args.enable = ACH:Toggle('Enable crosshair', nil, 1)
root.args.visibility = ACH:Select('Show crosshair', nil, 2,
	{combat = 'During combat', always = 'Always'}, nil, nil, nil, nil, Disabled)
root.args.move = ACH:Execute(function() return JI:IsCrosshairUnlocked() and 'Lock crosshair' or 'Unlock and preview' end,
	'Drag the crosshair anywhere on screen. When the GCD indicator is enabled, preview loops a sample fill. Entering combat automatically locks the crosshair.',
	3, function() JI:ToggleCrosshairMover() end, nil, nil, nil, nil, nil, Disabled)
root.args.style = ACH:Select('Crosshair style', nil, 4,
	{plus = 'Cross (+)', x = 'X', splitplus = 'Split cross (+)', splitx = 'Split X'}, nil, nil, nil, nil, Disabled)
root.args.weight = ACH:Select('Line weight', nil, 5, {thin = 'Thin', bold = 'Bold'}, nil, nil, nil, nil, Disabled)
root.args.size = ACH:Range('Crosshair size', nil, 6, {min = 8, max = 128, step = 1}, nil, nil, nil, Disabled)
root.args.color = ACH:Color('Crosshair color', nil, 7, true, nil,
	function() return unpack(DB().color) end,
	function(_, r, g, b, a) DB().color = {r, g, b, a}; JI:UpdateCrosshair() end, Disabled)
root.args.position = ACH:Header('Position', 10)
for index, field in ipairs({'x', 'y'}) do
	root.args[field] = ACH:Range(field == 'x' and 'Horizontal offset' or 'Vertical offset',
		'Offset from the center of your screen.', 10 + index, {min = -10000, max = 10000, softMin = -1000, softMax = 1000, step = 1}, nil, nil,
		function(_, value) JI:SetCrosshairPosition(field == 'x' and value or DB().x, field == 'y' and value or DB().y) end, Disabled)
end
root.args.reset = ACH:Execute('Reset position', 'Return to just below the center of the screen.', 13,
	function() JI:SetCrosshairPosition(0, -80) end, nil, nil, nil, nil, nil, Disabled)
root.args.strata = ACH:Select('Frame layer', nil, 14,
	{LOW = 'Low', MEDIUM = 'Medium', HIGH = 'High', DIALOG = 'Dialog'}, nil, nil, nil, nil, Disabled)

local gcd = ACH:Group('Global cooldown (GCD)', nil, 20, nil,
	function(info) return DB().gcd[info[#info]] end,
	function(info, value) DB().gcd[info[#info]] = value; JI:UpdateCrosshair() end)
gcd.inline = true; root.args.gcd = gcd
gcd.args.description = ACH:Description('An empty outline surrounds the crosshair. Its color fills during the global cooldown, then returns to empty when the GCD ends. Size and colors are independent of the crosshair. Set empty outline opacity to zero to hide the resting outline.', 0)
gcd.args.enable = ACH:Toggle('Enable GCD indicator', nil, 1, nil, nil, nil, nil, nil, Disabled)
gcd.args.shape = ACH:Select('Shape', nil, 2, {circle = 'Circle', diamond = 'Diamond', square = 'Square', triangle = 'Triangle'},
	nil, nil, nil, nil, GCDDisabled)
gcd.args.weight = ACH:Select('Outline weight', nil, 3, {thin = 'Thin', bold = 'Bold'}, nil, nil, nil, nil, GCDDisabled)
gcd.args.size = ACH:Range('Outline size', nil, 4, {min = 16, max = 256, step = 1}, nil, nil, nil, GCDDisabled)
for index, field in ipairs({'color', 'trackColor'}) do
	gcd.args[field] = ACH:Color(field == 'color' and 'GCD fill color' or 'Empty outline color', nil, 4 + index, true, nil,
		function() return unpack(DB().gcd[field]) end,
		function(_, r, g, b, a) DB().gcd[field] = {r, g, b, a}; JI:UpdateCrosshair() end, GCDDisabled)
end

for index, field in ipairs({'x', 'y'}) do
	gcd.args[field] = ACH:Range(field == 'x' and 'GCD horizontal offset' or 'GCD vertical offset',
		'Offset from the crosshair. Move the GCD independently; zero centers it on the crosshair.',
		7 + index, {min = -10000, max = 10000, softMin = -1000, softMax = 1000, step = 1}, nil, nil, nil, GCDDisabled)
end
gcd.args.reset = ACH:Execute('Center GCD on crosshair', nil, 10, function()
	DB().gcd.x, DB().gcd.y = 0, 0; JI:UpdateCrosshair()
end, nil, nil, nil, nil, nil, GCDDisabled)
