local JI = unpack(ElvUI_JiberishIcons)

--* Most of the API is from ElvUI/Simpy to maintain backwards compatibility if ElvUI is disabled
local C_AddOns_GetAddOnEnableState = C_AddOns and C_AddOns.GetAddOnEnableState
local GetAddOnEnableState = GetAddOnEnableState -- eventually this will be on C_AddOns and args swap
local utf8len, utf8sub, modf = string.utf8len, string.utf8sub, math.modf
local pairs, gsub = pairs, gsub

function JI:IsAddOnEnabled(addon)
	if C_AddOns_GetAddOnEnableState then
		return C_AddOns_GetAddOnEnableState(addon, JI.myName) == 2
	else
		return GetAddOnEnableState(JI.myName, addon) == 2
	end
end

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
