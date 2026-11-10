local JI = unpack(JiberishIcons)
local serializer = LibStub('AceSerializer-3.0')
local MAX_BYTES, MAX_DEPTH, MAX_VALUES = 250000, 32, 25000
local function Checksum(text)
	local a, b = 1, 0
	for i = 1, #text do a = (a + text:byte(i)) % 65521; b = (b + a) % 65521 end
	return string.format('%08x', b * 65536 + a)
end
local function Validate(value, schema, depth, budget)
	depth = depth or 0; budget = budget or {n = 0}
	budget.n = budget.n + 1
	assert(depth <= MAX_DEPTH and budget.n <= MAX_VALUES, 'Profile is too large or deeply nested.')
	local kind = type(value)
	assert(kind == 'table' or kind == 'string' or kind == 'boolean' or kind == 'number', 'Unsupported profile value.')
	if schema ~= nil then assert(kind == type(schema), 'A setting has an invalid value type.') end
	if kind == 'number' then assert(value == value and math.abs(value) < 1e12, 'Invalid profile number.')
	elseif kind == 'string' then assert(#value <= 8192, 'A setting contains too much text.')
	elseif kind == 'table' then
		for k, v in pairs(value) do
			assert(type(k) == 'string' or (type(k) == 'number' and k == math.floor(k) and k > 0 and k < 100000), 'Invalid profile key.')
			if type(k) == 'string' then assert(#k <= 256 and not k:find('[%c]'), 'Invalid profile key.') end
			local expected; if type(schema) == 'table' then expected = schema[k] end
			Validate(v, expected, depth + 1, budget)
		end
	end
end
local function Equal(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= 'table' then return a == b end
	for k, v in pairs(a) do if not Equal(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end
function JI:ExportProfileString()
	if InCombatLockdown() then return nil, 'Leave combat before exporting.' end
	-- Save unfinished mover drags before taking the snapshot.
	if JI.LockPortraits then JI:LockPortraits() end
	if JI.LockCrosshair then JI:LockCrosshair() end
	local payload = {addon='JiberishIcons', version=1, profile=JI:CopyTable({}, JI.db), global=JI:CopyTable({}, JI.global)}
	local ok, result = pcall(function()
		Validate(payload)
		local body = serializer:Serialize(payload)
		assert(#body <= MAX_BYTES, 'Profile is too large to share.')
		return '!JI1!'..Checksum(body)..'!'..body
	end)
	if not ok then return nil, 'Could not export profile: '..tostring(result) end
	return result
end
function JI:ReadProfileString(text)
	if type(text) ~= 'string' or #text > MAX_BYTES + 1024 then return nil, 'Invalid or oversized profile string.' end
	text = text:gsub('[%c ]','')
	local hash, body = text:match('^!JI1!(%x%x%x%x%x%x%x%x)!(.+)$')
	if not body or Checksum(body) ~= hash:lower() then return nil, 'Incomplete or damaged JiberishIcons profile string. Copy the entire export.' end
	-- Bound nesting before handing the input to the recursive data parser.
	-- No imported data is ever evaluated as Lua code. Uncompressed strings
	-- also let this size limit bound the actual parser input.
	local depth, count = 0, 0
	for token in body:gmatch('%^(.)') do
		count = count + 1
		if token == 'T' then depth = depth + 1 elseif token == 't' then depth = depth - 1 end
		if depth < 0 or depth > MAX_DEPTH or count > MAX_VALUES * 3 then return nil, 'Profile structure exceeds the supported limits.' end
	end
	if depth ~= 0 then return nil, 'Incomplete profile structure.' end
	local ok, payload, extra = serializer:Deserialize(body)
	if not ok or type(payload) ~= 'table' or extra ~= nil or payload.addon ~= 'JiberishIcons' or payload.version ~= 1
		or type(payload.profile) ~= 'table' or type(payload.global) ~= 'table' then return nil, 'This is not a supported JiberishIcons profile.' end
	local valid, err = pcall(function()
		Validate(payload)
		Validate(payload.profile, JI.data.defaults.profile)
		Validate(payload.global, JI.data.defaults.global)
		for _, pack in pairs(payload.global.customPacks and payload.global.customPacks.class and payload.global.customPacks.class.styles or {}) do
			assert(type(pack) == 'table', 'Invalid custom icon-pack definition.')
			for _, field in ipairs({'name','path','fileName'}) do assert(type(pack[field]) == 'string' and #pack[field] > 0, 'Invalid custom icon-pack definition.') end
			for _, field in ipairs({'artist','site'}) do assert(pack[field] == nil or type(pack[field]) == 'string', 'Invalid custom icon-pack credit.'); pack[field] = pack[field] or '' end
		end
	end)
	if not valid then return nil, 'Invalid profile settings: '..tostring(err) end
	return payload
end
function JI:ImportProfileString(text, name)
	if InCombatLockdown() then return false, 'Leave combat before importing.' end
	local payload, err = JI:ReadProfileString(text)
	if not payload then return false, err end
	if type(name) ~= 'string' then return false, 'Enter a name for the imported profile.' end
	name = name:match('^%s*(.-)%s*$')
	if #name == 0 or #name > 80 or name:find('[%c]') then return false, 'Use a profile name of 1–80 characters.' end
	local styles = payload.global.customPacks and payload.global.customPacks.class and payload.global.customPacks.class.styles or {}
	for key, data in pairs(styles) do
		local existing = JI.global.customPacks.class.styles[key]
		if existing and not Equal(existing, data) then return false, 'A different custom icon pack already uses the name "'..key..'". Rename that pack before importing.' end
	end
	local base, suffix = name, 2
	while JI.data.profiles[name] do name = base..' ('..suffix..')'; suffix = suffix + 1 end
	-- Import into a new profile. Existing profiles and custom packs survive.
	JI:CopyTable(JI.global, payload.global)
	JI:MergeStylePacks(); JI:BuildCustomStylePacks(); JI:UpdateCustomOptionsList()
	JI.data.profiles[name] = JI:CopyTable({}, payload.profile)
	JI.data:SetProfile(name)
	return true, 'Imported and activated "'..name..'". Custom artwork files and host-addon profiles must be shared separately.', name
end
function JI:BuildProfileSharingOptions(profiles)
	local ACH = JI.Libs.ACH
	local exportText, importText, name, message = '', '', 'Shared layout', ''
	local share = ACH:Group('Export / import', nil, 100, nil, nil, nil, function() return InCombatLockdown() end)
	share.inline = true; profiles.args.sharing = share
	share.args.description = ACH:Description('Share all JiberishIcons settings in the current profile: unit-frame themes, end caps, portraits and model fit, crosshair/GCD, icon choices, chat and meter settings, plus custom icon-pack definitions. ElvUI/EllesmereUI frame dimensions, positions, text, colors and Eltruism gradients belong to those addons: share their profiles too for the complete UI. Custom image files are not embedded.', 0)
	share.args.export = ACH:Execute('Generate export string', nil, 1, function()
		local err; exportText, err = JI:ExportProfileString(); message = err or 'Export ready. Select and copy the complete string.'; exportText = exportText or ''
	end)
	share.args.output = ACH:Input('Copy this export string', nil, 2, 6, 'full', function() return exportText end, function() end)
	share.args.name = ACH:Input('New profile name', 'Import creates and activates a new profile. Existing profiles are kept.', 3, nil, 'full', function() return name end, function(_, v) name = v end)
	share.args.input = ACH:Input('Paste a JiberishIcons export', nil, 4, 6, 'full', function() return importText end, function(_, v) importText = v end)
	share.args.import = ACH:Execute('Import as new profile', nil, 5, function()
		local ok; ok, message = JI:ImportProfileString(importText, name)
		if ok then importText = ''; exportText = '' end
	end)
	share.args.status = ACH:Description(function() return message end, 6)
end

local refreshDriver
function JI:RefreshProfileHosts()
	if InCombatLockdown() then
		if not refreshDriver then
			refreshDriver = CreateFrame('Frame')
			refreshDriver:RegisterEvent('PLAYER_REGEN_ENABLED')
			refreshDriver:SetScript('OnEvent', function() if refreshDriver.pending then refreshDriver.pending = nil; JI:RefreshProfileHosts() end end)
		end
		refreshDriver.pending = true; return
	end
	local E = _G.ElvUI and _G.ElvUI[1]
	if E and E.UnitFrames and E.UnitFrames.Update_AllFrames then E.UnitFrames:Update_AllFrames() end
	if JI.UpdateSUF then JI:UpdateSUF() end
end
