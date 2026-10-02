local JI = unpack(JiberishIcons)

-- Order matches the exported 8-column specialization sheet. Coordinates use
-- the same 1024px basis as class/race packs; each actual cell is 256px.
JI.dataHelper.specOrder = {
	{250, 'Blood Death Knight', 'DEATHKNIGHT'},
	{251, 'Frost Death Knight', 'DEATHKNIGHT'},
	{252, 'Unholy Death Knight', 'DEATHKNIGHT'},
	{102, 'Balance Druid', 'DRUID'},
	{103, 'Feral Druid', 'DRUID'},
	{104, 'Guardian Druid', 'DRUID'},
	{105, 'Restoration Druid', 'DRUID'},
	{253, 'Beast Mastery Hunter', 'HUNTER'},
	{254, 'Marksmanship Hunter', 'HUNTER'},
	{255, 'Survival Hunter', 'HUNTER'},
	{62, 'Arcane Mage', 'MAGE'},
	{63, 'Fire Mage', 'MAGE'},
	{64, 'Frost Mage', 'MAGE'},
	{268, 'Brewmaster Monk', 'MONK'},
	{270, 'Mistweaver Monk', 'MONK'},
	{269, 'Windwalker Monk', 'MONK'},
	{65, 'Holy Paladin', 'PALADIN'},
	{66, 'Protection Paladin', 'PALADIN'},
	{70, 'Retribution Paladin', 'PALADIN'},
	{256, 'Discipline Priest', 'PRIEST'},
	{257, 'Holy Priest', 'PRIEST'},
	{258, 'Shadow Priest', 'PRIEST'},
	{259, 'Assassination Rogue', 'ROGUE'},
	{260, 'Outlaw Rogue', 'ROGUE'},
	{261, 'Subtlety Rogue', 'ROGUE'},
	{262, 'Elemental Shaman', 'SHAMAN'},
	{263, 'Enhancement Shaman', 'SHAMAN'},
	{264, 'Restoration Shaman', 'SHAMAN'},
	{265, 'Affliction Warlock', 'WARLOCK'},
	{266, 'Demonology Warlock', 'WARLOCK'},
	{267, 'Destruction Warlock', 'WARLOCK'},
	{71, 'Arms Warrior', 'WARRIOR'},
	{72, 'Fury Warrior', 'WARRIOR'},
	{73, 'Protection Warrior', 'WARRIOR'},
	{577, 'Havoc Demon Hunter', 'DEMONHUNTER'},
	{581, 'Vengeance Demon Hunter', 'DEMONHUNTER'},
	{1467, 'Devastation Evoker', 'EVOKER'},
	{1468, 'Preservation Evoker', 'EVOKER'},
	{1473, 'Augmentation Evoker', 'EVOKER'},
	{1480, 'Devourer Demon Hunter', 'DEMONHUNTER'},
}
JI.dataHelper.specialization = {}
for index, entry in ipairs(JI.dataHelper.specOrder) do
	local column, row = (index - 1) % 8, math.floor((index - 1) / 8)
	local left, right, top, bottom = column / 8, (column + 1) / 8, row / 8, (row + 1) / 8
	JI.dataHelper.specialization[entry[1]] = {
		name = entry[2], class = entry[3],
		texString = format('%d:%d:%d:%d', column * 128, (column + 1) * 128, row * 128, (row + 1) * 128),
		texCoords = {left, top, left, bottom, right, top, right, bottom},
	}
end

local function IsSecret(value)
	return issecretvalue and issecretvalue(value)
end

local function ValidSpec(value)
	return not IsSecret(value) and type(value) == 'number' and JI.dataHelper.specialization[value] and value or nil
end

-- Classic talent tabs have a stable class-specific order but different IDs
-- and localized names. Feral Combat shares one tree; Combat uses Outlaw art.
local talentTreeSpecs = {
	DEATHKNIGHT = {250, 251, 252}, DRUID = {102, 103, 105}, HUNTER = {253, 254, 255},
	MAGE = {62, 63, 64}, PALADIN = {65, 66, 70}, PRIEST = {256, 257, 258},
	ROGUE = {259, 260, 261}, SHAMAN = {262, 263, 264}, WARLOCK = {265, 266, 267},
	WARRIOR = {71, 72, 73},
}

