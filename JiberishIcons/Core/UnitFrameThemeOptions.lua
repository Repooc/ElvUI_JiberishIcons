local JI = unpack(JiberishIcons)
local ACH = JI.Libs.ACH
function JI:OpenElvUIUnitFrameOptions(key)
    if InCombatLockdown() then return end
    local E = _G.ElvUI and _G.ElvUI[1]
    if not E or not E.ToggleOptions then return end
    local group = key == 'party' or key == 'boss' or key == 'arena' or key:match('^raid')
    if key == 'raid' then key = 'raid1' end
    E:ToggleOptions('unitframe,'..(group and 'groupUnits' or 'individualUnits')..','..key..',generalGroup')
end
local root = ACH:Group('Unit Frame Themes', nil, 67, 'tree', nil, nil, function() return InCombatLockdown() end)
JI.Options.args.unitFrameThemes = root
root.args.description = ACH:Description('Apply Bushido or Overwatch styling to your existing ElvUI or EllesmereUI unit frames. Set position, dimensions, auras, fonts, textures and health colors in your unit-frame addon. Configure gradients in Eltruism or your existing color addon. Theme settings follow your JiberishIcons profile. Changes are available out of combat.', 0)

for index, host in ipairs({'elvui', 'ellesmereui'}) do
	local title = host == 'elvui' and 'ElvUI' or 'EllesmereUI'
	local group = ACH:Group(title..' Unit Frames', nil, index, 'tree')
	root.args[host] = group
	local function Available()
		return host == 'elvui' and JI:IsAddOnEnabled('ElvUI')
			or host == 'ellesmereui' and (JI:IsAddOnEnabled('EllesmereUIUnitFrames') or JI:IsAddOnEnabled('EllesmereUIRaidFrames'))
	end
	group.args.description = ACH:Description(function()
		if not Available() then return 'Enable '..title..' unit frames to use this section.' end
		return 'Choose a frame category and select Bushido or Overwatch. Native restores the original appearance. Both themes use the existing clickable frames; click areas stay rectangular. Party and raid controls apply to the entire category.'
			..(host == 'ellesmereui' and ' Use the EllesmereUI frame style for individual frames; its Blizzard and Classic art styles retain their own silhouettes.' or '')
	end, 0)
	for order, unit in ipairs(JI.dataHelper.themeUnits) do
		if host == 'elvui' or not unit.elvuiOnly then
			local key = unit.key
			local function DB() return JI.db.unitFrameThemes[host][key] end
			local function CategoryAvailable()
				if host == 'elvui' then return JI:IsAddOnEnabled('ElvUI') end
				return JI:IsAddOnEnabled((key == 'party' or key == 'raid') and 'EllesmereUIRaidFrames' or 'EllesmereUIUnitFrames')
			end
			local function Disabled() return InCombatLockdown() or not CategoryAvailable() or (DB().theme ~= 'bushido' and DB().theme ~= 'overwatch') end
			local page = ACH:Group(unit.name, nil, order, nil,
				function(info) return DB()[info[#info]] end,
				function(info, value) DB()[info[#info]] = value; JI:UpdateUnitFrameThemes() end,
				function() return InCombatLockdown() or not CategoryAvailable() end)
			group.args[key] = page
			page.args.theme = ACH:Select('Theme', nil, 1, {native = 'Native', bushido = 'Bushido', overwatch = 'Overwatch'})
			page.args.shape = ACH:Select('Health silhouette', nil, 2,
				{native = 'Native shape / artwork only', diagonal = 'Forward diagonal', diagonalback = 'Backward diagonal', chamfer = 'Clipped corners'},
				nil, nil, nil, nil, Disabled)
			page.args.shapePower = ACH:Toggle('Shape power bar too', 'Uses the same silhouette on the existing power bar. Its dimensions, position and colors stay in '..title..'.',
				3, nil, nil, nil, nil, nil, Disabled)
			page.args.replaceBorder = ACH:Toggle('Replace rectangular border', 'Use the shaped outline in place of native and Eltruism rectangular borders and shadows. Eltruism background gradients keep their colors and follow the health shape. Highlights drawn through the same native border will also be hidden. Other indicators keep their normal behavior.',
				4, nil, nil, nil, nil, nil, Disabled)
			page.args.borderColor = ACH:Color('Outline color', nil, 5, true, nil,
				function() return unpack(DB().borderColor) end,
				function(_, r, g, b, a) DB().borderColor = {r, g, b, a}; JI:UpdateUnitFrameThemes() end, Disabled)
			page.args.divisions = ACH:Select('Health divisions', 'Visual guides over the continuous health bar. These do not round or change health values.', 6,
				{[0] = 'None', [5] = '5 sections', [10] = '10 sections', [20] = '20 sections'}, nil, nil, nil, nil, Disabled)
			page.args.divisionWidth = ACH:Range('Divider thickness', nil, 7, {min = 1, max = 6, step = 1}, nil, nil, nil, Disabled)
			page.args.divisionColor = ACH:Color('Divider color', nil, 8, true, nil,
				function() return unpack(DB().divisionColor) end,
				function(_, r, g, b, a) DB().divisionColor = {r, g, b, a}; JI:UpdateUnitFrameThemes() end, Disabled)
			page.args.segments = ACH:Select('Overwatch health segments', 'Equal health intervals: 5 bars = 20% each, 10 bars = 10% each, 20 bars = 5% each. Partial health fills smoothly within a cell. Colors, text and fonts stay in your unit-frame addon.', 9, {[5] = '5 bars — 20% each', [10] = '10 bars — 10% each', [20] = '20 bars — 5% each'}, nil, nil, nil, nil, function() return Disabled() or DB().theme ~= 'overwatch' end)
            local function OverwatchOnly() return Disabled() or DB().theme ~= 'overwatch' end
            page.args.reverseSegments = ACH:Toggle('Reverse segment slant', 'Mirror the segment shapes. Health fill direction remains controlled by your unit-frame addon.', 9.1, nil, nil, nil, nil, nil, OverwatchOnly)
            page.args.segmentSpacing = ACH:Range('Cell spacing', 'Six levels from tight to widely separated. The gap scales with each health interval.', 9.2, {min = 1, max = 6, step = 1}, nil,
                function() local db = DB(); return db.segmentSpacing > 0 and db.segmentSpacing or (db.segmentGap == 'narrow' and 1 or db.segmentGap == 'wide' and 5 or 2) end,
                function(_, value) DB().segmentSpacing = value; JI:UpdateUnitFrameThemes() end, OverwatchOnly)
            page.args.segmentBorderOpacity = ACH:Range('Cell outline opacity', 'Soften cell edges without changing health colors or gradients.', 9.24, {min = 0, max = 1, step = .05}, nil, nil, nil, OverwatchOnly)
            page.args.segmentBorderWidth = ACH:Range('Cell outline thickness', 'Half-pixel steps at 40px bar height; scales with the native frame height. Enable Outline each cell to show it.', 9.23, {min = .5, max = 3, step = .5}, nil, nil, nil, OverwatchOnly)
            page.args.segmentStyle = ACH:Select('Cell shape', nil, 9.21, {angled = 'Angled tiles', rounded = 'Rounded tiles'}, nil, nil, nil, nil, OverwatchOnly)
            page.args.segmentOutline = ACH:Toggle('Outline each cell', 'Disable for a cleaner fill, especially on short or narrow frames.', 9.22, nil, nil, nil, nil, nil, OverwatchOnly)
            page.args.sizing = ACH:Description('Frame width and height set the overall bar size. Health colors, gradients, information, text and fonts come from your existing unit-frame settings. This theme changes only the silhouette, gaps and outline.', 9.3)
            if host == 'elvui' then
                page.args.hostSettings = ACH:Execute('Open ElvUI size / text settings', 'Edit this category in ElvUI. Changes to width and height automatically resize the themed segments.', 9.4, function() JI:OpenElvUIUnitFrameOptions(key) end)
                if key == 'raid' then
                    page.args.raid2Settings = ACH:Execute('Open ElvUI Raid 2 settings', nil, 9.5, function() JI:OpenElvUIUnitFrameOptions('raid2') end)
                    page.args.raid3Settings = ACH:Execute('Open ElvUI Raid 3 settings', nil, 9.6, function() JI:OpenElvUIUnitFrameOptions('raid3') end)
                end
            end
			local cap = ACH:Group('Bushido artwork', nil, 10, nil,
				function(info) return DB().cap[info[#info]] end,
				function(info, value) DB().cap[info[#info]] = value; JI:UpdateUnitFrameThemes() end)
			cap.inline = true; page.args.cap = cap
			cap.hidden = function() return DB().theme == 'overwatch' end
			for _, field in ipairs({'shape', 'divisions', 'divisionWidth', 'divisionColor'}) do
				page.args[field].hidden = function() return DB().theme == 'overwatch' end
			end
			local function CapDisabled() return Disabled() or DB().theme ~= 'bushido' or not DB().cap.enable end
			cap.args.enable = ACH:Toggle('Show Bushido end cap', nil, 1, nil, nil, nil, nil, nil, Disabled)
			cap.args.side = ACH:Select('Attach to', nil, 2, {LEFT = 'Left', RIGHT = 'Right'}, nil, nil, nil, nil, CapDisabled)
			cap.args.mirror = ACH:Toggle('Flip artwork', nil, 3, nil, nil, nil, nil, nil, CapDisabled)
			cap.args.scale = ACH:Range('Height relative to health bar', nil, 4, {min = .5, max = 4, step = .05, isPercent = true}, nil, nil, nil, CapDisabled)
			cap.args.width = ACH:Range('Artwork width', nil, 5, {min = .5, max = 2, step = .05, isPercent = true}, nil, nil, nil, CapDisabled)
			cap.args.x = ACH:Range('Horizontal offset', nil, 6, {min = -200, max = 200, step = 1}, nil, nil, nil, CapDisabled)
			cap.args.y = ACH:Range('Vertical offset', nil, 7, {min = -200, max = 200, step = 1}, nil, nil, nil, CapDisabled)
			cap.args.colorMode = ACH:Select('Artwork tint', nil, 8, {class = "Displayed unit's class", custom = 'Custom color'},
				nil, nil, nil, nil, CapDisabled)
			cap.args.color = ACH:Color('Custom / fallback color and opacity', 'Used for NPCs and unavailable class information. Opacity applies in either tint mode.', 9, true, nil,
				function() return unpack(DB().cap.color) end,
				function(_, r, g, b, a) DB().cap.color = {r, g, b, a}; JI:UpdateUnitFrameThemes() end, CapDisabled)
			if JI.individualLayoutUnits[key] then
				local source, reversed, copySize, message = key == 'player' and 'target' or 'player', false, false, ''
				local copy = ACH:Group('Copy an individual frame layout', nil, 20)
				copy.inline = true; page.args.copyLayout = copy
				copy.args.description = ACH:Description('Copy this addon’s theme, artwork size/offsets, unit icon settings, portrait size, model fit, colors and placement relative to the unit. The destination unit frame keeps its screen position. Party, raid and boss layouts are configured separately. Portraits are shared between theme hosts.', 0)
				copy.args.source = ACH:Select('Copy from', nil, 1, function()
					local values = {}; for id, name in pairs(JI.individualLayoutUnits) do if id ~= key then values[id] = name end end; return values
				end, nil, nil, function() return source end, function(_, v) source = v end)
				copy.args.reverse = ACH:Toggle('Reverse when copying', 'Swap portrait and end-cap sides, mirror the artwork and silhouette, and reverse horizontal offsets and model facing.', 2, nil, nil, nil,
					function() return reversed end, function(_, v) reversed = v end)
				if host == 'elvui' then
					copy.args.size = ACH:Toggle('Also copy ElvUI width / height', 'Copies only native frame width and height. ElvUI keeps control of its colors, texts, auras and screen position. These native settings are shared using ElvUI’s own profile export.', 3, nil, nil, nil,
						function() return copySize end, function(_, v) copySize = v end)
				end
				copy.args.apply = ACH:Execute(function() return 'Copy '..JI.individualLayoutUnits[source]..' to '..unit.name end, nil, 4,
					function() local ok; ok, message = JI:CopyIndividualLayout(host, source, key, reversed, copySize) end)
				copy.args.flip = ACH:Execute('Reverse this layout', 'Mirror the current portrait and artwork arrangement in place.', 5,
					function() local ok; ok, message = JI:ReverseIndividualLayout(host, key) end)
				copy.args.status = ACH:Description(function() return message or '' end, 6)
			end
		end
	end
	group.args.restore = ACH:Execute('Restore all '..title..' frames', 'Turn off unit-frame themes for every '..title..' category.', 100,
		function()
			for _, db in pairs(JI.db.unitFrameThemes[host]) do db.theme = 'native' end
			JI:UpdateUnitFrameThemes()
		end)
end
