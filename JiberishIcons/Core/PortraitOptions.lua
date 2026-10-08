local JI = unpack(JiberishIcons)
local ACH = JI.Libs.ACH
local points = {CENTER = 'Center', TOP = 'Top', BOTTOM = 'Bottom', LEFT = 'Left', RIGHT = 'Right',
	TOPLEFT = 'Top left', TOPRIGHT = 'Top right', BOTTOMLEFT = 'Bottom left', BOTTOMRIGHT = 'Bottom right'}

local function Packs()
	local values = {}
	for _, kind in ipairs({'class', 'spec', 'race'}) do
		for key, data in pairs(JI.mergedStylePacks[kind].styles) do
			values[key] = data.name..(kind == 'spec' and ' (Spec)' or '')
		end
	end
	return values
end

local root = ACH:Group('Portraits', nil, 65, 'tree', nil, nil, function() return InCombatLockdown() end)
JI.Options.args.portraits = root
root.args.description = ACH:Description('Add movable portraits for your units. Choose an icon pack or a 2D character portrait, then place it on the screen or attach it to a unit frame. Locked portraits let mouse clicks pass through. Layout controls are available out of combat.', 0)
root.args.move = ACH:Execute(function() return JI:ArePortraitsUnlocked() and 'Lock portraits' or 'Unlock and preview' end,
	'Enable the portraits you want first. Drag each portrait to place it anywhere on screen. Missing units use your character for preview. Dragging switches an attached portrait to screen placement. Portraits lock automatically in combat.',
	1, function() JI:TogglePortraitMovers() end)

local groups = {}
for i, key in ipairs({'party', 'boss', 'additional'}) do
	local group = ACH:Group(({party = 'Party', boss = 'Boss', additional = 'Anything / Additional'})[key], nil, 19 + i, 'tab')
	root.args[key] = group; groups[key] = group
	group.args.enableAll = ACH:Execute('Enable all', nil, 0, function()
		for _, definition in ipairs(JI.dataHelper.portraitUnits) do
			if definition.group == key then JI.db.portraits[definition.key].enable = true end
		end
		JI:UpdatePortraits()
	end)
	group.args.disableAll = ACH:Execute('Disable all', nil, 0.1, function()
		for _, definition in ipairs(JI.dataHelper.portraitUnits) do
			if definition.group == key then JI.db.portraits[definition.key].enable = false end
		end
		JI:UpdatePortraits()
	end)
end

