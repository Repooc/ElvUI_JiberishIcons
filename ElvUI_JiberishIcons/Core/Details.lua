local JI = unpack(ElvUI_JiberishIcons)

function JI:SetupDetails()
    if not JI:IsAddOnEnabled('Details') then return end
    local mergedClassStyles = JI.mergedStylePacks.class

	for iconStyle, data in next, mergedClassStyles.styles do
		local path = (mergedClassStyles.styles[iconStyle] and mergedClassStyles.styles[iconStyle].path) or mergedClassStyles.path
		local fullPath = format('%s%s', path, iconStyle)
		if JI:IsValidTexturePath(fullPath) then
            _G.Details:AddCustomIconSet(fullPath, format('%s (Class)', data.name), false, fullPath, { 0.125, 0, 0.125, 0.125, 0.25, 0, 0.25, 0.125 }, {16, 16})
        end
    end
end
