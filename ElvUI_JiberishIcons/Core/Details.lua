local JI = unpack(ElvUI_JiberishIcons)

local classInfo = JI.icons.class

function JI:SetupDetails()
    if not JI:IsAddOnEnabled('Details') then return end

    for iconStyle, data in next, classInfo.styles do
        _G.Details:AddCustomIconSet(format('%s%s', classInfo.path, iconStyle), format('%s (Class)', data.name), false)
    end
end
