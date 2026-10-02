local JI = unpack(JiberishIcons)

-- A restricted row cannot identify a particular player. It can still choose
-- artwork when EVERY possible remote party member of that class has the same
-- confirmed spec. Require a public meter snapshot as evidence for the class/icon
-- key, and never attach the answer to a row index or recover a hidden GUID.
local snapshots = setmetatable({}, {__mode = 'k'})
local invalidSessions = setmetatable({}, {__mode = 'k'})

local function IsSecret(value)
	return issecretvalue and issecretvalue(value)
end

local function PublicTable(value)
	return not IsSecret(value) and type(value) == 'table'
end

local function Roster()
	if not UnitGUID or not IsInRaid then return end
	local raid = IsInRaid()
	if IsSecret(raid) or raid then return end
	local members, byGUID, signature = {}, {}, {}
	for i = 0, 4 do
		local unit = i == 0 and 'player' or 'party'..i
		local exists = UnitExists(unit)
		if IsSecret(exists) then return end
		if exists then
			local player, guid = UnitIsPlayer(unit), UnitGUID(unit)
			local _, class = UnitClass(unit)
			if IsSecret(player) or not player or IsSecret(guid) or type(guid) ~= 'string'
				or guid:sub(1, 7) ~= 'Player-' or IsSecret(class) or not JI.dataHelper.class[class] then return end
			local member = {guid = guid, class = class, own = i == 0}
			members[#members + 1], byGUID[guid] = member, member
			signature[#signature + 1] = guid..':'..class
		elseif i == 0 then return end
	end
	if #members < 2 then return end
	table.sort(signature)
	return members, byGUID, table.concat(signature, ';')
end

local function Context(sessionType, sessionID, meterType)
	if IsSecret(sessionType) or IsSecret(sessionID) or IsSecret(meterType) then return end
	local sessions, types = Enum and Enum.DamageMeterSessionType, Enum and Enum.DamageMeterType
	if not sessions or not types or (sessionID ~= nil and sessionID ~= 0)
		or (sessionType ~= sessions.Current and sessionType ~= sessions.Overall) then return end
	-- Limit inference to native friendly-player views; never enemy or custom views.
	for _, name in ipairs({'DamageDone', 'Dps', 'HealingDone', 'Hps', 'Absorbs',
		'Interrupts', 'Dispels', 'DamageTaken', 'AvoidableDamageTaken', 'Deaths'}) do
		if types[name] ~= nil and meterType == types[name] then return sessionType..':'..meterType end
	end
end

local function Key(class, fileID)
	if IsSecret(class) or type(class) ~= 'string' or not JI.dataHelper.class[class]
		or IsSecret(fileID) or type(fileID) ~= 'number' or fileID <= 0 then return end
	return class..':'..fileID
end

function JI:CapturePartyMeterSnapshot(window, session, sessionType, sessionID, meterType)
	if not window or InCombatLockdown() or not PublicTable(session) or invalidSessions[window] == session then return end
	local context = Context(sessionType, sessionID, meterType)
	local _, members, signature = Roster()
	if not context or not signature or not PublicTable(session.combatSources) then return end
	local observed = {}
	for _, source in ipairs(session.combatSources) do
		if not PublicTable(source) then return end
		local key = Key(source.classFilename, source.specIconID)
		if key then
			local guid = source.sourceGUID
			-- Do not replace a complete pre-combat snapshot with partially secret data.
			if IsSecret(guid) or IsSecret(source.sourceCreatureID) or IsSecret(source.threatPet) then return end
			local member = type(guid) == 'string' and members[guid]
			local displays = Enum and Enum.DamageMeterSourceDisplayType
			local enemy = displays and not IsSecret(source.sourceDisplayType) and source.sourceDisplayType == displays.Enemy
			local eligible = member and member.class == source.classFilename and not source.threatPet
				and not enemy and (source.sourceCreatureID == nil or source.sourceCreatureID == 0)
			-- An outsider, departed player or pet sharing this key makes it unsafe.
			if not eligible then observed[key] = false
			elseif observed[key] == nil then observed[key] = true end
		end
	end
	local snapshot = snapshots[window]
	if not snapshot or snapshot.context ~= context or snapshot.roster ~= signature then
		snapshot = {context = context, roster = signature, keys = {}}
		snapshots[window] = snapshot
	end
	-- Current rolls to an empty session between pulls. Retain evidence for the
	-- unchanged party, but keep conflicting historical participants blocked.
	for key, eligible in pairs(observed) do
		if not eligible or snapshot.keys[key] == nil then snapshot.keys[key] = eligible end
	end
	snapshot.session = session
end

function JI:GetPartyMeterSpecialization(window, class, fileID, source, sessionType, sessionID, meterType)
	local snapshot = window and snapshots[window]
	if not snapshot or not PublicTable(source) or not IsSecret(source.sourceGUID)
		or IsSecret(source.isLocalPlayer) or source.isLocalPlayer ~= false then return end
	local context, key = Context(sessionType, sessionID, meterType), Key(class, fileID)
	if not context or snapshot.context ~= context or not key or snapshot.keys[key] ~= true then return end
	if IsSecret(source.classFilename) or source.classFilename ~= class
		or IsSecret(source.specIconID) or source.specIconID ~= fileID then return end
	local displays = Enum and Enum.DamageMeterSourceDisplayType
	if displays and not IsSecret(source.sourceDisplayType) and source.sourceDisplayType == displays.Enemy then return end
	local members, _, signature = Roster()
	if not members or snapshot.roster ~= signature or not JI.GetCachedInspectionByGUID then return end
	local selected
	for _, member in ipairs(members) do
		-- isLocalPlayer=false rules out our own build, even in a same-class party.
		if not member.own and member.class == class then
			local spec = JI:GetCachedInspectionByGUID(member.guid, class)
			local info = not IsSecret(spec) and spec and JI.dataHelper.specialization[spec]
			if not info or info.class ~= class or (selected and selected ~= spec) then return end
			selected = spec
		end
	end
	return selected
end

function JI:InvalidatePartyMeterSnapshots()
	for window, snapshot in pairs(snapshots) do
		invalidSessions[window] = snapshot.session
		snapshots[window] = nil
	end
end