local function UsesForeverTalents()
	if not GetBuildInfo then return false end
	local _, _, _, interface = GetBuildInfo()
	return type(interface) == 'number' and interface >= 16000 and interface < 20000
end

local function PublicTable(value)
	return not IsSecret(value) and type(value) == 'table'
end

local function PublicNumber(value)
	return not IsSecret(value) and type(value) == 'number'
end

local function ForeverConfigSpec(class, configID)
	if IsSecret(class) or type(class) ~= 'string' then return end
	local specs = talentTreeSpecs[class]
	local traits = C_Traits
	if not specs or not traits or not traits.GetConfigInfo or not traits.GetGroupDisplayInfoByTreeID
		or not traits.GetGroupCurrencyInfo then return end
	local config = traits.GetConfigInfo(configID)
	if not PublicTable(config) or not PublicTable(config.treeIDs) then return end
	local treeID = config.treeIDs[1]
	if not PublicNumber(treeID) or treeID <= 0 then return end
	-- Match Blizzard's Camelot talent headers (build 1.60.1.70124): display groups
	-- are in tree order, currency rows must be joined by traitNodeGroupID.
	local displays = traits.GetGroupDisplayInfoByTreeID(treeID)
	if not PublicTable(displays) or #displays ~= #specs then return end
	local groupIDs, groupIndex, points = {}, {}, {}
	for index, display in ipairs(displays) do
		if not PublicTable(display) or not PublicNumber(display.groupID) then return end
		if groupIndex[display.groupID] then return end
		groupIDs[index], groupIndex[display.groupID], points[index] = display.groupID, index, 0
	end
	local groups = traits.GetGroupCurrencyInfo(configID, groupIDs)
	if not PublicTable(groups) then return end
	for _, group in ipairs(groups) do
		if not PublicTable(group) or not PublicNumber(group.traitNodeGroupID) then return end
		local index = groupIndex[group.traitNodeGroupID]
		if not index or not PublicTable(group.currencyInfos) then return end
		local currency = group.currencyInfos[1]
		if not PublicTable(currency) or not PublicNumber(currency.spent) or currency.spent < 0 then return end
		points[index] = currency.spent
	end
	local highest, selected, tied = 0, nil, false
	for index, spent in ipairs(points) do
		if spent > highest then
			highest, selected, tied = spent, specs[index], false
		elseif spent == highest then
			tied = true
		end
	end
	local specID = selected and not tied and selected or nil
	return specID, not specID
end

local committedForeverSpec
local function CachedForeverSpec(class, configID, group)
	local cached = committedForeverSpec
	if cached and cached.class == class and (not configID or cached.configID == configID)
		and (not group or cached.group == group) then
		return cached.specID, cached.classFallback
	end
end

local function ForeverTalentSpec()
	local _, class = UnitClass('player')
	if IsSecret(class) or type(class) ~= 'string' then return end
	local traits, api = C_Traits, C_SpecializationInfo
	if not traits or not traits.ConfigHasStagedChanges then return end
	local configID, group
	if api and api.GetActiveSpecGroup and api.GetCombatConfigIDForSpecGroup then
		group = api.GetActiveSpecGroup()
		if not PublicNumber(group) or group <= 0 then return CachedForeverSpec(class) end
		configID = api.GetCombatConfigIDForSpecGroup(group)
	elseif C_ClassTalents and C_ClassTalents.GetActiveConfigID then
		configID = C_ClassTalents.GetActiveConfigID()
	end
	if not PublicNumber(configID) or configID <= 0 then return CachedForeverSpec(class, nil, group) end
	-- Group currencies include pending edits. Keep the last committed result while
	-- previewing, scoped to this character's active config; never read another tab.
	local staged = traits.ConfigHasStagedChanges(configID)
	if IsSecret(staged) or type(staged) ~= 'boolean' or staged then
		return CachedForeverSpec(class, configID, group)
	end
	local specID, fallback = ForeverConfigSpec(class, configID)
	-- Missing/restricted talent reads are not an empty build. Keep this config's
	-- last confirmed result; a successful zero/tied allocation still replaces it.
	if not specID and not fallback then return CachedForeverSpec(class, configID, group) end
	committedForeverSpec = {configID = configID, group = group, class = class, specID = specID, classFallback = not specID}
	return specID, not specID
