local JI = unpack(JiberishIcons)
local registered = {}

function JI:SetupDetails()
	local details = _G.Details
	if not JI:IsAddOnEnabled('Details') or not details or type(details.AddCustomIconSet) ~= 'function' then return end

	for _, kind in ipairs({ 'class', 'spec' }) do
		local pack = JI.mergedStylePacks[kind]
		for style, data in pairs(pack and pack.styles or {}) do
			local isSpec = kind == 'spec'
			-- Details owns the bar coordinates (including alternate Retail Rogue
			-- cells). Only opt in spec packs with a compatible texture layout.
			local fileName = data.fileName or style
			if isSpec then fileName = data.detailsFileName end
			local path = fileName and (data.path or pack.path)..fileName
			if path and not registered[path] and JI:IsValidTexturePath(path) then
				local coords = isSpec and { 0, 0.125, 0, 0.125 }
					or { 0.125, 0, 0.125, 0.125, 0.25, 0, 0.25, 0.125 }
				local added = details:AddCustomIconSet(path, format('%s (%s)', data.name, isSpec and 'Spec' or 'Class'),
					isSpec, path, coords, {16, 16})
				if added ~= false then registered[path] = true end
			end
		end
	end
end
