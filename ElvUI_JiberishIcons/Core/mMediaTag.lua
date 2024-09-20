local JI, L = unpack(ElvUI_JiberishIcons)
local classInfo = JI.icons.class

function JI:Setup_mMediaTag()
	if not JI:IsAddOnEnabled('ElvUI_mMediaTag') then return end
	local texCoords = {}
	for className, data in next, classInfo.data do
		texCoords[className] = data.texCoords
	end

	for iconStyle, data in next, classInfo.styles do
		local path = format('%s%s', classInfo.path, iconStyle)
		mMT:AddClassIcons(iconStyle, path, texCoords, data.name)
	end
end