end

-- Called only after a GUID-matched INSPECT_READY, never from an arbitrary unit
-- repaint: the shared inspect config belongs to the last inspected character.
function JI:ReadInspectedSpecialization(unit)
	if UsesForeverTalents() then
		if not C_Traits or not C_Traits.HasValidInspectData then return end
		local ready = C_Traits.HasValidInspectData()
		if IsSecret(ready) or not ready then return end
		local _, class = UnitClass(unit)
		return ForeverConfigSpec(class, -1) -- Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID
	end
	local api = C_SpecializationInfo
	local inspect = (api and api.GetInspectSpecialization) or GetInspectSpecialization
	if inspect then return ValidSpec(inspect(unit)) end
end

local function UsesTalentTrees()
	if GetBuildInfo then
		local _, _, _, interface = GetBuildInfo()
		if type(interface) == 'number' then return interface >= 10000 and interface < 40000 end
	end
	-- Older Classic/TBC/Wrath clients without build metadata in the caller.
	return WOW_PROJECT_ID == 2 or WOW_PROJECT_ID == 5 or WOW_PROJECT_ID == 11
end

local function HasTalentTrees()
	return UsesTalentTrees() and (GetTalentTabInfo or (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo))
end

local function PlayerTalentSpec()
	local _, class = UnitClass('player')
	if IsSecret(class) or type(class) ~= 'string' then return end
	local specs = talentTreeSpecs[class]
	if not specs then return end
	local api = C_SpecializationInfo
	local getGroup = (api and api.GetActiveSpecGroup) or GetActiveTalentGroup
	local group = getGroup and getGroup()
	if IsSecret(group) then return end
	local highest, selected, tied = 0, nil, false
	for index, spec in ipairs(specs) do
		local points
		if GetTalentTabInfo then
			local first, _, third, _, fifth = GetTalentTabInfo(index, false, false, group)
			if IsSecret(first) then return end
			-- Vanilla/TBC: name, texture, points. Wrath+: ID, name, description, texture, points.
			if type(first) == 'number' then points = fifth
			elseif type(first) == 'string' then points = third end
		else
			-- Modern Classic: spent points are return 7; ignore uncommitted preview points.
			points = select(7, api.GetSpecializationInfo(index, false, false, nil, nil, group))
		end
		if IsSecret(points) or type(points) ~= 'number' or points < 0 then return end
		if points > highest then
			highest, selected, tied = points, spec, false
		elseif points == highest then
			tied = true
		end
	end
	if selected and not tied then return selected end
	-- Only a known, ambiguous personal allocation permits a class-crest fallback.
	-- Missing/restricted data and unknown other players continue to hide.
	return nil, true
end

