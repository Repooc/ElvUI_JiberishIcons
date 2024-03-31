local JI = unpack(ElvUI_JiberishIcons)

local classIconPath, iconStyles = JI.classIconPath, JI.iconStyles

function JI:SetupDetails()
    if not JI:IsAddOnEnabled('Details') then return end

    for iconStyle, data in next, iconStyles do
        _G.Details:AddCustomIconSet(format('%s%s', classIconPath, iconStyle), format('%s (Class)', data.name), false)
    end
end