for index, definition in ipairs(JI.dataHelper.portraitUnits) do
	local key = definition.key
	local additional = definition.group == 'additional'
	local function DB() return JI.db.portraits[key] end
	local function Disabled() return not DB().enable end
	local group = ACH:Group(definition.name, nil, index + 2, nil,
		function(info) return DB()[info[#info]] end,
		function(info, value) DB()[info[#info]] = value; JI:UpdatePortraits() end)
	local parent = definition.group and groups[definition.group] or root
	parent.args[key] = group
	group.args.enable = ACH:Toggle('Enable', nil, 1)
	local modes = {icon = 'Live unit icon', portrait = '2D character portrait'}
	if additional then modes.static = 'Choose any icon' end
	group.args.mode = ACH:Select('Portrait content', nil, 2, modes, nil, nil, nil, nil, Disabled)
	if additional then
		local sources = {}
		for _, unit in ipairs(JI.dataHelper.portraitUnits) do
			if unit.group ~= 'additional' then sources[unit.key] = unit.name end
		end
		group.args.sourceUnit = ACH:Select('Unit to follow', 'Used for live icons, character portraits and unit-frame attachment. A chosen fixed icon stays visible without this unit.', 2.1, sources, nil, nil, nil, nil, Disabled)
		local function StaticKind(kind)
			local _, _, current = JI:GetStyleInfo(DB().style)
			return DB().mode == 'static' and current == kind
		end
		for _, kind in ipairs({'class', 'spec', 'race'}) do
			local field = ({class = 'iconID', spec = 'specID', race = 'raceID'})[kind]
			group.args[field] = ACH:Select('Choose icon', nil, 3.1, function()
				local values = {}
				if kind == 'spec' then
					for id, info in pairs(JI.dataHelper.specialization) do values[id] = info.name end
				elseif kind == 'race' then
					for id, info in pairs(JI.dataHelper.race) do values[id] = info.name or id end
				else
					for id in pairs(JI.dataHelper.class) do
						values[id] = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[id]) or id
					end
				end
				return values
			end, nil, nil, nil, nil, Disabled, function() return not StaticKind(kind) end)
		end
	end
	group.args.style = ACH:Select('Icon pack', nil, 3, Packs, nil, nil, nil, nil,
		function() return Disabled() or DB().mode == 'portrait' end)
	group.args.fallback = ACH:Select('When an icon is unavailable', 'Pets and NPCs have no player class or specialization icon. This also applies while a specialization is loading.', 4,
		{portrait = 'Show 2D portrait', class = 'Show Fabled Class icon', hide = 'Leave the frame empty'}, nil, nil, nil, nil,
		function() return Disabled() or DB().mode ~= 'icon' end)
	group.args.shape = ACH:Select('Frame shape', nil, 5, {circle = 'Circle', droplet = 'Droplet right', dropletleft = 'Droplet left',
		circlethin = 'Thin circle', dropletthin = 'Thin droplet right', dropletleftthin = 'Thin droplet left', none = 'None — icon only'}, nil, nil, nil, nil, Disabled)
	group.args.size = ACH:Range('Size', nil, 6, {min = 24, max = 320, step = 1}, nil, nil, nil, Disabled)
	group.args.reverse = ACH:Toggle('Mirror artwork', 'Mirror the icon or character portrait inside the frame.', 7, nil, nil, nil, nil, nil, Disabled)
	group.args.iconScale = ACH:Range('Icon scale', 'Fit the artwork inside the portrait frame.', 8, {min = 0.4, max = 1.3, step = 0.01, isPercent = true}, nil, nil, nil,
		function() return Disabled() or DB().mode == 'portrait' end)
	group.args.contentX = ACH:Range('Icon horizontal offset', nil, 9, {min = -100, max = 100, step = 1}, nil, nil, nil,
		function() return Disabled() or DB().mode == 'portrait' end)
	group.args.contentY = ACH:Range('Icon vertical offset', nil, 10, {min = -100, max = 100, step = 1}, nil, nil, nil,
		function() return Disabled() or DB().mode == 'portrait' end)
	group.args.zoom = ACH:Range('2D portrait zoom', 'Also applies to fallback character portraits.', 11, {min = 0, max = 0.4, step = 0.01, isPercent = true}, nil, nil, nil, Disabled)
	group.args.classColor = ACH:Toggle('Class-colored border', 'Use the selected border color for pets, NPCs and unavailable classes.', 12, nil, nil, nil, nil, nil, Disabled)
	for offset, field in ipairs({'borderColor', 'backgroundColor'}) do
		group.args[field] = ACH:Color(field == 'borderColor' and 'Border color' or 'Background color', nil, 12 + offset, true, nil,
			function() return unpack(DB()[field]) end,
			function(_, r, g, b, a) DB()[field] = {r, g, b, a}; JI:UpdatePortraits() end, Disabled)
	end
	group.args.placement = ACH:Header('Placement', 20)
	group.args.anchor = ACH:Select('Attach to', 'Screen positions work with any UI. Attached portraits follow the selected frame and hide when it is hidden or unavailable.', 21,
		{screen = 'Screen', blizzard = 'Blizzard unit frame', elvui = 'ElvUI unit frame', custom = 'Named frame'}, nil, nil, nil,
		function(_, value)
			local db = DB(); db.anchor = value
			db.point, db.relativePoint = value == 'screen' and 'CENTER' or 'RIGHT', value == 'screen' and 'CENTER' or 'LEFT'
			db.x, db.y = value == 'screen' and definition.x or 0, value == 'screen' and definition.y or 0
			JI:UpdatePortraits()
		end, Disabled)
	group.args.frameName = ACH:Input('Frame name', 'For other UI addons, enter the global name of the frame to follow. The portrait remains independent of that frame’s own portrait settings.',
		22, nil, 'full', nil, nil, function() return Disabled() or DB().anchor ~= 'custom' end, nil,
		function(_, value) return value == '' or value:match('^[%a_][%w_]*$') ~= nil or 'Enter a frame name using letters, numbers and underscores.' end)
	group.args.point = ACH:Select('Portrait anchor point', nil, 23, points, nil, nil, nil, nil, Disabled)
	group.args.relativePoint = ACH:Select('Attach point', nil, 24, points, nil, nil, nil, nil, Disabled)
	group.args.x = ACH:Range('Horizontal position', nil, 25, {min = -10000, max = 10000, softMin = -1000, softMax = 1000, step = 1}, nil, nil, nil, Disabled)
	group.args.y = ACH:Range('Vertical position', nil, 26, {min = -10000, max = 10000, softMin = -1000, softMax = 1000, step = 1}, nil, nil, nil, Disabled)
	for _, field in ipairs({'point', 'relativePoint', 'x', 'y'}) do
		group.args[field].get = function() return DB()[field] end
		group.args[field].set = function(_, value) JI:SetPortraitPlacement(key, field, value) end
	end
	group.args.strata = ACH:Select('Layer', nil, 27, {BACKGROUND = 'Background', LOW = 'Low', MEDIUM = 'Medium', HIGH = 'High', DIALOG = 'Above other frames'}, nil, nil, nil, nil, Disabled)
	group.args.level = ACH:Range('Order within layer', nil, 28, {min = 1, max = 100, step = 1}, nil, nil, nil, Disabled)
	group.args.reset = ACH:Execute('Reset position', 'Return this portrait to its default screen position.', 29, function()
		local db = DB(); db.anchor, db.point, db.relativePoint = 'screen', 'CENTER', 'CENTER'
		db.x, db.y = definition.x, definition.y; JI:UpdatePortraits()
	end)
	if key == 'player' or key == 'target' then
		local function CastDB() return DB().cast end
		local function CircleDisabled() return Disabled() or (DB().shape ~= 'circle' and DB().shape ~= 'circlethin') end
		local function CastDisabled() return CircleDisabled() or not CastDB().enable end
		local cast = ACH:Group('Cast ring', nil, 35, nil,
			function(info) return CastDB()[info[#info]] end,
			function(info, value) CastDB()[info[#info]] = value; JI:UpdatePortraits() end)
		cast.inline = true; group.args.cast = cast
		cast.args.description = ACH:Description('For Circle and Thin circle portraits. The border fills during casts and drains during channels. Use Unlock and preview to adjust the ring and text. Each unit has its own settings.', 0)
		cast.args.enable = ACH:Toggle('Enable cast ring', nil, 1, nil, nil, nil, nil, nil, CircleDisabled)
		cast.args.spellIcon = ACH:Toggle('Show spell icon inside circle', 'Temporarily fill the portrait with the spell being cast. Your normal portrait returns when the cast ends.', 2, nil, nil, nil, nil, nil, CastDisabled)
		cast.args.showName = ACH:Toggle('Show spell name', nil, 3, nil, nil, nil, nil, nil, CastDisabled)
		cast.args.showTime = ACH:Toggle('Show remaining time', nil, 4, nil, nil, nil, nil, nil, CastDisabled)
		for order, field in ipairs({'color', 'channelColor', 'textColor'}) do
			cast.args[field] = ACH:Color(({color = 'Cast color', channelColor = 'Channel color', textColor = 'Text color'})[field], nil, 4 + order, true, nil,
				function() return unpack(CastDB()[field]) end,
				function(_, r, g, b, a) CastDB()[field] = {r, g, b, a}; JI:UpdatePortraits() end, CastDisabled)
		end
		cast.args.font = ACH:Select('Font', nil, 8, function()
			local values = {__default = 'Game default'}
			local media = LibStub('LibSharedMedia-3.0', true)
			if media and media.HashTable then
				for name in pairs(media:HashTable('font')) do values[name] = name end
			end
			return values
		end, nil, nil, nil, nil, CastDisabled)
		cast.args.fontSize = ACH:Range('Font size', nil, 9, {min = 8, max = 40, step = 1}, nil, nil, nil, CastDisabled)
		cast.args.outline = ACH:Select('Font outline', nil, 10, {[''] = 'None', OUTLINE = 'Outline', THICKOUTLINE = 'Thick outline'}, nil, nil, nil, nil, CastDisabled)
		cast.args.textWidth = ACH:Range('Text width', 'Maximum width before a long spell name is clipped.', 11, {min = 40, max = 400, step = 1}, nil, nil, nil, CastDisabled)
		for index, prefix in ipairs({'name', 'time'}) do
			local label, order = prefix == 'name' and 'Spell name' or 'Remaining time', 12 + (index - 1) * 4
			cast.args[prefix..'Header'] = ACH:Header(label, order)
			cast.args[prefix..'Point'] = ACH:Select('Anchor point', nil, order + 1, points, nil, nil, nil, nil, CastDisabled)
			cast.args[prefix..'X'] = ACH:Range('Horizontal offset', nil, order + 2, {min = -500, max = 500, step = 1}, nil, nil, nil, CastDisabled)
			cast.args[prefix..'Y'] = ACH:Range('Vertical offset', nil, order + 3, {min = -500, max = 500, step = 1}, nil, nil, nil, CastDisabled)
		end
	end
end
