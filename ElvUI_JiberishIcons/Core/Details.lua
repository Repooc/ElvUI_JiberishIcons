local JI = unpack(ElvUI_JiberishIcons)
local path, isCustom

function JI:SetupDetails()
    if not JI:IsAddOnEnabled('Details') then return end
    local mergedStylePacks = JI.mergedStylePacks.class

	for iconStyle, data in next, mergedStylePacks.styles do
		local path = (mergedStylePacks.styles[iconStyle] and mergedStylePacks.styles[iconStyle].path) or mergedStylePacks.path
		local fullPath = format('%s%s', path, iconStyle)
		if JI:IsValidTexturePath(fullPath) then
            _G.Details:AddCustomIconSet(fullPath, format('%s (Class)', data.name), false)
        end
    end
end
