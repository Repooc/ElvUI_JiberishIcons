local JI = unpack(ElvUI_JiberishIcons)

function JI:Setup_Eltruism()
	if not JI:IsAddOnEnabled('ElvUI_EltreumUI') then return end
	local mergedClassStyles = JI.mergedStylePacks.class

    for iconStyle, data in next, mergedClassStyles.styles do
		local path = (mergedClassStyles.styles[iconStyle] and mergedClassStyles.styles[iconStyle].path) or mergedClassStyles.path
		local fullPath = format('%s%s', path, iconStyle)
		if JI:IsValidTexturePath(fullPath) then
			ElvUI_EltreumUI:AddClassIcons(iconStyle, fullPath, 'default', data.name)
		else
			JI:Print('Failed to add '..data.name..' to Eltruism with style key of '..iconStyle..'.\nTexture Path: '..fullPath)
		end
	end
end

function JI:SetupEltruismIconPacks()
    if not JI:IsAddOnEnabled('ElvUI_EltreumUI') then return end
    if _G.ElvUI_EltreumUI and not _G.ElvUI_EltreumUI.AddDamageMeterIconPack then return end
    local mergedClassStyles = JI.mergedStylePacks.class

	for iconStyle, data in next, mergedClassStyles.styles do
		local path = (mergedClassStyles.styles[iconStyle] and mergedClassStyles.styles[iconStyle].path) or mergedClassStyles.path
		local fullPath = format('%s%s', path, iconStyle)
		if JI:IsValidTexturePath(fullPath) then
			_G.ElvUI_EltreumUI:AddDamageMeterIconPack(data.name, data.name, false, fullPath)
        end
    end
end