-- Read the player's committed build, public spec APIs, or a GUID-scoped inspect
-- result. Unknown other players enter the throttled inspection queue on demand.
function JI:GetUnitSpecialization(unit)
	if IsSecret(unit) or type(unit) ~= 'string' then return end
	local isSelf = unit == 'player' or (UnitIsUnit and UnitIsUnit(unit, 'player'))
	if IsSecret(isSelf) then return end
	local api = C_SpecializationInfo
	if isSelf then
		if UsesForeverTalents() then return ForeverTalentSpec() end
		if HasTalentTrees() then return PlayerTalentSpec() end
		local getIndex = (api and api.GetSpecialization) or GetSpecialization
		local getInfo = (api and api.GetSpecializationInfo) or GetSpecializationInfo
		if not getIndex or not getInfo then return end
		local index = getIndex()
		if IsSecret(index) or type(index) ~= 'number' or index <= 0 then return end
		return ValidSpec(getInfo(index))
	end
	local inspect = (api and api.GetInspectSpecialization) or GetInspectSpecialization
	if inspect then
		local spec = inspect(unit)
		if IsSecret(spec) then
			-- Forever's selected-spec API is not its talent-tree result. A hidden
			-- starter ID must not block an independently verified trait inspection.
			if not UsesForeverTalents() then return end
		elseif ValidSpec(spec) then
			if JI.RememberPublicSpecialization then JI:RememberPublicSpecialization(unit, spec) end
			return spec
		end
	end
	-- Retail can already have a current, direct spec ID. Prefer that over an older
	-- cached answer; Forever starter IDs still fall through to trait inspection.
	if JI.GetCachedInspection then
		local spec, fallback = JI:GetCachedInspection(unit)
		if spec or fallback then return spec, fallback end
	end
	-- LibOpenRaid, when loaded by another addon, may know a group member's spec.
	-- Check public identity before letting it resolve a name or access a cache.
	local name, realm = UnitName(unit)
	if IsSecret(name) or IsSecret(realm) or type(name) ~= 'string' then return end
	local raid = LibStub('LibOpenRaid-1.0', true)
	if raid and raid.GetUnitInfo then
		local info = raid.GetUnitInfo(unit)
		if not IsSecret(info) and type(info) == 'table' then
			local spec = ValidSpec(info.specId)
			if spec then return spec end
		end
	end
	if JI.RequestSpecializationInspection then JI:RequestSpecializationInspection(unit) end
end

function JI:RefreshSpecializationIcons()
	if JI.RefreshDamageMeterSpecializations then JI:RefreshDamageMeterSpecializations() end
	if JI.RefreshBlizzardSpecializations then JI:RefreshBlizzardSpecializations() end
	if JI.RefreshSUFSpecializations then JI:RefreshSUFSpecializations() end
	if JI.RefreshElvUISpecializations then JI:RefreshElvUISpecializations() end
	if JI.RefreshEllesmereSpecializations then JI:RefreshEllesmereSpecializations() end
end

local driver
function JI:SetupSpecializationIcons()
	if driver then return end
	local api = C_SpecializationInfo
	if not ((api and api.GetSpecialization) or GetSpecialization or HasTalentTrees() or UsesForeverTalents()) then return end
	driver = CreateFrame('Frame')
	for _, event in ipairs({'PLAYER_ENTERING_WORLD', 'PLAYER_SPECIALIZATION_CHANGED',
		'PLAYER_TALENT_UPDATE', 'ACTIVE_TALENT_GROUP_CHANGED', 'CHARACTER_POINTS_CHANGED',
		'TRAIT_CONFIG_UPDATED', 'TRAIT_TREE_CURRENCY_INFO_UPDATED', 'TRAIT_CONFIG_CREATED',
		'PLAYER_LEVEL_UP', 'INSPECT_READY', 'GROUP_ROSTER_UPDATE', 'PLAYER_REGEN_ENABLED',
		'PLAYER_TARGET_CHANGED', 'PLAYER_FOCUS_CHANGED'}) do
		-- Event availability differs across Classic and Retail clients.
		if C_EventUtils and C_EventUtils.IsEventValid then
			if C_EventUtils.IsEventValid(event) then driver:RegisterEvent(event) end
		else
			pcall(driver.RegisterEvent, driver, event)
		end
	end
	driver:SetScript('OnEvent', function(_, event, unit)
		if event == 'ACTIVE_TALENT_GROUP_CHANGED' or (event == 'PLAYER_SPECIALIZATION_CHANGED'
			and not IsSecret(unit) and unit == 'player') then
			-- A new active build must be verified before a transient failure can
			-- reuse it. Ordinary combat/inspection events do not clear our build.
			committedForeverSpec = nil
		end
		if JI.OnSpecializationInspectEvent then JI:OnSpecializationInspectEvent(event, unit) end
		JI:RefreshSpecializationIcons()
	end)
	if JI.SetupSpecializationInspection then JI:SetupSpecializationInspection() end
	local raid = LibStub('LibOpenRaid-1.0', true)
	if raid and raid.RegisterCallback then
		raid.RegisterCallback(JI, 'UnitInfoUpdate', 'RefreshSpecializationIcons')
		raid.RegisterCallback(JI, 'UnitInfoWipe', 'RefreshSpecializationIcons')
	end
end
