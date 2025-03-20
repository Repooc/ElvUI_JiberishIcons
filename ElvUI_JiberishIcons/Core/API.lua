local JI = unpack(ElvUI_JiberishIcons)

--* Most of the API is from ElvUI/Simpy to maintain backwards compatibility if ElvUI is disabled
local utf8len, utf8sub, modf = string.utf8len, string.utf8sub, math.modf
local pairs, gsub = pairs, gsub

local UF = JI:IsAddOnEnabled('ElvUI') and ElvUI[1].UnitFrames or ''

-- Text Gradient by Simpy
function JI:TextGradient(text, ...)
	local msg, total = '', utf8len(text)
	local idx, num = 0, select('#', ...) / 3

	for i = 1, total do
		local x = utf8sub(text, i, i)
		if strmatch(x, '%s') then
			msg = msg .. x
			idx = idx + 1
		else
			local segment, relperc = modf((idx/total)*num)
			local r1, g1, b1, r2, g2, b2 = select((segment*3)+1, ...)

			if not r2 then
				msg = msg .. JI:RGBToHex(r1, g1, b1, nil, x..'|r')
			else
				msg = msg .. JI:RGBToHex(r1+(r2-r1)*relperc, g1+(g2-g1)*relperc, b1+(b2-b1)*relperc, nil, x..'|r')
				idx = idx + 1
			end
		end
	end

	return msg
end

function JI:RGBToHex(r, g, b, header, ending)
	r = r <= 1 and r >= 0 and r or 1
	g = g <= 1 and g >= 0 and g or 1
	b = b <= 1 and b >= 0 and b or 1
	return format('%s%02x%02x%02x%s', header or '|cff', r*255, g*255, b*255, ending or '')
end

do
	local d = {'|[TA].-|[ta]','|c[fF][fF]%x%x%x%x%x%x','|r','^%s+','%s+$'}
	function JI:StripString(s, ignoreTextures)
		for i = ignoreTextures and 2 or 1, #d do s = gsub(s,d[i],'') end
		return s
	end
end

function JI:CopyTable(current, default, merge)
	if type(current) ~= 'table' then
		current = {}
	end

	if type(default) == 'table' then
		for option, value in pairs(default) do
			local isTable = type(value) == 'table'
			if not merge or (isTable or current[option] == nil) then
				current[option] = (isTable and JI:CopyTable(current[option], value, merge)) or value
			end
		end
	end

	return current
end

