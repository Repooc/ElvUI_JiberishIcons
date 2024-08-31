local JI = unpack(ElvUI_JiberishIcons)

local UnitClass, UnitIsPlayer = UnitClass, UnitIsPlayer
local classInfo = JI.icons.class
local cachedBlizzardPortraits, cachedBlizzardClassIcons = {}, {}
local INVERSE = {
	InverseAnchors = {
		BOTTOM = 'TOP',
		BOTTOMLEFT = 'TOPRIGHT',
		BOTTOMRIGHT = 'TOPLEFT',
		CENTER = 'CENTER',
		LEFT = 'RIGHT',
		RIGHT = 'LEFT',
		TOP = 'BOTTOM',
		TOPLEFT = 'BOTTOMRIGHT',
		TOPRIGHT = 'BOTTOMLEFT'
	}
}

local function UpdateIcon(frame)
	if not frame or not frame.classIcon then return end
	local unit = cachedBlizzardClassIcons[frame]
	local db = JI.db.blizzard[unit]

	if db then
		local _, class = UnitClass(frame.unit)
		local icon = classInfo.data[class]

		if icon and UnitIsPlayer(frame.unit) and not frame.unit ~= 'pet' then
			--* Update Icon Holder Frame
			frame.classIcon:SetSize(db.icon.size, db.icon.size)
			frame.classIcon:ClearAllPoints()
			frame.classIcon:SetPoint(INVERSE.InverseAnchors[db.icon.anchorPoint], frame, db.icon.anchorPoint, db.icon.xOffset, db.icon.yOffset)

			--* Update Icon Texture
			frame.classIcon.icon:SetTexture(format('%s%s', classInfo.path, db.icon.style))
			frame.classIcon.icon:SetTexCoord(unpack(icon.texCoords))

			frame.classIcon:SetShown(db.icon.enable)
		elseif frame.classIcon then
			frame.classIcon:Hide()
		end
	end
end

