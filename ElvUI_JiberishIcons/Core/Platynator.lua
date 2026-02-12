local JI = unpack(ElvUI_JiberishIcons)

-- function JI:Setup_Platynator()
-- 	if not JI:IsAddOnEnabled('Platynator') then return end
-- 	local mergedClassStyles = JI.mergedStylePacks.class
-- 	for iconStyle, data in next, mergedClassStyles.styles do
-- 		local path = (mergedClassStyles.styles[iconStyle] and mergedClassStyles.styles[iconStyle].path) or mergedClassStyles.path
-- 		local fullPath = format('%s%s', path, iconStyle)
-- 		if JI:IsValidTexturePath(fullPath) then
-- 			Platynator:AddClassIcons(iconStyle, fullPath, 'default', data.name)
-- 		else
-- 			JI:Print('Failed to add '..data.name..' to Platynator with style key of '..iconStyle..'.\nTexture Path: '..fullPath)
-- 		end
-- 	end
-- end
