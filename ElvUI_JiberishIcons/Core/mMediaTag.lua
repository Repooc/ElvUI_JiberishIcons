local JI, L = unpack(ElvUI_JiberishIcons)
local path, isCustom

function JI:Setup_mMediaTag()
	if not JI:IsAddOnEnabled('ElvUI_mMediaTag') then return end
	local mergedStylePacks = JI.mergedStylePacks.class

	for iconStyle, data in next, mergedStylePacks.styles do
		local path = (mergedClassStyles.styles[iconStyle] and mergedClassStyles.styles[iconStyle].path) or mergedClassStyles.path
		local fullPath = format('%s%s', path, iconStyle)
		if JI:IsValidTexturePath(fullPath) then
			mMT:AddClassIcons(iconStyle, fullPath, 'default', data.name)
		end
	end
end
