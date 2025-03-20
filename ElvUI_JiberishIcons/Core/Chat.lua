local JI = unpack(ElvUI_JiberishIcons)

local classInfo = JI.dataHelper.class

local function SetupCache(frame, event, message, sender, _, _, _, _, _, _, _, _, _, guid)
	if sender and guid and guid ~= '' then
		JI.GuidCache[guid] = true
		JI.AuthorCache[sender] = guid
	end
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

function JI:SetupChatCache()
	for _, event in pairs(FindURL_Events) do
		_G.ChatFrame_AddMessageEventFilter(event, SetupCache)
	end
end

local function AddMessage(frame, message, ...)
	local db = JI.db.chat

	if db and db.enable then
		message = message:gsub('(|Hplayer.-|h.-|h)', function(playerLink)
			local playerName, serverName = playerLink:match('|Hplayer:([^:]+)%-(.-):')
			if serverName then
				playerName = playerName .. '-' .. serverName
			end

			local guid = JI.AuthorCache[playerName]

			if guid then
				local _, englishClass = GetPlayerInfoByGUID(guid)
				local icon = classInfo[englishClass]

				local style = db.style or 'fabled'
				local mergedClassStyles = JI.mergedStylePacks.class
				local path = (mergedClassStyles.styles[style] and mergedClassStyles.styles[style].path) or mergedClassStyles.path

				local fullPath = format('%s%s', path, style)
				if not JI:IsValidTexturePath(fullPath) then
					style = 'fabled'
				end

				local iconString
				if icon and icon.texString then
					iconString = format('|T%s%s:0:0:0:0:1024:1024:%s|t', path, style, icon.texString)

					return iconString .. playerLink
				end
			end

			return playerLink
		end)
	end

	return JI.hooks[frame].AddMessage(frame, message, ...)
end

function JI:ToggleChat()
	JI:SetupChat()
    local db = JI.db.chat
	if db.enable then
		JI:RegisterEvent('UPDATE_CHAT_WINDOWS', JI.SetupChat)
		JI:RegisterEvent('UPDATE_FLOATING_CHAT_WINDOWS', JI.SetupChat)
	else
		JI:UnregisterEvent('UPDATE_CHAT_WINDOWS', JI.SetupChat)
		JI:UnregisterEvent('UPDATE_FLOATING_CHAT_WINDOWS', JI.SetupChat)
	end
end

local ignoreChats = { [2] = true }
function JI:SetupChat()
	local db = JI.db.chat
	for _, frameName in ipairs(_G.CHAT_FRAMES) do
		local frame = _G[frameName]
		local id = frame:GetID()

		local allowHooks = db.enable and not ignoreChats[id]
		if allowHooks and not JI:IsHooked(frame, 'AddMessage') then
			JI:RawHook(frame, 'AddMessage', AddMessage, true)
		elseif JI:IsHooked(frame, 'AddMessage') then
			JI:Unhook(frame, 'AddMessage')
		end
	end
end
