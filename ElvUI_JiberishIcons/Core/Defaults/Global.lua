local JI, L, P, G = unpack(ElvUI_JiberishIcons)

G.customPacks = {
    class = {
        styles = {}
    },	
}

G.newStyleInfo = {
    class = {
        name = '',																-- Name of the style pack (string: required)
        path = [[Interface\AddOns\JiberishIcons_CustomStyles\Media\Custom\]],	-- Path to the style pack ( Interface\AddOns\JiberishIcons_CustomStyles\\Media\\Custom\\ ) (string: required)
        fileName = 'yourfilenamehere',											-- Required (string: required)
        artist = '',															-- Artist name (string: optional)
        site = '',																-- Artist website (string: optional)
    }
}