JI.dataHelper = {
	class = {
		WARRIOR	= {
			texString = '0:128:0:128',
			texStringLarge = '0:500:0:500',
			texCoords = { 0, 0, 0, 0.125, 0.125, 0, 0.125, 0.125 },
		},
		MAGE = {
			texString = '128:256:0:128',
			texStringLarge = '500:1000:0:500',
			texCoords = { 0.125, 0, 0.125, 0.125, 0.25, 0, 0.25, 0.125 },
		},
		ROGUE = {
			texString = '256:384:0:128',
			texStringLarge = '1000:1500:0:500',
			texCoords = { 0.25, 0, 0.25, 0.125, 0.375, 0, 0.375, 0.125 },
		},
		DRUID = {
			texString = '384:512:0:128',
			texStringLarge = '1500:2000:0:500',
			texCoords = { 0.375, 0, 0.375, 0.125, 0.5, 0, 0.5, 0.125 },
		},
		EVOKER = {
			texString = '512:640:0:128',
			texStringLarge = '2000:2500:0:500',
			texCoords = { 0.5, 0, 0.5, 0.125, 0.625, 0, 0.625, 0.125 },
		},
		HUNTER = {
			texString = '0:128:128:256',
			texStringLarge = '0:500:500:1000',
			texCoords = { 0, 0.125, 0, 0.25, 0.125, 0.125, 0.125, 0.25 },
		},
		SHAMAN = {
			texString = '128:256:128:256',
			texStringLarge = '500:1000:500:1000',
			texCoords = { 0.125, 0.125, 0.125, 0.25, 0.25, 0.125, 0.25, 0.25 },
		},
		PRIEST = {
			texString = '256:384:128:256',
			texStringLarge = '1000:1500:500:1000',
			texCoords = { 0.25, 0.125, 0.25, 0.25, 0.375, 0.125, 0.375, 0.25 },
		},
		WARLOCK = {
			texString = '384:512:128:256',
			texStringLarge = '1500:2000:500:1000',
			texCoords = { 0.375, 0.125, 0.375, 0.25, 0.5, 0.125, 0.5, 0.25 },
		},
		PALADIN = {
			texString = '0:128:256:384',
			texStringLarge = '0:500:1000:1500',
			texCoords = { 0, 0.25, 0, 0.375, 0.125, 0.25, 0.125, 0.375 },
		},
		DEATHKNIGHT = {
			texString = '128:256:256:384',
			texStringLarge = '500:1000:1000:1500',
			texCoords = { 0.125, 0.25, 0.125, 0.375, 0.25, 0.25, 0.25, 0.375 },
		},
		MONK = {
			texString = '256:384:256:384',
			texStringLarge = '1000:1500:1000:1500',
			texCoords = { 0.25, 0.25, 0.25, 0.375, 0.375, 0.25, 0.375, 0.375 },
		},
		DEMONHUNTER = {
			texString = '384:512:256:384',
			texStringLarge = '1500:2000:1000:1500',
			texCoords = { 0.375, 0.25, 0.375, 0.375, 0.5, 0.25, 0.5, 0.375 },
		},
	},
	spec = {
		-- DEATHKNIGHT	= { 250, 251, 252 },
		-- DEMONHUNTER	= { 577, 581 },
		-- DRUID		= { 102, 103, 104, 105 },
		-- EVOKER		= { 1467, 1468, 1473},
		-- HUNTER		= { 253, 254, 255 },
		-- MAGE		= { 62, 63, 64 },
		-- MONK		= { 268, 270, 269 },
		-- PALADIN		= { 65, 66, 70 },
		-- PRIEST		= { 256, 257, 258 },
		-- ROGUE		= { 259, 260, 261 },
		-- SHAMAN		= { 262, 263, 264 },
		-- WARLOCK		= { 265, 266, 267 },
		-- WARRIOR		= { 71, 72, 73 },
		DEATHKNIGHT	= {
			specIDs = { [250] = true, [251] = true, [252] = true, },
		},
		DEMONHUNTER	= {
			specIDs = { [577] = true, [581] = true, },
		},
		DRUID = {
			specIDs = { [102] = true, [103] = true, [104] = true, [105] = true, },
		},
		EVOKER		= {
			specIDs = { [1467] = true, [1468] = true, [1473] = true, },
		},
		HUNTER		= {
			specIDs = { [253] = true, [254] = true, [255] = true },
		},
		MAGE		= {
			specIDs = { [62] = true, [63] = true, [64] = true, },
		},
		MONK		= {
			specIDs = { [268] = true, [270] = true, [269] = true, },
		},
		PALADIN		= {
			specIDs = { [65] = true, [66] = true, [70] = true },
		},
		PRIEST		= {
			specIDs = { [256] = true, [257] = true, [258] = true },
		},
		ROGUE		= {
			specIDs = { [259] = true, [260] = true, [261] = true },
		},
		SHAMAN		= {
			specIDs = { [262] = true, [263] = true, [264] = true },
		},
		WARLOCK		= {
			specIDs = { [265] = true, [266] = true, [267] = true},
		},
		WARRIOR		= {
			specIDs = { [71] = true, [72] = true, [73] = true },
		},
	},
	elvuiUnitList = {
		player = {
			updateFunc = UF.CreateAndUpdateUF,
			groupName = 'individualUnits',
		},
		pet = {
			updateFunc = UF.CreateAndUpdateUF,
			groupName = 'individualUnits',
		},
		pettarget = {
			updateFunc = UF.CreateAndUpdateUF,
			groupName = 'individualUnits',
		},
		target = {
			updateFunc = UF.CreateAndUpdateUF,
			groupName = 'individualUnits',
		},
		targettarget = {
			updateFunc = UF.CreateAndUpdateUF,
			groupName = 'individualUnits',
		},
		targettargettarget = {
			updateFunc = UF.CreateAndUpdateUF,
			groupName = 'individualUnits',
		},
		focus = {
			updateFunc = UF.CreateAndUpdateUF,
			groupName = 'individualUnits',
		},
		focustarget = {
			updateFunc = UF.CreateAndUpdateUF,
			groupName = 'individualUnits',
		},
		party = {
			updateFunc = UF.CreateAndUpdateHeaderGroup,
			groupName = 'groupUnits',
		},
		raid1 = {
			updateFunc = UF.CreateAndUpdateHeaderGroup,
			groupName = 'groupUnits',
		},
		raid2 = {
			updateFunc = UF.CreateAndUpdateHeaderGroup,
			groupName = 'groupUnits',
		},
		raid3 = {
			updateFunc = UF.CreateAndUpdateHeaderGroup,
			groupName = 'groupUnits',
		},
		raidpet = {
			updateFunc = UF.CreateAndUpdateHeaderGroup,
			groupName = 'groupUnits',
		},
		boss = {
			updateFunc = UF.CreateAndUpdateUFGroup, --MAX_BOSS_FRAMES
			groupName = 'groupUnits',
		},
		arena = {
			updateFunc = UF.CreateAndUpdateUFGroup, --5
			groupName = 'groupUnits',
		},
	},
	sufUnitList = {'player', 'pet', 'pettarget', 'target', 'targettarget', 'targettargettarget', 'focus', 'focustarget', 'party', 'partypet', 'partytarget', 'partytargettarget', 'raid', 'raidpet', 'boss', 'bosstarget', 'maintank', 'maintanktarget', 'mainassist', 'mainassisttarget', 'arena', 'arenatarget', 'arenapet', 'battleground', 'battlegroundtarget', 'battlegroundpet', 'arenatargettarget', 'battlegroundtargettarget', 'maintanktargettarget', 'mainassisttargettarget', 'bosstargettarget'}
}