local function CreateIcon(frame)
	if frame.classIcon then return end

	frame.classIcon = CreateFrame('Frame', nil, frame)
	frame.classIcon:SetPoint('LEFT', frame, 'RIGHT', 0, 0)
	frame.classIcon:SetSize(32, 32)
	frame.classIcon:SetFrameLevel(700)

	--! Possible mask support in the furture
	-- frame.classIcon.background = frame.classIcon:CreateTexture(nil, 'ARTWORK', nil, 1)
	-- frame.classIcon.background:SetAllPoints(frame.classIcon)
	-- frame.classIcon.background:SetTexture([[Interface\Tooltips\UI-Tooltip-Background]])

	frame.classIcon.icon = frame.classIcon:CreateTexture(nil, 'ARTWORK', nil, 2)
	frame.classIcon.icon:SetAllPoints(frame.classIcon)

	--! Possible mask support in the furture
	-- frame.classIcon.mask = frame.classIcon:CreateMaskTexture()
	-- frame.classIcon.mask:SetAllPoints(frame.classIcon.background)
	-- frame.classIcon.mask:SetTexture([[Interface\CHARACTERFRAME\TempPortraitAlphaMask]], 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE')

	--! Possible mask support in the furture
	-- frame.classIcon.background:AddMaskTexture(frame.classIcon.mask)
	-- frame.classIcon.icon:AddMaskTexture(frame.classIcon.mask)
end

local function UpdatePortrait(frame)
	if not frame or not frame.classPortrait then return end
	local unit = cachedBlizzardPortraits[frame]
	local db = JI.db.blizzard[unit]

	if db then
		local _, class = UnitClass(frame.unit)
		local icon = classInfo.data[class]
		local showPortrait = icon and db.portrait.enable and UnitIsPlayer(frame.unit)

		--* Update Background Color
		local r, g, b, a = unpack(db.portrait.background.color)
		if db.portrait.background.colorOverride == 2 then
			r, g, b = GetClassColor(class)
		elseif db.portrait.background.colorOverride == 1 then
			r, g, b = GetClassColor(select(2, UnitClass('player')))
		end
		frame.classPortrait.background:SetColorTexture(r, g, b, a)

		--* Update Portrait Texture
		frame.classPortrait.portrait:SetTexture(format('%s%s', classInfo.path, db.portrait.style))
		if icon then frame.classPortrait.portrait:SetTexCoord(unpack(icon.texCoords)) end

		frame.classPortrait:SetShown(showPortrait)
		frame.classPortrait.background:SetShown(showPortrait and db.portrait.background.enable)
		frame.portrait:SetShown(not showPortrait)
	end
end

local function CreatePortrait(frame)
	if frame.classPortrait then return end

	frame.classPortrait = CreateFrame('Frame', nil, frame)
	frame.classPortrait:SetAllPoints(frame.portrait)

	frame.classPortrait.background = frame.classPortrait:CreateTexture(nil, 'BACKGROUND', nil, -5)
	frame.classPortrait.background:SetAllPoints(frame.classPortrait)
	frame.classPortrait.background:SetTexture([[Interface\Tooltips\UI-Tooltip-Background]])

	frame.classPortrait.portrait = frame.classPortrait:CreateTexture(nil, 'BACKGROUND', nil, -4)
	frame.classPortrait.portrait:SetAllPoints(frame.classPortrait)

	frame.classPortrait.mask = frame.classPortrait:CreateMaskTexture()
	frame.classPortrait.mask:SetAllPoints(frame.classPortrait.background)
	frame.classPortrait.mask:SetTexture([[Interface\CHARACTERFRAME\TempPortraitAlphaMask]], 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE')

	frame.classPortrait.background:AddMaskTexture(frame.classPortrait.mask)
	frame.classPortrait.portrait:AddMaskTexture(frame.classPortrait.mask)
end

local function SetupCache(frame, event, message, sender, _, _, _, _, _, _, _, _, _, guid)
	if sender and guid and guid ~= '' then
		JI.GuidCache[guid] = true
		JI.AuthorCache[sender] = guid
	end
end

local function StripColorCodes(text)
    return text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
end

local function AddMessage(frame, message, ...)
	message = message:gsub('(|Hplayer.-|h)(.-)|h', function(link, name)
		local playerName, serverName = link:match('|Hplayer:([^:]+)%-(.-):')
		if serverName then
			playerName = playerName .. '-' .. serverName
		end

		-- Remove color codes and extract player name with server
		local cleanName = StripColorCodes(name:match('%[(.-)%]'))
		if cleanName then
			cleanName = cleanName:gsub('%[', ''):gsub('%]', '')
		end
		local guid = JI.AuthorCache[playerName]

		if guid then
			local _, englishClass = GetPlayerInfoByGUID(guid)
			local icon = classInfo.data[englishClass]
			local db = JI.db.chat
			local iconString
			if icon and icon.texString then
				iconString = format('|T%s%s:0:0:0:0:1024:1024:%s|t', classInfo.path, db.style, icon.texString)

				return link .. iconString .. name
			end
		end
	end)

	return JI.hooks[frame].AddMessage(frame, message, ...)
end

local FindURL_Events = {
	'CHAT_MSG_WHISPER',
	'CHAT_MSG_WHISPER_INFORM',
	'CHAT_MSG_BN_WHISPER',
	'CHAT_MSG_BN_WHISPER_INFORM',
	'CHAT_MSG_BN_INLINE_TOAST_BROADCAST',
	'CHAT_MSG_GUILD_ACHIEVEMENT',
	'CHAT_MSG_GUILD',
	'CHAT_MSG_PARTY',
	'CHAT_MSG_PARTY_LEADER',
	'CHAT_MSG_RAID',
	'CHAT_MSG_RAID_LEADER',
	'CHAT_MSG_RAID_WARNING',
	'CHAT_MSG_INSTANCE_CHAT',
	'CHAT_MSG_INSTANCE_CHAT_LEADER',
	'CHAT_MSG_CHANNEL',
	'CHAT_MSG_SAY',
	'CHAT_MSG_YELL',
	'CHAT_MSG_EMOTE',
	'CHAT_MSG_AFK',
	'CHAT_MSG_DND',
	'CHAT_MSG_COMMUNITIES_CHANNEL',
}
function JI:SetupBlizzardChatEvents()
	JI:SetupBlizzardChat()
	JI:RegisterEvent('UPDATE_CHAT_WINDOWS', JI.SetupBlizzardChat)
	JI:RegisterEvent('UPDATE_FLOATING_CHAT_WINDOWS', JI.SetupBlizzardChat)
	for _, event in pairs(FindURL_Events) do
		ChatFrame_AddMessageEventFilter(event, SetupCache)
	end
end

local ignoreChats = { [2]='Log', [3]='Voice' }
function JI:SetupBlizzardChat()
	for _, frameName in ipairs(_G.CHAT_FRAMES) do
		local frame = _G[frameName]
		local id = frame:GetID()

		local allowHooks = not ignoreChats[id]
		if allowHooks and not JI:IsHooked(frame, 'AddMessage') then
			JI:RawHook(frame, 'AddMessage', AddMessage, true)
		end
	end

end

local singleUnits = { 'PlayerFrame', 'TargetFrame', 'TargetFrameToT', 'FocusFrame', 'FocusFrameToT' }
function JI:UpdateMedia(specific)
	if specific then
		for frame, unit in next, cachedBlizzardClassIcons do
			if unit == specific then
				UpdateIcon(frame)
				return
			end
		end
		for frame, unit in next, cachedBlizzardPortraits do
			if unit == specific then
				UpdatePortrait(frame)
				return
			end
		end
	end

	for _, frame in ipairs(singleUnits) do
		frame = _G[frame]
		UpdateIcon(frame)
		UpdatePortrait(frame)
	end

	for i = 1, 4 do
		local frame = _G.PartyFrame and _G.PartyFrame['MemberFrame'..i] or _G['PartyMemberFrame'..i]
		UpdateIcon(frame)
		UpdatePortrait(frame)
	end
end

--* Create both icons and portraits for 'SingleUnits' and 'Party'
function JI:SetupBlizzardFrames()
	--* Setup Single Units Icons and Portraits
	for _, frame in next, singleUnits do
		frame = _G[frame]
		if frame and frame.unit and frame.unit ~= '' then
			if not cachedBlizzardClassIcons[frame] then
				cachedBlizzardClassIcons[frame] = frame.unit
				CreateIcon(frame)
			end
			if not cachedBlizzardPortraits[frame] then
				cachedBlizzardPortraits[frame] = frame.unit
				CreatePortrait(frame)
			end
		end
	end

	--* Setup Party Icons and Portraits
	for i = 1, 4 do
		local frame = _G.PartyFrame and _G.PartyFrame['MemberFrame'..i] or _G['PartyMemberFrame'..i]
		if frame and frame.unit and frame.unit ~= '' then
			local unit = strmatch(frame.unit, 'party') and 'party'

			if not cachedBlizzardClassIcons[frame] then
				cachedBlizzardClassIcons[frame] = unit
				CreateIcon(frame)
			end
			if not cachedBlizzardPortraits[frame] then
				cachedBlizzardPortraits[frame] = unit
				CreatePortrait(frame)
			end
		end
	end
end

--* Update 'SingleUnits' and 'Party' (Icona and Portraits)
function JI:UnitFramePortrait_Update(frame, updated)
	if not frame then return end

	if type(frame) == 'string' and updated then
		if updated == 'icon' then
			for cachedFrame, unit in next, cachedBlizzardClassIcons do
				if frame == unit then
					UpdateIcon(cachedFrame)
				end
			end
		elseif updated == 'portrait' then
			for cachedFrame, unit in next, cachedBlizzardPortraits do
				if frame == unit then
					UpdatePortrait(cachedFrame)
				end
			end
		end
		return
	end

	if cachedBlizzardClassIcons[frame] then UpdateIcon(frame) end
	if cachedBlizzardPortraits[frame] then UpdatePortrait(frame) end
end
