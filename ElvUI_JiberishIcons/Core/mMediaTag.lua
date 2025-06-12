local JI, L = unpack(ElvUI_JiberishIcons)
local path, isCustom

function JI:Setup_mMediaTag()
	if not JI:IsAddOnEnabled('ElvUI_mMediaTag') then return end
	local mergedClassStyles = JI.mergedStylePacks.class

	for iconStyle, data in next, mergedClassStyles.styles do
		JI:Print('Attempting to add '..data.name..' to mMediaTag.')
		local path = (mergedClassStyles.styles[iconStyle] and mergedClassStyles.styles[iconStyle].path) or mergedClassStyles.path
		local fullPath = format('%s%s', path, iconStyle)
		if JI:IsValidTexturePath(fullPath) then
			mMT:AddClassIcons(iconStyle, fullPath, 'default', data.name)
			JI:Print('Added '..data.name..' to mMediaTag with style key of '..iconStyle..'.\nTexture Path: '..fullPath)
		else
			JI:Print('Failed to add '..data.name..' to mMediaTag with style key of '..iconStyle..'.\nTexture Path: '..fullPath)
		end
	end
end
