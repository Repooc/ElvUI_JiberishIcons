-- Run from the repository root: lua5.1 tests/ellesmereui.lua
-- Loads the real addon defaults/options, AceDB and adapter with a small WoW UI mock.
local root = 'JiberishIcons/'
local passed = 0
local function expect(value, message) assert(value, message or 'expectation failed') end
local function equal(actual, expected) assert(actual == expected, tostring(actual)..' ~= '..tostring(expected)) end

local function fixture(loaded, client, saved)
	local env = setmetatable({}, { __index = _G })
	env._G = env
	env.JiberishIconsDB = saved
	local world, timers, objects = {}, {}, {}
	local secret = {}
	local state = { combat = false, loaded = loaded ~= false, addons = {} }
	env.issecretvalue = function(v) return rawequal(v, secret) end
	env.securecallfunction = function(fn, ...) return fn(...) end
	env.wipe = function(t) for k in pairs(t) do t[k] = nil end; return t end
	env.format, env.gsub, env.strupper, env.sort = string.format, string.gsub, string.upper, table.sort
	env.strsplit = function(separator, value) return value:match('^([^'..separator..']*)') end
	env.GetRealmName = function() return 'Realm' end
	env.UnitName = function() return 'Tester' end
	env.UnitRace = function() return 'Human', 'HUMAN' end
	env.UnitFactionGroup = function() return 'Alliance' end
	env.GetLocale = function() return 'enUS' end
	env.GetCurrentRegion = function() return 1 end
	env.UnitExists = function(u) return world[u] and world[u].exists end
	env.UnitIsPlayer = function(u) return world[u] and world[u].player end
	env.UnitClass = function(u) return 'Class', world[u] and world[u].class end
	env.InCombatLockdown = function() return state.combat end
	env.WOW_PROJECT_ID, env.WOW_PROJECT_MAINLINE = 1, 1
	env.C_AddOns = {
		GetAddOnMetadata = function(_, key) return key == 'Title' and 'JiberishIcons' or '1.4.7' end,
		IsAddOnLoaded = function(name) return (name == 'EllesmereUIUnitFrames' and state.loaded) or state.addons[name] end,
	}
	if client then
		env.WOW_PROJECT_ID = 2 -- Exercise the non-Mainline path.
		if client ~= 'forever' then env.issecretvalue = nil end
		if client == 'forever' then
			env.GetBuildInfo = function() return '1.60.1', '70009', 'Sep 28 2026', 16001 end
		end
		env.C_AddOns.GetAddOnEnableState = function(name, character)
			equal(character, 'Tester')
			return env.C_AddOns.IsAddOnLoaded(name) and 2 or 0
		end
		if client == 'legacy' then
			env.GetAddOnMetadata = env.C_AddOns.GetAddOnMetadata
			env.IsAddOnLoaded = env.C_AddOns.IsAddOnLoaded
			env.GetAddOnEnableState = function(character, name)
				equal(character, 'Tester')
				return env.IsAddOnLoaded(name) and 2 or 0
			end
			env.C_AddOns = nil
		end
	end
	env.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
	local methods = {}
	function methods:SetScript(event, fn) self.scripts[event] = fn end
	function methods:HookScript(event, fn)
		local old = self.scripts[event]
		self.scripts[event] = function(...) if old then old(...) end; fn(...) end
	end
	function methods:RegisterEvent(event) self.events[event] = true end
	function methods:GetAttribute(key) return self.attributes and self.attributes[key] end
	function methods:SetAttribute(key, value)
		self.attributes = self.attributes or {}; self.attributes[key] = value
		if self.scripts.OnAttributeChanged then self.scripts.OnAttributeChanged(self, key, value) end
	end
	function methods:Show()
		local changed = not self.shown
		self.shown = true
		if changed and self.scripts.OnShow then self.scripts.OnShow(self) end
	end
	function methods:Hide() self.shown = false end
	function methods:SetShown(shown) if shown then self:Show() else self:Hide() end end
	function methods:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
	function methods:SetTexture(path) self.path = path end
	function methods:GetTexture()
		if type(self.path) == 'number' then return self.path end
		return self.path and not self.path:find('missing', 1, true) and self.path or nil
	end
	function methods:SetTexCoord(...) self.coords = {...} end
	function methods:GetTexCoord() return unpack(self.coords or {0, 1, 0, 1}) end
	function methods:SetAtlas(atlas) self.path = 'atlas:'..atlas; self.coords = {0, 1, 0, 1} end
	function methods:SetColorTexture(...) self.color = {...} end
	function methods:AddMaskTexture(mask) self.mask = mask end
	function methods:EnableMouse(on) self.mouse = on end
	function methods:SetFrameLevel(level) self.level = level end
	function methods:GetFrameLevel() return self.level or 1 end
	function methods:SetSize(w, h)
		expect(not state.combat, 'size changed in combat')
		self.width, self.height = w, h
	end
	function methods:ClearAllPoints() expect(not state.combat, 'anchors changed in combat'); self.point = nil end
	function methods:SetPoint(...) expect(not state.combat, 'position changed in combat'); self.point = {...} end
	function methods:SetAllPoints(parent) self.allPoints = parent end
	function methods:SetAlpha(alpha) self.alpha = alpha end
	function methods:GetEffectiveAlpha() return (self.alpha or 1) * (self.parent and self.parent:GetEffectiveAlpha() or 1) end
	local function object(kind, parent)
		local obj = setmetatable({ kind = kind, parent = parent, shown = true, scripts = {}, events = {}, children = {} }, { __index = methods })
		objects[#objects + 1] = obj
		if parent then parent.children[#parent.children + 1] = obj end
		return obj
	end
	env.CreateFrame = function(_, _, parent) return object('Frame', parent) end
	function methods:CreateTexture() return object('Texture', self) end
	function methods:CreateMaskTexture() return object('Mask', self) end
	env.hooksecurefunc = function(owner, name, fn)
		if type(owner) == 'string' then owner, name, fn = env, owner, name end
		local original = owner[name]
		owner[name] = function(...) original(...); fn(...) end
	end
	local function load(path, ...)
		return setfenv(assert(loadfile(root..path)), env)(...)
	end
	world.player = { exists = true, player = true, class = 'WARRIOR' }
	load('Libs/Ace3/LibStub/LibStub.lua')
	load('Libs/Ace3/CallbackHandler-1.0/CallbackHandler-1.0.lua')
	load('Libs/Ace3/AceDB-3.0/AceDB-3.0.lua')
	load('Libs/Ace3/AceLocale-3.0/AceLocale-3.0.lua')
	env.LibStub:NewLibrary('LibSharedMedia-3.0', 1)
	load('Libs/LibAceConfigHelper/LibAceConfigHelper.lua')
	local JI = { RegisterEvent = function() end }
	local aceAddon = env.LibStub:NewLibrary('AceAddon-3.0', 1)
	function aceAddon:NewAddon() return JI end
	for _, lib in ipairs({ 'AceConfig-3.0', 'AceConfigDialog-3.0', 'AceDBOptions-3.0', 'AceConfigRegistry-3.0', 'AceGUI-3.0' }) do
		env.LibStub:NewLibrary(lib, 1)
	end
	load('Init.lua', 'JiberishIcons', {})
	load('Locales/enUS.lua')
	load('Core/API.lua')
	load('Core/Specializations.lua')
	load('Core/Inspection.lua')
	load('Core/Defaults/Profile.lua')
	load('Core/Defaults/Global.lua')
	load('Core/Core.lua', 'JiberishIcons')
	-- Formatting unrelated to this adapter uses WoW's UTF8 helpers.
	JI.TextGradient = function(_, value) return value end
	JI.StripString = function(_, value) return value end
	JI.UpdateMedia = function() end
	load('Core/Options.lua', 'JiberishIcons')
	load('Core/EllesmereUI.lua')
	load('Core/DamageMeterParty.lua')
	load('Core/DamageMeters.lua')
	JI:BuildProfile()
	local ns = { Engine = { Attach = function() end, AttachPolled = function() end, RepaintAll = function() end } }
	if state.loaded then env.EllesmereUI = { _ModuleNS = { EllesmereUIUnitFrames = ns } } end
	local function flush()
		local count = 0
		while #timers > 0 do
			count = count + 1; expect(count < 20, 'unbounded startup retry')
			local pending = timers; timers = {}
			for _, fn in ipairs(pending) do fn() end
		end
	end
	local function fire(event, ...)
		for _, obj in ipairs(objects) do
			if obj.events[event] and obj.scripts.OnEvent then obj.scripts.OnEvent(obj, event, ...) end
		end
	end
	local function frame(key, class)
		world[key] = { exists = true, player = true, class = class or 'MAGE' }
		local f = object('Frame'); f._euiUnit = key
		-- Deliberately no Portrait member: icons must not depend on portraits.
		return f
	end
	local function icon(f) return f.children[1] and f.children[1].children[1] end
	return { env = env, JI = JI, ns = ns, world = world, state = state, secret = secret,
		flush = flush, fire = fire, frame = frame, icon = icon, objects = objects, load = load }
end

local function test(name, fn)
	fn(); passed = passed + 1; print('PASS '..name)
end

test('real AceDB defaults and existing integration options', function()
	local f = fixture()
	for _, key in ipairs(f.JI.dataHelper.ellesmereSettingList) do
		local db = f.JI.db.ellesmereui[key].icon
		equal(db.enable, false); equal(db.style, 'fabled'); equal(db.size, 32)
		equal(db.anchorPoint, 'RIGHT'); equal(db.xOffset, 0); equal(db.yOffset, 0)
	end
	f.JI.db.ellesmereui.player.icon.size = 64
	equal(f.JI.db.ellesmereui.target.icon.size, 32)
	expect(f.JI.Options.args.blizzard and f.JI.Options.args.elvui and f.JI.Options.args.suf)
end)

test('missing addon is a no-op', function()
	local f = fixture(false)
	local count = #f.objects
	f.JI:SetupEllesmereUI(); f.JI:UpdateEllesmereUI(); f.flush()
	equal(#f.objects, count); expect(f.JI.Options.args.ellesmereui.hidden())
end)

test('late frame readiness, idempotency, independent icons and inherited fading', function()
	local f = fixture()
	f.JI:SetupEllesmereUI(); f.flush()
	f.JI.db.ellesmereui.target.icon.enable = true
	local target = f.frame('target')
	f.ns.Engine.Attach(target, 'target'); f.flush()
	local icon = f.icon(target)
	expect(icon:IsShown()); equal(icon.coords[1], 0.125)
	equal(target.children[1].point[1], 'LEFT'); equal(target.children[1].point[3], 'RIGHT')
	equal(target.children[1].mouse, false)
	f.JI:SetupEllesmereUI(); f.ns.frames = { target = target }; f.JI:UpdateEllesmereUI()
	equal(#target.children, 1)
	target:SetAlpha(0.25); equal(icon:GetEffectiveAlpha(), 0.25)
	target:Hide(); expect(not icon:IsShown()); target:Show(); expect(icon:IsShown())
	expect(target.Portrait == nil)
end)

test('player, NPC, missing, vehicle and restricted identity transitions', function()
	local f = fixture()
	local target = f.frame('target')
	f.ns.frames = { target = target }; f.JI.db.ellesmereui.target.icon.enable = true
	f.JI:SetupEllesmereUI(); f.flush()
	local icon = f.icon(target)
	for _, field in ipairs({ 'exists', 'player', 'class' }) do
		local old = f.world.target[field]
		f.world.target[field] = f.secret; f.ns.Engine.RepaintAll(target); expect(not icon:IsShown())
		f.world.target[field] = old; f.ns.Engine.RepaintAll(target); expect(icon:IsShown())
	end
	f.world.target.player = false; f.fire('PLAYER_TARGET_CHANGED'); expect(not icon:IsShown())
	f.world.target.player = true; f.world.target.exists = false; f.fire('UNIT_TARGET'); expect(not icon:IsShown())
	f.world.target.exists = true; target._euiUnit = 'vehicle'; f.ns.Engine.RepaintAll(target); expect(not icon:IsShown())
	target._euiUnit = f.secret; f.ns.Engine.RepaintAll(target); expect(not icon:IsShown())
	target._euiUnit = 'target'; f.world.target.class = 'ROGUE'; f.fire('UNIT_NAME_UPDATE'); expect(icon:IsShown()); equal(icon.coords[1], 0.25)
end)

test('ToT/FoT use engine identity repaints, with no adapter OnUpdate loop', function()
	local f = fixture(); f.JI:SetupEllesmereUI()
	for _, key in ipairs({ 'targettarget', 'focustarget' }) do
		f.JI.db.ellesmereui[key].icon.enable = true
		local frame = f.frame(key)
		f.ns.Engine.AttachPolled(frame, key)
		f.world[key].class = 'ROGUE'; f.ns.Engine.RepaintAll(frame, 'PollIdentity')
		equal(f.icon(frame).coords[1], 0.25)
	end
	for _, obj in ipairs(f.objects) do expect(not obj.scripts.OnUpdate) end
end)

test('combat defers creation/layout while existing class icons update', function()
	local f = fixture()
	local target, focus = f.frame('target'), f.frame('focus')
	f.ns.frames = { target = target, focus = focus }
	f.JI.db.ellesmereui.target.icon.enable = true
	f.JI:SetupEllesmereUI(); f.flush()
	f.state.combat = true
	f.JI.db.ellesmereui.focus.icon.enable = true
	f.JI.db.ellesmereui.target.icon.size = 64
	f.JI.db.ellesmereui.target.icon.xOffset = 50
	f.JI:UpdateEllesmereUI()
	expect(not f.icon(focus)); equal(target.children[1].width, 32)
	f.world.target.class = 'ROGUE'; f.ns.Engine.RepaintAll(target)
	equal(f.icon(target).coords[1], 0.25)
	f.JI.db.ellesmereui.target.icon.enable = false; f.JI:UpdateEllesmereUI(); expect(not f.icon(target):IsShown())
	f.state.combat = false; f.fire('PLAYER_REGEN_ENABLED'); f.flush()
	expect(f.icon(focus):IsShown()); equal(target.children[1].width, 64); equal(target.children[1].point[4], 50)
end)

test('settings controls and Apply to All copy all fields without aliasing', function()
	local f = fixture()
	local group = f.JI.Options.args.ellesmereui.args.target
	for key, value in pairs({ enable = true, style = 'fabledrealm', size = 48, anchorPoint = 'TOP', xOffset = 12, yOffset = 18 }) do
		group.set({key}, value); equal(group.get({key}), value)
	end
	group.args.applyAll.func()
	for _, key in ipairs(f.JI.dataHelper.ellesmereSettingList) do
		local db = f.JI.db.ellesmereui[key].icon
		equal(db.enable, true); equal(db.style, 'fabledrealm'); equal(db.size, 48)
		equal(db.anchorPoint, 'TOP'); equal(db.xOffset, 12); equal(db.yOffset, 18)
	end
	group.set({'size'}, 20); equal(f.JI.db.ellesmereui.player.icon.size, 48)
end)

test('custom pack add/edit/delete refresh and invalid style fallback', function()
	local f = fixture()
	local target = f.frame('target'); f.ns.frames = { target = target }
	local db = f.JI.db.ellesmereui.target.icon; db.enable = true; db.style = 'custom'
	f.JI:SetupEllesmereUI(); f.flush()
	expect(f.icon(target).path:match('fabled$'))
	f.JI.global.customPacks.class.styles.custom = { path = 'Custom\\', fileName = 'custom', name = 'Custom' }
	f.JI:MergeStylePacks(); equal(f.icon(target).path, 'Custom\\custom')
	f.JI.global.customPacks.class.styles.custom.path = 'Other\\'
	f.JI:MergeStylePacks(); equal(f.icon(target).path, 'Other\\custom')
	f.JI.global.customPacks.class.styles.custom.path = 'missing\\'
	f.JI:MergeStylePacks(); expect(f.icon(target).path:match('fabled$'))
	f.JI.global.customPacks.class.styles.custom = nil
	f.JI:MergeStylePacks(); expect(f.icon(target).path:match('fabled$'))
end)

test('actual AceDB profile switch, copy and reset refresh icons', function()
	local f = fixture()
	local target = f.frame('target'); f.ns.frames = { target = target }
	local original = f.JI.data:GetCurrentProfile()
	f.JI.db.ellesmereui.target.icon.enable = true
	f.JI:SetupEllesmereUI(); f.flush(); expect(f.icon(target):IsShown())
	f.JI.data:SetProfile('Other'); expect(not f.icon(target):IsShown())
	f.JI.data:CopyProfile(original); expect(f.icon(target):IsShown())
	f.JI.data:ResetProfile(); expect(not f.icon(target):IsShown())
end)

test('replacement frame retires the previous icon', function()
	local f = fixture()
	local old = f.frame('target'); f.ns.frames = { target = old }
	f.JI.db.ellesmereui.target.icon.enable = true
	f.JI:SetupEllesmereUI(); f.flush()
	local replacement = f.frame('target', 'ROGUE')
	f.ns.frames.target = replacement; f.ns.Engine.Attach(replacement, 'target'); f.flush()
	expect(not f.icon(old):IsShown()); expect(f.icon(replacement):IsShown())
	old:Hide(); old:Show(); expect(not f.icon(old):IsShown()); equal(#old.children, 1)
end)

test('horizontal reversal stays within each atlas cell and leaves shared coordinates unchanged', function()
	local f = fixture()
	for _, data in pairs(f.JI.dataHelper.class) do
		local original = {unpack(data.texCoords)}
		local reverse = {f.JI:GetIconTexCoords(data.texCoords, true)}
		for i = 1, 4 do equal(reverse[i], original[i + 4]); equal(reverse[i + 4], original[i]) end
		local normal = {f.JI:GetIconTexCoords(data.texCoords, false)}
		for i = 1, 8 do equal(normal[i], original[i]); equal(data.texCoords[i], original[i]) end
	end
	equal(table.concat({f.JI:GetIconTexCoords({0.1, 0.3, 0.2, 0.4}, true)}, ':'), '0.3:0.1:0.2:0.4')
	equal(f.JI:GetIconTexString('128:256:0:128', true), '256:128:0:128')
	equal(f.JI:GetIconTexString('128:256:0:128', false), '128:256:0:128')
end)

test('Reverse defaults off in every configurable icon and portrait tab', function()
	local f = fixture()
	equal(f.JI.db.chat.reverse, false)
	expect(f.JI.Options.args.chat.args.reverse)
	for _, module in ipairs({'blizzard', 'elvui', 'suf', 'ellesmereui'}) do
		for unit, settings in pairs(f.JI.db[module]) do
			for _, element in ipairs({'icon', 'portrait'}) do
				if settings[element] then
					equal(settings[element].reverse, false)
					local group = f.JI.Options.args[module].args[unit]
					if module ~= 'ellesmereui' then group = group.args[element] end
					expect(group.args.reverse)
				end
			end
		end
	end
end)

test('Ellesmere reverse is independent per frame, live in combat, copied and reset with profiles', function()
	local f = fixture()
	local player, target = f.frame('player', 'MAGE'), f.frame('target', 'MAGE')
	f.ns.frames = {player = player, target = target}
	f.JI.db.ellesmereui.player.icon.enable = true; f.JI.db.ellesmereui.target.icon.enable = true
	f.JI:SetupEllesmereUI(); f.flush()
	local controls = f.JI.Options.args.ellesmereui.args.target.args
	f.state.combat = true
	controls.reverse.set(nil, true)
	equal(f.icon(target).coords[1], 0.25); equal(f.icon(player).coords[1], 0.125)
	controls.reverse.set(nil, false); equal(f.icon(target).coords[1], 0.125)
	f.state.combat = false
	controls.reverse.set(nil, true); controls.applyAll.func()
	for _, key in ipairs(f.JI.dataHelper.ellesmereUnitList) do equal(f.JI.db.ellesmereui[key].icon.reverse, true) end
	equal(f.icon(player).coords[1], 0.25)
	local original = f.JI.data:GetCurrentProfile()
	f.JI.data:SetProfile('Reverse test'); equal(f.JI.db.ellesmereui.target.icon.reverse, false)
	f.JI.data:CopyProfile(original); equal(f.icon(target).coords[1], 0.25)
	f.JI.data:ResetProfile(); equal(f.JI.db.ellesmereui.target.icon.reverse, false)
end)

test('Blizzard icon and portrait reverse independently and General applies normal/reverse', function()
	local f = fixture()
	f.load('Core/Blizzard.lua')
	local target = f.frame('target'); target.unit = 'target'; target.portrait = target:CreateTexture()
	f.env.TargetFrame = target
	f.JI:SetupBlizzardFrames()
	local db = f.JI.db.blizzard.target
	db.icon.enable = true; db.portrait.enable = true
	f.JI:UpdateMedia()
	local controls = f.JI.Options.args.blizzard.args.target.args
	controls.icon.args.reverse.set(nil, true)
	equal(target.classIcon.icon.coords[1], 0.25); equal(target.classPortrait.portrait.coords[1], 0.125)
	controls.portrait.args.reverse.set(nil, true)
	equal(target.classPortrait.portrait.coords[1], 0.25)
	controls.icon.args.reverse.set(nil, false)
	equal(target.classIcon.icon.coords[1], 0.125); equal(target.classPortrait.portrait.coords[1], 0.25)
	local bulk = f.JI.Options.args.blizzard.args.general.args.icon.args
	for _, value in ipairs({'reverse', 'normal'}) do
		bulk.reverse.set(nil, value); expect(not bulk.confirmReverse.disabled())
		bulk.confirmReverse.func()
		for _, settings in pairs(f.JI.db.blizzard) do equal(settings.icon.reverse, value == 'reverse') end
		expect(bulk.confirmReverse.disabled())
	end
end)

test('SUF reverses icons and class portraits, and restores normal orientation', function()
	local f = fixture(); f.state.addons.ShadowedUnitFrames = true
	local modules = {}
	f.env.ShadowUF = { db = { profile = { units = { target = { portrait = { type = 'class' } } } } }, Layout = {} }
	function f.env.ShadowUF:RegisterModule(module, name) modules[name] = module end
	f.load('Core/SUF.lua')
	local target = f.frame('target'); target.unit = 'target'; target.unitType = 'target'; target.portrait = target:CreateTexture()
	function target:UnitClassToken() return f.world.target.class end
	function f.env.ShadowUF.Layout:Reload()
		modules.classportrait:Update(target); modules.classicon:Update(target)
	end
	modules.classportrait:OnLayoutApply(target); modules.classicon:OnPreLayoutApply(target)
	f.JI.db.suf.target.portrait.enable = true; f.JI.db.suf.target.icon.enable = true
	f.JI:UpdateSUF()
	local controls = f.JI.Options.args.suf.args.target.args
	controls.portrait.args.reverse.set(nil, true)
	equal(target.portrait.coords[1], 0.25); equal(target.classIcon.icon.coords[1], 0.125)
	controls.icon.args.reverse.set(nil, true); equal(target.classIcon.icon.coords[1], 0.25)
	controls.portrait.args.reverse.set(nil, false); equal(target.portrait.coords[1], 0.125)
	controls.icon.args.reverse.set(nil, false); equal(target.classIcon.icon.coords[1], 0.125)
	f.env.UnitRace = function() return 'Undead', 'Scourge' end
	f.JI.db.suf.target.portrait.style = 'fabledazeroth'
	f.JI.db.suf.target.icon.style = 'fabledregalia'
	f.JI:UpdateSUF()
	expect(target.portrait.path:find('Media\\Race\\fabledazeroth', 1, true))
	equal(target.portrait.coords[1], 0.875)
	expect(target.classIcon.icon.path:find('Media\\Class\\fabledregalia', 1, true))
	f.world.target.class = f.secret
	f.JI:UpdateSUF(); equal(target.portrait.path, '')
end)

test('ElvUI portrait reversal and existing reverse tags render the same atlas cell', function()
	local f = fixture(); f.state.addons.ElvUI = true
	local tags = {}
	local E = { UnitFrames = { PortraitUpdate = function() end } }
	function E:AddTag(name, _, fn) tags[name] = fn end
	function E:AddTagInfo() end
	E.IsSecretValue = function(_, value) return f.env.issecretvalue(value) end
	f.env.ElvUI = {E}
	f.load('Core/ElvUI.lua')
	local target = f.frame('target'); target.unit = 'target'; target.unitframeType = 'target'
	local portrait = target:CreateTexture(); portrait.__owner = target; portrait.useClassBase = true
	f.JI.dataHelper.elvuiUnitList.target.updateFunc = function() E.UnitFrames.PortraitUpdate(portrait) end
	f.JI.db.elvui.target.portrait.enable = true
	local reverse = f.JI.Options.args.elvui.args.target.args.portrait.args.reverse
	reverse.set(nil, true); equal(portrait.coords[1], 0.25)
	reverse.set(nil, false); equal(portrait.coords[1], 0.125)
	f.JI:BuildElvUITags()
	expect(tags['jiberish:class:fabled']('target', nil, '32'):find(':128:256:0:128|t', 1, true))
	expect(tags['jiberish:class:fabled:reverse']('target', nil, '32'):find(':256:128:0:128|t', 1, true))
	expect(tags['jiberish:class:fabledcore']('target', nil, '32'):find(':32:32:0:0:2048:2048:256:512:0:256|t', 1, true))
	expect(tags['jiberish:class:fabledcore:reverse']('target', nil, '32'):find(':2048:2048:512:256:0:256|t', 1, true))
end)

local function checkChat(f)
	f.load('Core/Chat.lua')
	local chat = f.frame('player'); function chat:GetID() return 1 end
	local received
	chat.AddMessage = function(_, message) received = message end
	f.env.CHAT_FRAMES = {'ChatFrame1'}; f.env.ChatFrame1 = chat
	f.JI.hooks = {}
	function f.JI:IsHooked(frame) return self.hooks[frame] ~= nil end
	function f.JI:RawHook(frame, name, fn)
		self.hooks[frame] = {[name] = frame[name]}; frame[name] = fn
	end
	f.env.GetPlayerInfoByGUID = function() return 'Mage', 'MAGE' end
	f.JI.AuthorCache['Tester-Realm'] = 'guid'
	f.JI.db.chat.enable = true; f.JI:SetupChat()
	local message = '|Hplayer:Tester-Realm:1|h[Tester]|h hello'
	chat:AddMessage(message); expect(received:find(':128:256:0:128|t', 1, true))
	f.JI.Options.args.chat.args.reverse.set(nil, true)
	chat:AddMessage(message); expect(received:find(':256:128:0:128|t', 1, true))
	f.JI.Options.args.chat.args.reverse.set(nil, false)
	chat:AddMessage(message); expect(received:find(':128:256:0:128|t', 1, true))
	f.JI.db.chat.style = 'fabledcore'
	chat:AddMessage(message); expect(received:find(':2048:2048:256:512:0:256|t', 1, true))
	f.JI.Options.args.chat.args.reverse.set(nil, true)
	chat:AddMessage(message); expect(received:find(':2048:2048:512:256:0:256|t', 1, true))
	f.JI.Options.args.chat.args.reverse.set(nil, false)
	f.env.GetPlayerInfoByGUID = function() return 'Mage', 'MAGE', 'Undead', 'Scourge' end
	f.JI.db.chat.style = 'fabledazeroth'
	chat:AddMessage(message)
	expect(received:find('Media\\Race\\fabledazeroth', 1, true))
	expect(received:find(':2048:2048:1792:2048:0:256|t', 1, true))
	f.env.GetPlayerInfoByGUID = function() return 'Mage', 'MAGE' end
	chat:AddMessage(message); equal(received, message)
	if f.env.issecretvalue then
		chat:AddMessage(f.secret); equal(received, f.secret)
	end
end

test('Chat reverse affects new messages without reinstalling chat hooks', function()
	checkChat(fixture())
end)

for _, client in ipairs({'modern', 'legacy'}) do
	test(client..' Classic APIs support initialization, standalone options and Chat reversal', function()
		local f = fixture(false, client)
		equal(f.JI.Version, '1.4.7')
		expect(not f.JI:IsAddOnEnabled('ShadowedUnitFrames'))
		f.state.addons.ShadowedUnitFrames = true
		expect(f.JI:IsAddOnEnabled('ShadowedUnitFrames'))
		f.JI:SetupEllesmereUI(); f.flush()
		expect(f.JI.Options.args.ellesmereui.hidden())
		local opened
		f.JI.Libs.ACD.Open = function(_, name) opened = name end
		f.JI:ToggleOptions(); equal(opened, 'JiberishIcons')
		checkChat(f)
	end)
end

test('Fabled packs register independently and race lookup covers every atlas cell', function()
	local f = fixture()
	equal(f.JI.mergedStylePacks.class.styles.fabledclass.name, 'Fabled Class')
	local classCount = 0
	for class, expected in pairs(f.JI.dataHelper.class) do
		local icon, path, size = f.JI:GetIdentityIcon(class, nil, 'fabledclass')
		equal(icon, expected); equal(size, 2048)
		equal(path, f.JI.defaultStylePacks.class.path..'fabledclass')
		classCount = classCount + 1
	end
	equal(classCount, 13)
	equal(f.JI.Options.args.chat.args.style.values().fabledclass, 'Fabled Class')
	equal(f.JI.mergedStylePacks.class.styles.fabledregalia.name, 'Fabled Regalia')
	equal(f.JI.mergedStylePacks.race.styles.fabledazeroth.name, 'Fabled Azeroth')
	equal(f.JI.mergedStylePacks.class.styles.fabledazeroth, nil)
	equal(#f.JI.dataHelper.raceOrder, 26)
	local cells = {}
	for _, entry in ipairs(f.JI.dataHelper.raceOrder) do
		local icon, path = f.JI:GetIdentityIcon('MAGE', entry[1], 'fabledazeroth')
		expect(icon); expect(path:find('Media\\Race\\fabledazeroth', 1, true))
		expect(not cells[icon.texString]); cells[icon.texString] = true
		for _, coordinate in ipairs(icon.texCoords) do expect(coordinate >= 0 and coordinate <= 1) end
	end
	equal(f.JI:GetIdentityIcon('MAGE', 'Earthen', 'fabledazeroth'), f.JI.dataHelper.race.EARTHENDWARF)
	equal(f.JI:GetIdentityIcon('MAGE', 'Undead', 'fabledazeroth'), f.JI.dataHelper.race.SCOURGE)
	equal(f.JI:GetIdentityIcon('MAGE', 'Haranir', 'fabledazeroth').texString, '128:256:384:512')
	equal(f.JI:GetIdentityIcon('MAGE', nil, 'fabledazeroth'), nil)
	equal(f.JI:GetIdentityIcon('MAGE', f.secret, 'fabledazeroth'), nil)
	local values = f.JI.Options.args.ellesmereui.args.target.args.style.values()
	equal(values.fabledclass, 'Fabled Class')
	equal(values.fabledregalia, 'Fabled Regalia'); expect(values.fabledazeroth)
	expect(f.JI.Options.args.StylePacks.args.RaceTab.args.fabledazeroth)
end)

test('Ellesmere switches race cells on identity changes and hides restricted races', function()
	local f = fixture()
	local target = f.frame('target', 'MAGE')
	f.ns.frames = { target = target }
	local race = 'Scourge'
	f.env.UnitRace = function() return 'Race', race end
	local db = f.JI.db.ellesmereui.target.icon
	db.enable, db.style = true, 'fabledazeroth'
	f.JI:SetupEllesmereUI(); f.flush()
	equal(f.icon(target).coords[1], 0.875)
	expect(f.icon(target).path:find('Media\\Race\\fabledazeroth', 1, true))
	race = 'Haranir'; f.ns.Engine.RepaintAll(target)
	equal(f.icon(target).coords[1], 0.125); equal(f.icon(target).coords[2], 0.375)
	db.reverse = true; f.ns.Engine.RepaintAll(target)
	equal(f.icon(target).coords[1], 0.25)
	race = f.secret; f.ns.Engine.RepaintAll(target); expect(not f.icon(target):IsShown())
	race = nil; f.ns.Engine.RepaintAll(target); expect(not f.icon(target):IsShown())
	race = 'Human'; f.ns.Engine.RepaintAll(target); expect(f.icon(target):IsShown())
	db.style = 'fabledregalia'; f.JI:UpdateEllesmereUI()
	expect(f.icon(target).path:find('Media\\Class\\fabledregalia', 1, true))
end)

test('Blizzard race icon and class portrait can select separate packs', function()
	local f = fixture(); f.load('Core/Blizzard.lua')
	local target = f.frame('target'); target.unit = 'target'; target.portrait = target:CreateTexture()
	f.env.TargetFrame = target
	f.env.UnitRace = function() return 'Race', 'Vulpera' end
	f.JI:SetupBlizzardFrames()
	local db = f.JI.db.blizzard.target
	db.icon.enable, db.icon.style = true, 'fabledazeroth'
	db.portrait.enable, db.portrait.style = true, 'fabledregalia'
	f.JI:UpdateMedia()
	expect(target.classIcon.icon.path:find('Media\\Race\\fabledazeroth', 1, true))
	equal(target.classIcon.icon.coords[1], 0.875); equal(target.classIcon.icon.coords[2], 0.25)
	expect(target.classPortrait.portrait.path:find('Media\\Class\\fabledregalia', 1, true))
	equal(target.classPortrait.portrait.coords[1], 0.125)
end)

test('Missing race texture falls back to the class texture and class coordinates together', function()
	local f = fixture()
	f.JI.mergedStylePacks.race.styles.fabledazeroth.path = 'missing\\'
	f.JI:ClearIconStyleCache()
	local icon, path, textureSize = f.JI:GetIdentityIcon('MAGE', 'Scourge', 'fabledazeroth')
	equal(icon, f.JI.dataHelper.class.MAGE)
	equal(path, f.JI.defaultStylePacks.class.path..'fabled')
	equal(textureSize, 1024)
	expect(f.JI:GetIconMarkup(icon, path, 32, false, textureSize):find(':1024:1024:128:256:0:128|t', 1, true))
end)

test('Blizzard Apply To All can select and enable race portraits', function()
	local f = fixture()
	local controls = f.JI.Options.args.blizzard.args.general.args.portrait.args
	local info = {'blizzard', 'general', 'portrait', 'style'}
	controls.style.set(info, 'fabledazeroth')
	equal(controls.style.get(info), 'fabledazeroth')
	controls.confirmStyle.func(info)
	for _, settings in pairs(f.JI.db.blizzard) do equal(settings.portrait.style, 'fabledazeroth') end
	info[4] = 'enable'
	controls.enable.set(info, 'enable'); controls.confirmEnable.func(info)
	for _, settings in pairs(f.JI.db.blizzard) do equal(settings.portrait.enable, true) end
end)

test('ElvUI race tags support size, reversal and unavailable identity', function()
	local f = fixture(); f.state.addons.ElvUI = true
	local tags = {}; local E = { UnitFrames = { PortraitUpdate = function() end } }
	function E:AddTag(name, _, fn) tags[name] = fn end
	function E:AddTagInfo() end
	f.env.ElvUI = {E}; f.load('Core/ElvUI.lua')
	f.frame('target'); local race = 'Haranir'
	f.env.UnitRace = function() return 'Race', race end
	f.JI:BuildElvUITags()
	local normal = tags['jiberish:race:fabledazeroth']
	expect(normal('target', nil, '48'):find(':48:48:0:0:2048:2048:256:512:768:1024|t', 1, true))
	expect(tags['jiberish:race:fabledazeroth:reverse']('target', nil, '48'):find(':512:256:768:1024|t', 1, true))
	race = f.secret; equal(normal('target'), nil)
	race = 'UnknownRace'; equal(normal('target'), nil)
end)

test('Forever beta supports race icons and chat with modern APIs on a non-Mainline client', function()
	local f = fixture(true, 'forever')
	equal(select(4, f.env.GetBuildInfo()), 16001)
	local target = f.frame('target'); f.ns.frames = {target = target}
	f.JI.db.ellesmereui.target.icon.enable = true
	f.JI.db.ellesmereui.target.icon.style = 'fabledazeroth'
	f.env.UnitRace = function() return 'Night Elf', 'NightElf' end
	f.JI:SetupEllesmereUI(); f.flush()
	expect(f.icon(target):IsShown()); equal(f.icon(target).coords[1], 0.25)
	f.env.UnitRace = function() return 'Restricted', f.secret end
	f.ns.Engine.RepaintAll(target); expect(not f.icon(target):IsShown())
	checkChat(f)
end)

test('Forever skips enabled but unloaded optional integrations', function()
	local f = fixture(false, 'forever')
	f.env.C_AddOns.GetAddOnEnableState = function() return 2 end
	-- Init cached the API at load, so reload it with an enabled-only client state.
	f.load('Init.lua', 'JiberishIcons', {})
	expect(not f.JI:IsAddOnEnabled('ElvUI'))
	expect(not f.JI:IsAddOnEnabled('EllesmereUIUnitFrames'))
	f.state.addons.ElvUI = true; expect(f.JI:IsAddOnEnabled('ElvUI'))
end)

test('HD packs keep normalized cells and scale markup/previews without changing older packs', function()
	local f = fixture()
	for _, style in ipairs({'fabledclass', 'fabledcore', 'fabledregalia', 'fabledazeroth'}) do
		local icon, path, size = f.JI:GetIdentityIcon('MAGE', 'Haranir', style)
		equal(size, 2048)
		local left, right, top, bottom = icon.texString:match('^(%d+):(%d+):(%d+):(%d+)$')
		local markup = f.JI:GetIconMarkup(icon, path, 128, false, size)
		expect(markup:find(':128:128:0:0:2048:2048:', 1, true))
		equal(f.JI:GetIconTexString(icon.texString, false, size), string.format('%d:%d:%d:%d', left*2, right*2, top*2, bottom*2))
		equal(f.JI:GetIconTexString(icon.texString, true, size), string.format('%d:%d:%d:%d', right*2, left*2, top*2, bottom*2))
		equal(icon.texCoords[1], left/1024)
	end
	local groups = f.JI.Options.args.StylePacks.args
	expect(groups.ClassTab.args.fabledclass.args.icons.name():find(':2048:2048:', 1, true))
	expect(groups.ClassTab.args.fabledcore.args.icons.name():find(':2048:2048:', 1, true))
	expect(groups.ClassTab.args.fabledregalia.args.icons.name():find(':2048:2048:', 1, true))
	expect(groups.RaceTab.args.fabledazeroth.args.HARANIR.name:find(':2048:2048:256:512:768:1024|t', 1, true))
	for _, style in ipairs({'fabled', 'fableddimension', 'fabledmyth', 'fabledpixels', 'fabledpixelsv2', 'fabledrealm', 'fabledrealmv2', 'intothevoid'}) do
		local oldIcon, oldPath, oldSize = f.JI:GetIdentityIcon('MAGE', nil, style)
		equal(oldSize, 1024)
		expect(f.JI:GetIconMarkup(oldIcon, oldPath, 128, false, oldSize):find(':1024:1024:128:256:0:128|t', 1, true))
		equal(oldIcon.texString, '128:256:0:128')
	end
end)

test('specialization pack exposes 40 distinct cells, including Devourer, with no chat entry', function()
	local f = fixture()
	equal(#f.JI.dataHelper.specOrder, 40)
	local seen = {}
	for _, entry in ipairs(f.JI.dataHelper.specOrder) do
		local icon, path, size = f.JI:GetIdentityIcon(entry[3], nil, 'fabledspecializations', entry[1])
		expect(icon and not seen[icon.texString]); seen[icon.texString] = true
		expect(path:find('Media\\Spec\\fabledspecializations', 1, true)); equal(size, 2048)
	end
	local devourer, path, size = f.JI:GetIdentityIcon('DEMONHUNTER', nil, 'fabledspecializations', 1480)
	equal(devourer.texString, '896:1024:512:640')
	expect(f.JI:GetIconMarkup(devourer, path, 32, true, size):find(':2048:1792:1024:1280|t', 1, true))
	equal(f.JI:GetIdentityIcon('MAGE', nil, 'fabledspecializations', 1480), nil)
	equal(f.JI:GetIdentityIcon('MAGE', nil, 'fabledspecializations', f.secret), nil)
	local values = f.JI.Options.args.ellesmereui.args.player.args.style.values()
	equal(values.fabledspecializations, 'Fabled Specializations (Spec)')
	equal(f.JI.Options.args.chat.args.style.values().fabledspecializations, nil)
	expect(f.JI.Options.args.StylePacks.args.SpecTab.args.fabledspecializations.args['1480'])
	equal(f.env.JiberishFabledIcons, f.env.JiberishIcons)
end)

test('player specialization supports modern and legacy APIs, self aliases and restricted results', function()
	local f = fixture(); f.world.player.class = 'MAGE'
	local index, spec = 2, 63
	f.env.C_SpecializationInfo = {
		GetSpecialization = function() return index end,
		GetSpecializationInfo = function(i) equal(i, 2); return spec end,
	}
	equal(f.JI:GetUnitIcon('player', 'fabledspecializations'), f.JI.dataHelper.specialization[63])
	f.frame('target', 'MAGE'); f.env.UnitIsUnit = function(unit) return unit == 'target' end
	equal(f.JI:GetUnitIcon('target', 'fabledspecializations'), f.JI.dataHelper.specialization[63])
	index = f.secret; equal(f.JI:GetUnitIcon('player', 'fabledspecializations'), nil)
	index = 2; spec = f.secret; equal(f.JI:GetUnitIcon('player', 'fabledspecializations'), nil)
	spec = 0; equal(f.JI:GetUnitIcon('player', 'fabledspecializations'), nil)
	spec = 64
	f.env.GetSpecialization = f.env.C_SpecializationInfo.GetSpecialization
	f.env.GetSpecializationInfo = f.env.C_SpecializationInfo.GetSpecializationInfo
	f.env.C_SpecializationInfo = nil
	equal(f.JI:GetUnitIcon('player', 'fabledspecializations'), f.JI.dataHelper.specialization[64])
	f.env.GetSpecialization = nil; f.env.GetSpecializationInfo = nil
	equal(f.JI:GetUnitIcon('player', 'fabledspecializations'), nil)
	local count = #f.objects; f.JI:SetupSpecializationIcons(); equal(#f.objects, count)
end)

test('target specialization uses available data and hides unknown, stale-class and secret results', function()
	local f = fixture(); f.frame('target', 'SHAMAN')
	local inspected, cached, reads = 264, 262, 0
	f.env.C_SpecializationInfo = {GetInspectSpecialization = function() return inspected end}
	local raid = f.env.LibStub:NewLibrary('LibOpenRaid-1.0', 1)
	raid.GetUnitInfo = function() reads = reads + 1; return {specId = cached} end
	equal(f.JI:GetUnitIcon('target', 'fabledspecializations'), f.JI.dataHelper.specialization[264]); equal(reads, 0)
	inspected = 0
	equal(f.JI:GetUnitIcon('target', 'fabledspecializations'), f.JI.dataHelper.specialization[262]); equal(reads, 1)
	inspected = f.secret; equal(f.JI:GetUnitIcon('target', 'fabledspecializations'), nil); equal(reads, 1)
	inspected = 0; cached = f.secret; equal(f.JI:GetUnitIcon('target', 'fabledspecializations'), nil)
	cached = 63; equal(f.JI:GetUnitIcon('target', 'fabledspecializations'), nil)
	cached = 264; f.env.UnitName = function() return f.secret end
	equal(f.JI:GetUnitIcon('target', 'fabledspecializations'), nil)
	f.world.target.player = false; equal(f.JI:GetUnitIcon('target', 'fabledspecializations'), nil)
end)

test('missing specialization artwork falls back to class art and class coordinates together', function()
	local f = fixture(); f.frame('target', 'MAGE')
	f.JI.mergedStylePacks.spec.styles.fabledspecializations.path = 'missing\\'
	f.JI:ClearIconStyleCache()
	local icon, path, size = f.JI:GetUnitIcon('target', 'fabledspecializations')
	equal(icon, f.JI.dataHelper.class.MAGE); equal(size, 1024)
	equal(path, f.JI.defaultStylePacks.class.path..'fabled')
end)

test('specialization events repaint Ellesmere icons in combat without moving frames', function()
	local f = fixture(); local player = f.frame('player', 'MAGE'); f.ns.frames = {player = player}
	local spec = 63
	f.env.C_SpecializationInfo = {GetSpecialization = function() return 1 end, GetSpecializationInfo = function() return spec end}
	local db = f.JI.db.ellesmereui.player.icon; db.enable = true; db.style = 'fabledspecializations'
	f.JI:SetupEllesmereUI(); f.flush(); f.JI:SetupSpecializationIcons()
	local count = #f.objects; f.JI:SetupSpecializationIcons(); equal(#f.objects, count)
	equal(f.icon(player).coords[1], .375)
	f.state.combat = true; spec = 64; f.fire('PLAYER_SPECIALIZATION_CHANGED', 'player')
	equal(f.icon(player).coords[1], .5); expect(f.icon(player):IsShown())
	spec = 0; f.fire('PLAYER_TALENT_UPDATE'); expect(not f.icon(player):IsShown())
	spec = 62; f.fire('PLAYER_TALENT_UPDATE'); expect(f.icon(player):IsShown()); equal(f.icon(player).coords[1], .25)
end)

test('Blizzard spec icons and portraits refresh during combat and hide unavailable specs', function()
	local f = fixture(); f.load('Core/Blizzard.lua')
	local target = f.frame('target', 'MAGE'); target.unit = 'target'; target.portrait = target:CreateTexture(); f.env.TargetFrame = target
	local spec = 63; f.env.GetInspectSpecialization = function() return spec end
	f.JI:SetupBlizzardFrames()
	local db = f.JI.db.blizzard.target
	db.icon.enable = true; db.icon.style = 'fabledspecializations'
	db.portrait.enable = true; db.portrait.style = 'fabledspecializations'; db.portrait.reverse = true
	f.JI:UpdateMedia(); equal(target.classIcon.icon.coords[1], .375)
	f.state.combat = true; spec = 64; f.JI:RefreshSpecializationIcons()
	equal(target.classIcon.icon.coords[1], .5); equal(target.classPortrait.portrait.coords[1], .625)
	spec = 0; f.JI:RefreshSpecializationIcons()
	expect(not target.classIcon:IsShown()); expect(not target.classPortrait:IsShown()); expect(target.portrait:IsShown())
end)

test('ElvUI spec tags and portraits refresh with correct size, reversal and unknown handling', function()
	local f = fixture(); f.state.addons.ElvUI = true
	local tags, events = {}, {}; local E = {UnitFrames = {PortraitUpdate = function() end}}
	function E:AddTag(name, event, fn) tags[name] = fn; events[name] = event end
	function E:AddTagInfo() end
	f.env.ElvUI = {E}; f.load('Core/ElvUI.lua')
	local target = f.frame('target', 'SHAMAN'); target.unit = 'target'; target.unitframeType = 'target'
	local portrait = target:CreateTexture(); portrait.__owner = target; portrait.useClassBase = true
	local spec = 264; f.env.GetInspectSpecialization = function() return spec end
	local db = f.JI.db.elvui.target.portrait; db.enable = true; db.style = 'fabledspecializations'
	E.UnitFrames.PortraitUpdate(portrait); equal(portrait.coords[1], .375)
	f.JI:BuildElvUITags(); equal(events['jiberish:spec:fabledspecializations'], .5)
	expect(tags['jiberish:spec:fabledspecializations']('target', nil, '32'):find(':2048:2048:768:1024:768:1024|t', 1, true))
	expect(tags['jiberish:spec:fabledspecializations:reverse']('target', nil, '32'):find(':1024:768:768:1024|t', 1, true))
	f.state.combat = true; spec = 262; f.JI:RefreshSpecializationIcons(); equal(portrait.coords[1], .125)
	spec = 0; f.JI:RefreshSpecializationIcons(); equal(portrait.path, nil)
	equal(tags['jiberish:spec:fabledspecializations']('target'), nil)
end)

test('SUF specialization repaint changes textures without reloading layout in combat', function()
	local f = fixture(); f.state.addons.ShadowedUnitFrames = true
	local modules = {}
	f.env.ShadowUF = {db = {profile = {units = {target = {portrait = {type = 'class'}}}}}, Layout = {}}
	function f.env.ShadowUF:RegisterModule(module, name) modules[name] = module end
	f.load('Core/SUF.lua')
	local target = f.frame('target', 'MAGE'); target.unit = 'target'; target.unitType = 'target'; target.portrait = target:CreateTexture()
	function target:UnitClassToken() return f.world.target.class end
	local spec = 63; f.env.GetInspectSpecialization = function() return spec end
	modules.classportrait:OnLayoutApply(target); modules.classicon:OnPreLayoutApply(target)
	local db = f.JI.db.suf.target
	db.icon.enable = true; db.icon.style = 'fabledspecializations'; db.portrait.enable = true; db.portrait.style = 'fabledspecializations'
	modules.classportrait:Update(target); modules.classicon:Update(target)
	f.state.combat = true; spec = 64; f.JI:RefreshSpecializationIcons()
	equal(target.classIcon.icon.coords[1], .5); equal(target.portrait.coords[1], .5)
	spec = 0; f.JI:RefreshSpecializationIcons(); expect(not target.classIcon:IsShown()); equal(target.portrait.path, '')
end)

test('JiberishIcons rename preserves profiles, aliases and owned custom texture paths', function()
	local saved = {
		profileKeys = {['Tester - Realm'] = 'Raid'},
		profiles = {Raid = {chat = {enable = true, style = 'fabledregalia', reverse = true}}},
		global = {customPacks = {class = {styles = {
			old = {name = 'Old', path = [[Interface\AddOns\ElvUI_JiberishIcons\Media\Custom\]], fileName = 'old'},
			external = {name = 'External', path = [[Interface\AddOns\MyArt\]], fileName = 'custom'},
		}}}},
	}
	local f = fixture(true, nil, saved)
	equal(f.JI.AddOnName, 'JiberishIcons')
	equal(f.JI.MediaPath, [[Interface\AddOns\JiberishIcons\Media\]])
	equal(f.env.JiberishIcons, f.env.ElvUI_JiberishIcons)
	equal(f.env.JiberishIcons, f.env.JiberishFabledIcons)
	equal(f.JI.data:GetCurrentProfile(), 'Raid')
	equal(f.JI.db.chat.style, 'fabledregalia'); equal(f.JI.db.chat.reverse, true)
	equal(f.JI.global.customPacks.class.styles.old.path, [[Interface\AddOns\JiberishIcons\Media\Custom\]])
	equal(f.JI.global.customPacks.class.styles.external.path, [[Interface\AddOns\MyArt\]])
end)

test('all 40 ElvUI specialization tags use the renamed texture, both orientations and sizes', function()
	local f = fixture(); f.state.addons.ElvUI = true
	local tags, infos = {}, {}; local E = {UnitFrames = {PortraitUpdate = function() end}}
	function E:AddTag(name, event, fn) tags[name] = fn end
	function E:AddTagInfo(name, group, help) infos[name] = help end
	f.env.ElvUI = {E}; f.load('Core/ElvUI.lua'); f.JI:BuildElvUITags()
	local spec
	f.env.GetSpecialization = function() return 1 end
	f.env.GetSpecializationInfo = function() return spec end
	for id, icon in pairs(f.JI.dataHelper.specialization) do
		spec = id; f.world.player.class = icon.class
		for _, reverse in ipairs({false, true}) do
			local name = 'jiberish:spec:fabledspecializations'..(reverse and ':reverse' or '')
			expect(infos[name] and infos[name]:find(name, 1, true))
			for _, size in ipairs({1, 32, 64, 128}) do
				local actual = tags[name]('player', nil, tostring(size))
				local expected = f.JI:GetIconMarkup(icon, [[Interface\AddOns\JiberishIcons\Media\Spec\fabledspecializations]], size, reverse, 2048)
				equal(actual, expected)
			end
			equal(tags[name]('player', nil, '999'), tags[name]('player', nil, '64'))
		end
	end
	spec = f.secret; equal(tags['jiberish:spec:fabledspecializations']('player'), nil)
end)

test('modern Classic talent allocations drive Ellesmere spec art without a selected specialization', function()
	local f = fixture(true, 'forever')
	-- Modernized Classic has namespaced APIs but still uses talent tab counters.
	f.env.GetBuildInfo = function() return '1.15.9', '', '', 11509 end
	local player = f.frame('player', 'PALADIN'); f.ns.frames = {player = player}
	local points = {0, 0, 5}
	f.env.C_SpecializationInfo = {
		GetSpecialization = function() return 0 end,
		GetSpecializationInfo = function(i, inspect, pet)
			equal(inspect, false); equal(pet, false)
			-- Modern Classic uses return 7 for spent points, return 9 for previews.
			return ({831, 839, 855})[i], 'Localized tree', '', 1, nil, nil, points[i], '', 99
		end,
	}
	local db = f.JI.db.ellesmereui.player.icon; db.enable = true; db.style = 'fabledspecializations'
	f.JI:SetupEllesmereUI(); f.flush(); f.JI:SetupSpecializationIcons()
	local function matches(id)
		expect(f.icon(player):IsShown())
		equal(f.icon(player).path, f.JI.defaultStylePacks.spec.path..'fabledspecializations')
		local expected = f.JI.dataHelper.specialization[id].texCoords
		for i, value in ipairs(expected) do equal(f.icon(player).coords[i], value) end
	end
	matches(70)
	f.state.combat = true
	points = {6, 0, 5}; f.fire('PLAYER_TALENT_UPDATE'); matches(65)
	points = {0, 7, 0}; f.fire('ACTIVE_TALENT_GROUP_CHANGED'); matches(66)
	points = {0, 0, 0}; f.fire('CHARACTER_POINTS_CHANGED')
	expect(f.icon(player):IsShown())
	equal(f.icon(player).path, f.JI.defaultStylePacks.class.path..'fabledregalia')
	for i, value in ipairs(f.JI.dataHelper.class.PALADIN.texCoords) do equal(f.icon(player).coords[i], value) end
	points = {1, 0, 2}; f.fire('PLAYER_LEVEL_UP'); matches(70)
end)

test('Classic talent tab layouts map every tree without relying on localized names or Retail IDs', function()
	local expected = {
		DEATHKNIGHT = {250, 251, 252}, DRUID = {102, 103, 105}, HUNTER = {253, 254, 255},
		MAGE = {62, 63, 64}, PALADIN = {65, 66, 70}, PRIEST = {256, 257, 258},
		ROGUE = {259, 260, 261}, SHAMAN = {262, 263, 264}, WARLOCK = {265, 266, 267},
		WARRIOR = {71, 72, 73},
	}
	for _, layout in ipairs({'vanilla', 'wrath'}) do
		local f = fixture(true, 'legacy')
		local active = 1
		f.env.GetActiveTalentGroup = function() return 2 end
		f.env.GetTalentTabInfo = function(i, inspect, pet, group)
			equal(inspect, false); equal(pet, false); equal(group, 2)
			local points = i == active and 5 or 0
			if layout == 'vanilla' then return 'Localized tree', 'texture', points, 'background' end
			return 700+i, 'Localized tree', 'description', 'texture', points, 'background', 99
		end
		for class, specs in pairs(expected) do
			f.world.player.class = class
			for index, id in ipairs(specs) do
				active = index
				equal(f.JI:GetUnitIcon('player', 'fabledspecializations'), f.JI.dataHelper.specialization[id])
			end
		end
	end
end)

test('Classic talent fallback handles ties, unspent points, self aliases and unavailable data', function()
	local f = fixture(true, 'forever'); f.world.player.class = 'PALADIN'
	f.env.GetBuildInfo = function() return '1.15.9', '', '', 11509 end
	local points = {0, 0, 0}
	f.env.GetTalentTabInfo = function(i) return 'Localized tree', 'texture', points[i] end
	local icon, path, size = f.JI:GetUnitIcon('player', 'fabledspecializations')
	equal(icon, f.JI.dataHelper.class.PALADIN); equal(size, 2048)
	equal(path, f.JI.defaultStylePacks.class.path..'fabledregalia')
	points = {5, 5, 0}; equal(f.JI:GetUnitIcon('player', 'fabledspecializations'), icon)
	points = {5, 5, 6}; equal(f.JI:GetUnitSpecialization('player'), 70)
	points = {5, 5, 5}; equal(f.JI:GetUnitIcon('player', 'fabledspecializations'), icon)
	points = {f.secret, 0, 5}; equal(f.JI:GetUnitIcon('player', 'fabledspecializations'), nil)
	points = {nil, 0, 5}; equal(f.JI:GetUnitIcon('player', 'fabledspecializations'), nil)
	points = {0, 0, 5}
	f.frame('target', 'PALADIN'); f.env.UnitIsUnit = function() return true end
	equal(f.JI:GetUnitSpecialization('target'), 70)
	f.env.UnitIsUnit = function() return false end
	equal(f.JI:GetUnitIcon('target', 'fabledspecializations'), nil)
	f.env.UnitIsUnit = function() return f.secret end
	equal(f.JI:GetUnitIcon('target', 'fabledspecializations'), nil)
end)

test('Classic talent event registration works without Retail specialization APIs or unsupported events', function()
	local f = fixture(true, 'legacy'); local player = f.frame('player', 'MAGE'); f.ns.frames = {player = player}
	local active = 1
	f.env.GetTalentTabInfo = function(i) return 'Localized tree', 'texture', i == active and 3 or 0 end
	f.env.C_EventUtils = {IsEventValid = function(event) return event ~= 'PLAYER_SPECIALIZATION_CHANGED' end}
	local db = f.JI.db.ellesmereui.player.icon; db.enable = true; db.style = 'fabledspecializations'
	f.JI:SetupEllesmereUI(); f.flush(); f.JI:SetupSpecializationIcons()
	for _, obj in ipairs(f.objects) do expect(not obj.events.PLAYER_SPECIALIZATION_CHANGED) end
	local count = #f.objects; f.JI:SetupSpecializationIcons(); equal(#f.objects, count)
	active = 3; f.fire('CHARACTER_POINTS_CHANGED')
	expect(f.icon(player):IsShown()); equal(f.icon(player).coords[1], .5)
end)

test('Retail and Mists use their selected specialization even if talent-tab APIs exist', function()
	for _, project in ipairs({1, 19}) do
		local f = fixture(); f.env.WOW_PROJECT_ID = project; f.world.player.class = 'MAGE'
		f.env.GetBuildInfo = function() return '', '', '', project == 1 and 120100 or 50504 end
		f.env.GetSpecialization = function() return 2 end
		f.env.GetSpecializationInfo = function(i) equal(i, 2); return 63 end
		f.env.GetTalentTabInfo = function() error('Selected-specialization clients must not count tree points') end
		equal(f.JI:GetUnitIcon('player', 'fabledspecializations'), f.JI.dataHelper.specialization[63])
	end
end)

-- Forever 1.60.1.70124 uses C_Traits groups, as in Blizzard's Camelot headers.
-- The live Paladin report is Holy=6 with no currency rows for the other groups.
local function foreverTalentsFixture()
	local f = fixture(true, 'forever')
	f.env.GetBuildInfo = function() return '1.60.1', '70124', '', 16001 end
	f.state.activeGroup, f.state.staged = 1, false
	f.state.points = {[101] = {6, 0, 0}, [202] = {0, 0, 8}}
	f.env.C_SpecializationInfo = {
		GetActiveSpecGroup = function() return f.state.activeGroup end,
		GetCombatConfigIDForSpecGroup = function(group) return group == 1 and 101 or 202 end,
		GetSpecialization = function() return 1 end,
		GetSpecializationInfo = function() return 1486, 'Paladin', '', 1, nil, nil, 0 end,
	}
	f.env.GetTalentTabInfo = function() return 1486, 'Paladin', '', 1, 0 end
	f.env.C_ClassTalents = {GetActiveConfigID = function() return f.state.activeGroup == 1 and 101 or 202 end}
	f.env.C_Traits = {
		ConfigHasStagedChanges = function() return f.state.staged end,
		GetConfigInfo = function(configID) return {ID = configID, treeIDs = {1000}} end,
		GetGroupDisplayInfoByTreeID = function(treeID)
			equal(treeID, 1000)
			return {{groupID = 41, displayName = 'Holy'}, {groupID = 42, displayName = 'Protection'},
				{groupID = 43, displayName = 'Retribution'}}
		end,
		GetGroupCurrencyInfo = function(configID, ids)
			equal(#ids, 3); equal(ids[1], 41); equal(ids[2], 42); equal(ids[3], 43)
			local groups = {}
			-- Response order need not match header order. Unspent groups are absent.
			for index = 3, 1, -1 do
				local spent = f.state.points[configID][index]
				if spent ~= 0 then
					groups[#groups+1] = {traitNodeGroupID = 40+index, currencyInfos = {{spent = spent}}}
				end
			end
			return groups
		end,
	}
	local player = f.frame('player', 'PALADIN'); f.ns.frames = {player = player}
	local db = f.JI.db.ellesmereui.player.icon; db.enable = true; db.style = 'fabledspecializations'
	return f, player
end

test('Forever live Holy 6 with absent unspent groups paints Holy instead of the class crest', function()
	local f, player = foreverTalentsFixture()
	f.JI:SetupEllesmereUI(); f.flush(); f.JI:SetupSpecializationIcons()
	equal(f.JI:GetUnitSpecialization('player'), 65)
	expect(f.icon(player):IsShown())
	equal(f.icon(player).path, f.JI.defaultStylePacks.spec.path..'fabledspecializations')
	for i, value in ipairs(f.JI.dataHelper.specialization[65].texCoords) do equal(f.icon(player).coords[i], value) end
	f.state.combat = true
	f.state.points[101] = {6, 9, 1}; f.fire('TRAIT_TREE_CURRENCY_INFO_UPDATED', 1000)
	for i, value in ipairs(f.JI.dataHelper.specialization[66].texCoords) do equal(f.icon(player).coords[i], value) end
	f.state.activeGroup = 2; f.fire('ACTIVE_TALENT_GROUP_CHANGED', 2, 1)
	for i, value in ipairs(f.JI.dataHelper.specialization[70].texCoords) do equal(f.icon(player).coords[i], value) end
end)

test('Forever keeps committed spec during previews and refreshes after trait commits', function()
	local f, player = foreverTalentsFixture()
	f.JI:SetupEllesmereUI(); f.flush(); f.JI:SetupSpecializationIcons()
	f.state.staged = true; f.state.points[101] = {6, 10, 0}
	f.fire('TRAIT_TREE_CURRENCY_INFO_UPDATED', 1000)
	equal(f.JI:GetUnitSpecialization('player'), 65)
	f.state.staged = false; f.fire('TRAIT_CONFIG_UPDATED', 101)
	equal(f.JI:GetUnitSpecialization('player'), 66)
	for i, value in ipairs(f.JI.dataHelper.specialization[66].texCoords) do equal(f.icon(player).coords[i], value) end
	f.state.activeGroup = 2; f.state.staged = true
	-- Never reuse the first loadout's answer for a different config with staged edits.
	equal(f.JI:GetUnitIcon('player', 'fabledspecializations'), nil)
	f.state.staged = false; f.fire('TRAIT_CONFIG_UPDATED', 202)
	equal(f.JI:GetUnitSpecialization('player'), 70)
end)

test('Forever group lookup handles empty/tied builds, loading, restrictions and self targets', function()
	local f = foreverTalentsFixture()
	f.state.points[101] = {0, 0, 0}
	equal(f.JI:GetUnitIcon('player', 'fabledspecializations'), f.JI.dataHelper.class.PALADIN)
	f.state.points[101] = {6, 6, 0}
	equal(f.JI:GetUnitIcon('player', 'fabledspecializations'), f.JI.dataHelper.class.PALADIN)
	f.state.points[101] = {6, 6, 7}; equal(f.JI:GetUnitSpecialization('player'), 70)
	f.state.points[101] = {f.secret, 0, 0}; equal(f.JI:GetUnitSpecialization('player'), 70)
	f.state.points[101] = {6, 0, 0}
	f.frame('target', 'PALADIN'); f.env.UnitIsUnit = function() return true end
	equal(f.JI:GetUnitSpecialization('target'), 65)
	f.env.UnitIsUnit = function() return false end
	equal(f.JI:GetUnitIcon('target', 'fabledspecializations'), nil)
	f.env.C_Traits.GetConfigInfo = function() return nil end
	equal(f.JI:GetUnitSpecialization('player'), 65)
	f.env.C_Traits = nil
	-- The legacy zero counters are not authoritative on Forever.
	equal(f.JI:GetUnitIcon('player', 'fabledspecializations'), nil)
end)

test('Forever uses active config when the combat-group helper is unavailable', function()
	local f = foreverTalentsFixture()
	f.env.C_SpecializationInfo.GetCombatConfigIDForSpecGroup = nil
	equal(f.JI:GetUnitSpecialization('player'), 65)
	f.state.activeGroup = 2; equal(f.JI:GetUnitSpecialization('player'), 70)
end)

local function partyFixture(onlyParty)
	local f = fixture(not onlyParty)
	f.state.addons.EllesmereUIRaidFrames = true
	f.env.EllesmereUI = f.env.EllesmereUI or {_ModuleNS = {}}
	local ns = {_partyAllButtons = {}, _partyFramesVisible = true,
		_CreatePartyHeader = function() end, _RebuildPartyUnitMap = function() end,
		_UpdatePartyVisibility = function() end, ReloadPartyFrames = function() end}
	f.env.EllesmereUI._ModuleNS.EllesmereUIRaidFrames = ns
	f.party = ns
	f.partyFrame = function(unit, class)
		local frame = f.frame(unit, class); frame._euiUnit = nil; frame:SetAttribute('unit', unit)
		ns._partyAllButtons[#ns._partyAllButtons + 1] = frame
		return frame
	end
	return f
end

test('Party works with Raid Frames alone and has independent settings', function()
	local f = partyFixture(true)
	expect(not f.JI.Options.args.ellesmereui.hidden())
	expect(not f.JI.Options.args.ellesmereui.args.party.hidden())
	expect(f.JI.Options.args.ellesmereui.args.player.hidden())
	local first, second, self = f.partyFrame('party1', 'MAGE'), f.partyFrame('party2', 'ROGUE'), f.partyFrame('player', 'WARRIOR')
	local db = f.JI.db.ellesmereui.party.icon
	equal(db.enable, false); db.enable = true; db.size = 40; db.style = 'fabledregalia'
	f.JI:SetupEllesmereUI(); f.flush()
	for _, frame in ipairs({first, second, self}) do
		expect(f.icon(frame):IsShown()); equal(frame.children[1].width, 40)
		expect(f.icon(frame).path:match('fabledregalia$')); equal(#frame.children, 1)
	end
	equal(f.icon(first).coords[1], .125); equal(f.icon(second).coords[1], .25)
	first:SetAlpha(.35); equal(f.icon(first):GetEffectiveAlpha(), .35)
	first:Hide(); expect(not f.icon(first):IsShown()); first:Show(); expect(f.icon(first):IsShown())
	f.JI.Options.args.ellesmereui.args.party.args.applyAll.func()
	equal(f.JI.db.ellesmereui.target.icon.size, 40)
	db.size = 64; equal(f.JI.db.ellesmereui.target.icon.size, 40)
end)

test('Party secure header reassignments repaint in combat without stale identities', function()
	local f = partyFixture()
	local frame = f.partyFrame('party1', 'MAGE'); f.frame('party2', 'ROGUE')
	f.JI.db.ellesmereui.party.icon.enable = true
	f.JI:SetupEllesmereUI(); f.flush(); equal(f.icon(frame).coords[1], .125)
	f.state.combat = true
	frame:SetAttribute('unit', 'party2'); equal(f.icon(frame).coords[1], .25)
	frame:SetAttribute('unit', nil); expect(not f.icon(frame):IsShown())
	frame:SetAttribute('unit', f.secret); expect(not f.icon(frame):IsShown())
	frame:SetAttribute('unit', 'party2'); expect(f.icon(frame):IsShown())
	f.world.party2.player = false; f.fire('UNIT_FLAGS', 'party2'); expect(not f.icon(frame):IsShown())
	f.world.party2.player = true; f.fire('UNIT_FLAGS', 'party2'); expect(f.icon(frame):IsShown())
	f.JI.db.ellesmereui.party.icon.size = 60; f.JI:UpdateEllesmereUI(); equal(frame.children[1].width, 32)
	f.state.combat = false; f.fire('PLAYER_REGEN_ENABLED'); f.flush(); equal(frame.children[1].width, 60)
end)

test('Party discovers late buttons, hides previews and retires removed buttons', function()
	local f = partyFixture(); f.JI.db.ellesmereui.party.icon.enable = true
	f.JI:SetupEllesmereUI(); f.flush()
	local frame = f.partyFrame('party1', 'MAGE'); f.party._CreatePartyHeader(); f.flush()
	expect(f.icon(frame):IsShown())
	f.party._partyPvActive = true; f.party._UpdatePartyVisibility(); f.flush(); expect(not f.icon(frame):IsShown())
	f.party._partyPvActive = nil; f.party._partyFramesVisible = false
	f.party._UpdatePartyVisibility(); f.flush(); expect(not f.icon(frame):IsShown())
	f.party._partyFramesVisible = true; f.party.ReloadPartyFrames(); f.flush(); expect(f.icon(frame):IsShown())
	local replacement = f.partyFrame('party2', 'ROGUE'); f.party._partyAllButtons = {replacement}
	f.party._RebuildPartyUnitMap(); f.flush(); expect(f.icon(replacement):IsShown()); expect(not f.icon(frame):IsShown())
	frame:Hide(); frame:Show(); expect(not f.icon(frame):IsShown())
	f.JI:UpdateEllesmereUI(); equal(#replacement.children, 1)
end)

local function inspectionFixture()
	local f = foreverTalentsFixture()
	f.state.now, f.state.notifies, f.state.inspectTimers, f.state.guids = 0, {}, {}, {}
	f.env.GetTime = function() return f.state.now end
	f.env.UnitGUID = function(unit) return f.state.guids[unit] end
	f.env.UnitIsUnit = function(a, b)
		local ga, gb = f.state.guids[a], f.state.guids[b]
		return ga and gb and ga == gb or false
	end
	f.env.CanInspect = function(unit) return f.state.inspectable ~= false end
	f.env.CheckInteractDistance = function() return f.state.inRange ~= false end
	f.env.NotifyInspect = function(unit)
		f.state.notifies[#f.state.notifies+1] = {unit = unit, guid = f.state.guids[unit], time = f.state.now}
	end
	f.env.ClearInspectPlayer = function() end
	f.env.C_Timer.NewTimer = function(delay, callback)
		local timer = {due = f.state.now + delay, callback = callback, Cancel = function(self) self.cancelled = true end}
		f.state.inspectTimers[#f.state.inspectTimers+1] = timer
		return timer
	end
	f.env.C_Traits.HasValidInspectData = function() return f.state.inspectValid end
	local oldConfig, oldDisplays = f.env.C_Traits.GetConfigInfo, f.env.C_Traits.GetGroupDisplayInfoByTreeID
	f.env.C_Traits.GetConfigInfo = function(id)
		return id == -1 and {treeIDs = {1082}} or oldConfig(id)
	end
	f.env.C_Traits.GetGroupDisplayInfoByTreeID = function(tree)
		if tree == 1082 then return {{groupID = 41}, {groupID = 42}, {groupID = 43}} end
		return oldDisplays(tree)
	end
	f.state.guids.player = 'Player-self'
	local flushUI = f.flush
	f.tick = function(seconds)
		local deadline, runs = f.state.now + seconds, 0
		flushUI()
		while true do
			local nextTimer
			for _, timer in ipairs(f.state.inspectTimers) do
				if not timer.cancelled and timer.due <= deadline and (not nextTimer or timer.due < nextTimer.due) then nextTimer = timer end
			end
			if not nextTimer then break end
			runs = runs + 1; expect(runs < 1000, 'unbounded inspection timer loop')
			f.state.now = nextTimer.due; nextTimer.cancelled = true; nextTimer.callback(); flushUI()
		end
		f.state.now = deadline
	end
	f.flush = function() f.tick(0) end
	f.ready = function(guid, points)
		f.state.inspectValid, f.state.points[-1] = true, points
		f.fire('INSPECT_READY', guid)
	end
	return f
end

test('Forever inspects a target automatically and paints live Enhancement 11 on the correct frame', function()
	local f = inspectionFixture()
	local target = f.frame('target', 'SHAMAN'); f.ns.frames.target = target
	f.state.guids.target = 'Player-shaman'
	local db = f.JI.db.ellesmereui.target.icon; db.enable = true; db.style = 'fabledspecializations'
	f.JI:SetupEllesmereUI(); f.JI:SetupSpecializationIcons(); f.flush()
	equal(#f.state.notifies, 1); equal(f.state.notifies[1].unit, 'target'); expect(not f.icon(target):IsShown())
	f.ready('Player-shaman', {0, 11, 0})
	equal(f.JI:GetUnitSpecialization('target'), 263); equal(f.JI:GetUnitSpecialization('player'), 65)
	expect(f.icon(target):IsShown()); expect(f.icon(target).path:match('fabledspecializations$'))
	for i, value in ipairs(f.JI.dataHelper.specialization[263].texCoords) do equal(f.icon(target).coords[i], value) end
	f.tick(5); equal(#f.state.notifies, 1)
	-- The same-class replacement must not inherit the previous inspection config or cache.
	f.state.guids.target = 'Player-new'; f.fire('PLAYER_TARGET_CHANGED'); f.flush()
	expect(not f.icon(target):IsShown())
	f.ready('Player-shaman', {0, 11, 0}); expect(not f.icon(target):IsShown())
	f.ready('Player-new', {0, 0, 12}); equal(f.JI:GetUnitSpecialization('target'), 264)
end)

test('Party inspections share GUID results with targets and use each assigned member build', function()
	local f = inspectionFixture()
	f.state.addons.EllesmereUIRaidFrames = true
	local first, second = f.frame('party1', 'SHAMAN'), f.frame('party2', 'PALADIN')
	first:SetAttribute('unit', 'party1'); second:SetAttribute('unit', 'party2')
	f.env.EllesmereUI._ModuleNS.EllesmereUIRaidFrames = {_partyAllButtons = {first, second}, _partyFramesVisible = true}
	local target = f.frame('target', 'SHAMAN'); f.ns.frames.target = target
	f.state.guids.party1, f.state.guids.target, f.state.guids.party2 = 'Player-one', 'Player-one', 'Player-two'
	for _, key in ipairs({'party', 'target'}) do
		local db = f.JI.db.ellesmereui[key].icon; db.enable = true; db.style = 'fabledspecializations'
	end
	f.JI:SetupEllesmereUI(); f.JI:SetupSpecializationIcons(); f.flush()
	equal(#f.state.notifies, 1)
	local requested = f.state.notifies[1]
	expect(requested.unit == 'party1' or requested.unit == 'party2')
	f.ready(requested.guid, requested.guid == 'Player-one' and {0, 11, 0} or {0, 0, 10})
	f.tick(2); equal(#f.state.notifies, 2)
	local other = f.state.notifies[2]; expect(other.guid ~= requested.guid)
	f.ready(other.guid, other.guid == 'Player-one' and {0, 11, 0} or {0, 0, 10})
	expect(f.icon(first):IsShown()); expect(f.icon(target):IsShown()); equal(f.JI:GetUnitSpecialization('party2'), 70)
	f.state.combat = true; first:SetAttribute('unit', 'party2')
	for i, value in ipairs(f.JI.dataHelper.specialization[70].texCoords) do equal(f.icon(first).coords[i], value) end
	f.state.guids.party2 = 'Player-replacement'; f.fire('GROUP_ROSTER_UPDATE'); f.flush()
	expect(not f.icon(first):IsShown()); expect(not f.icon(second):IsShown()); equal(#f.state.notifies, 2)
end)

test('inspection queue respects manual windows, other addons, combat and unavailable identities', function()
	local f = inspectionFixture(); f.frame('target', 'SHAMAN'); f.state.guids.target = 'Player-target'
	f.JI:SetupSpecializationIcons()
	f.env.InspectFrame = f.env.CreateFrame('Frame')
	f.JI:GetUnitSpecialization('target'); f.flush(); f.tick(5); equal(#f.state.notifies, 0)
	f.env.InspectFrame:Hide(); f.state.combat = true; f.tick(5); equal(#f.state.notifies, 0)
	f.state.combat = false; f.tick(1); equal(#f.state.notifies, 1)
	f.frame('focus', 'SHAMAN'); f.state.guids.focus = 'Player-other'
	f.env.NotifyInspect('focus'); f.ready('Player-other', {0, 11, 0})
	equal(f.JI:GetUnitSpecialization('target'), nil)
	f.ready('Player-target', {0, 11, 0}); equal(f.JI:GetUnitSpecialization('target'), nil)
	f.tick(2); equal(#f.state.notifies, 3)
	f.env.ClearInspectPlayer(); f.ready('Player-target', {0, 11, 0}); equal(f.JI:GetUnitSpecialization('target'), nil)
	f.state.guids.target = f.secret; f.tick(10); equal(#f.state.notifies, 3)
end)

test('inspection retries are bounded, cached results expire and ties use a verified class fallback', function()
	local f = inspectionFixture(); f.frame('target', 'SHAMAN'); f.state.guids.target = 'Player-target'
	f.JI:SetupSpecializationIcons(); f.JI:GetUnitSpecialization('target'); f.flush(); f.tick(20)
	equal(#f.state.notifies, 3)
	f.JI:GetUnitSpecialization('target'); f.flush(); f.tick(5); equal(#f.state.notifies, 3)
	f.tick(30); f.JI:GetUnitSpecialization('target'); f.flush(); equal(#f.state.notifies, 4)
	f.ready('Player-target', {6, 6, 0})
	equal(f.JI:GetUnitIcon('target', 'fabledspecializations'), f.JI.dataHelper.class.SHAMAN)
	f.tick(61); equal(f.JI:GetUnitIcon('target', 'fabledspecializations'), f.JI.dataHelper.class.SHAMAN); f.flush()
	equal(#f.state.notifies, 5)
	f.ready('Player-target', {f.secret, 0, 0})
	equal(f.JI:GetUnitIcon('target', 'fabledspecializations'), f.JI.dataHelper.class.SHAMAN)
	f.tick(240); equal(f.JI:GetUnitIcon('target', 'fabledspecializations'), nil)
end)

test('uninspectable distant players and restricted results never trigger unsafe requests', function()
	local f = inspectionFixture(); f.frame('target', 'SHAMAN'); f.state.guids.target = 'Player-target'
	f.JI:SetupSpecializationIcons(); f.state.inRange = false
	f.JI:GetUnitSpecialization('target'); f.flush(); f.tick(10); equal(#f.state.notifies, 0)
	f.state.inRange = true; f.env.CanInspect = function() return f.secret end
	f.tick(5); equal(#f.state.notifies, 0)
	f.env.CanInspect = function() return true end; f.tick(1); equal(#f.state.notifies, 1)
	f.state.inspectValid = f.secret; f.fire('INSPECT_READY', 'Player-target')
	equal(f.JI:GetUnitIcon('target', 'fabledspecializations'), nil)
end)

test('Forever inspection refresh reaches Blizzard target/party frames and ElvUI portraits/tags in combat', function()
	local f = inspectionFixture(); f.load('Core/Blizzard.lua')
	f.env.strmatch = string.match
	local target = f.frame('target', 'SHAMAN'); target.unit = 'target'; target.portrait = target:CreateTexture()
	local party = f.frame('party1', 'SHAMAN'); party.unit = 'party1'; party.portrait = party:CreateTexture()
	f.env.TargetFrame, f.env.PartyFrame = target, {MemberFrame1 = party}
	f.state.guids.target, f.state.guids.party1 = 'Player-shaman', 'Player-shaman'
	f.JI:SetupBlizzardFrames()
	for _, key in ipairs({'target', 'party'}) do
		for _, kind in ipairs({'icon', 'portrait'}) do
			local db = f.JI.db.blizzard[key][kind]; db.enable = true; db.style = 'fabledspecializations'
		end
	end
	f.state.addons.ElvUI = true
	local tags, E = {}, {UnitFrames = {PortraitUpdate = function() end}}
	function E:AddTag(name, event, fn) tags[name] = fn end
	function E:AddTagInfo() end
	f.env.ElvUI = {E}; f.load('Core/ElvUI.lua'); f.JI:BuildElvUITags()
	target.unitframeType = 'target'; party.unitframeType = 'party'
	local portraits = {}
	for _, frame in ipairs({target, party}) do
		local portrait = frame:CreateTexture(); portrait.__owner = frame; portrait.useClassBase = true
		local db = f.JI.db.elvui[frame.unitframeType].portrait; db.enable = true; db.style = 'fabledspecializations'
		E.UnitFrames.PortraitUpdate(portrait); portraits[#portraits+1] = portrait
	end
	f.JI.db.blizzard.target.icon.size = 48; f.JI.db.blizzard.target.icon.xOffset = 12
	f.JI:UpdateMedia(); f.JI:SetupSpecializationIcons(); f.flush(); equal(#f.state.notifies, 1)
	equal(target.classIcon.width, 48); equal(target.classIcon.point[4], 12)
	f.state.combat = true; f.ready('Player-shaman', {0, 11, 0})
	for _, frame in ipairs({target, party}) do
		expect(frame.classIcon:IsShown()); expect(frame.classPortrait:IsShown()); expect(not frame.portrait:IsShown())
		for i, value in ipairs(f.JI.dataHelper.specialization[263].texCoords) do
			equal(frame.classIcon.icon.coords[i], value); equal(frame.classPortrait.portrait.coords[i], value)
		end
		equal(tags['jiberish:spec:fabledspecializations'](frame.unit, nil, '32'),
			f.JI:GetIconMarkup(f.JI.dataHelper.specialization[263], f.JI.defaultStylePacks.spec.path..'fabledspecializations', 32, false, 2048))
	end
	for _, portrait in ipairs(portraits) do equal(portrait.coords[1], .25) end
	f.state.guids.target = 'Player-new'; f.fire('PLAYER_TARGET_CHANGED')
	expect(not target.classIcon:IsShown()); expect(party.classIcon:IsShown())
	equal(tags['jiberish:spec:fabledspecializations']('target'), nil)
	expect(tags['jiberish:spec:fabledspecializations']('party1'))
	f.JI.db.blizzard.target.icon.size = 64; f.JI:RefreshSpecializationIcons(); equal(target.classIcon.width, 48)
	f.state.combat = false; f.fire('PLAYER_REGEN_ENABLED'); equal(target.classIcon.width, 64)
end)

test('inspection prioritizes the current target and wakes exactly when the request cooldown ends', function()
	local f = inspectionFixture()
	for _, unit in ipairs({'party1', 'party2', 'target'}) do
		f.frame(unit, 'SHAMAN'); f.state.guids[unit] = 'Player-'..unit
	end
	f.JI:SetupSpecializationIcons()
	for _, unit in ipairs({'party1', 'party2', 'target'}) do f.JI:GetUnitSpecialization(unit) end
	f.flush(); equal(#f.state.notifies, 1); equal(f.state.notifies[1].unit, 'target'); equal(f.state.notifies[1].time, 0)
	f.tick(.37); f.ready('Player-target', {0, 11, 0}); f.flush()
	f.tick(1.62); equal(#f.state.notifies, 1)
	f.tick(.02); equal(#f.state.notifies, 2); equal(f.state.notifies[2].time, 2)
	equal(f.state.notifies[2].unit, 'party1')
	f.tick(.23); f.ready('Player-party1', {0, 0, 11}); f.flush()
	f.tick(1.76); equal(#f.state.notifies, 3); equal(f.state.notifies[3].time, 4)
	equal(f.state.notifies[3].unit, 'party2')
end)

test('new targets wake a waiting queue immediately while failed target retries yield to party members', function()
	local f = inspectionFixture()
	f.frame('party1', 'SHAMAN'); f.state.guids.party1 = 'Player-party'
	f.env.CanInspect = function(unit) return unit == 'target' or f.state.partyInRange end
	f.JI:SetupSpecializationIcons(); f.JI:GetUnitSpecialization('party1'); f.flush(); equal(#f.state.notifies, 0)
	f.tick(.2); f.frame('target', 'SHAMAN'); f.state.guids.target = 'Player-target'
	f.JI:GetUnitSpecialization('target'); f.flush()
	equal(#f.state.notifies, 1); equal(f.state.notifies[1].time, .2)
	f.state.partyInRange = true
	f.tick(5); equal(#f.state.notifies, 2); equal(f.state.notifies[2].unit, 'party1')
end)

test('confirmed target icons survive background refresh and zoning but not identity or spec invalidation', function()
	local f = inspectionFixture()
	local target = f.frame('target', 'SHAMAN'); f.ns.frames.target = target
	f.state.guids.target = 'Player-target'
	local db = f.JI.db.ellesmereui.target.icon; db.enable = true; db.style = 'fabledspecializations'
	f.JI:SetupEllesmereUI(); f.JI:SetupSpecializationIcons(); f.flush()
	f.ready('Player-target', {0, 11, 0})
	f.tick(59); f.fire('PLAYER_TARGET_CHANGED'); f.flush()
	equal(f.JI:GetUnitSpecialization('target'), 263); equal(#f.state.notifies, 1)
	f.tick(2); f.fire('PLAYER_TARGET_CHANGED')
	-- The old confirmed icon is returned synchronously, before the refresh reply.
	equal(f.JI:GetUnitSpecialization('target'), 263); expect(f.icon(target):IsShown())
	f.flush(); equal(#f.state.notifies, 2)
	f.ready('Player-target', {0, 0, 12}); equal(f.JI:GetUnitSpecialization('target'), 264)
	f.fire('PLAYER_ENTERING_WORLD', false, false)
	equal(f.JI:GetUnitSpecialization('target'), 264); expect(f.icon(target):IsShown()); equal(#f.state.notifies, 2)
	f.state.guids.target = 'Player-other'; f.fire('PLAYER_TARGET_CHANGED')
	equal(f.JI:GetUnitSpecialization('target'), nil); expect(not f.icon(target):IsShown())
	f.state.guids.target = 'Player-target'; f.fire('PLAYER_TARGET_CHANGED')
	equal(f.JI:GetUnitSpecialization('target'), 264); expect(f.icon(target):IsShown())
	f.tick(61); equal(f.JI:GetUnitSpecialization('target'), 264); f.flush()
	local beforeChange = #f.state.notifies
	f.fire('PLAYER_SPECIALIZATION_CHANGED', 'target')
	equal(f.JI:GetUnitSpecialization('target'), nil); expect(not f.icon(target):IsShown())
	f.ready('Player-target', {0, 0, 12}) -- delayed reply to the pre-change inspection
	equal(f.JI:GetUnitSpecialization('target'), nil); expect(not f.icon(target):IsShown())
	f.tick(5); equal(#f.state.notifies, beforeChange + 1)
	f.ready('Player-target', {0, 13, 0}); equal(f.JI:GetUnitSpecialization('target'), 263)
end)

test('Retail uses a current public specialization immediately and preserves it over an older cached build', function()
	local f = inspectionFixture()
	f.env.GetBuildInfo = function() return '12.0.1', '', '', 120100 end
	f.frame('target', 'MAGE'); f.state.guids.target = 'Player-mage'
	local spec = 0
	f.env.C_SpecializationInfo.GetInspectSpecialization = function() return spec end
	f.JI:SetupSpecializationIcons(); f.JI:GetUnitSpecialization('target'); f.flush()
	equal(#f.state.notifies, 1)
	spec = 63; f.ready('Player-mage', {})
	equal(f.JI:GetUnitSpecialization('target'), 63)
	spec = 0; equal(f.JI:GetUnitSpecialization('target'), 63)
	spec = 64; equal(f.JI:GetUnitSpecialization('target'), 64)
	spec = 0; equal(f.JI:GetUnitSpecialization('target'), 64)
	equal(#f.state.notifies, 1)
	spec = f.secret; equal(f.JI:GetUnitSpecialization('target'), nil)
	spec = 0; f.state.guids.target = 'Player-other'; equal(f.JI:GetUnitSpecialization('target'), nil)
end)

local function detailsFixture(client)
	local f = fixture(false, client)
	f.load('Core/Details.lua')
	f.entries = {}
	f.env.Details = {}
	function f.env.Details:AddCustomIconSet(path, label, isSpec, icon, coords, size)
		equal(self, f.env.Details)
		f.entries[#f.entries + 1] = { value = path, label = label, isSpec = isSpec, icon = icon, texcoord = coords, iconsize = size }
		return true
	end
	return f
end

test('Details registers a selectable specialization pack alongside every class pack, once', function()
	local f = detailsFixture()
	f.state.addons.Details = true
	f.JI:SetupDetails(); f.JI:SetupDetails()
	local classes, specs, foundClass = 0, 0, false
	for _, entry in ipairs(f.entries) do
		if entry.isSpec then
			specs = specs + 1
			equal(entry.label, 'Fabled Specializations (Spec)')
			equal(entry.value, [[Interface\AddOns\JiberishIcons\Media\Spec\spec_fabledspecializations]])
			equal(entry.icon, entry.value)
			-- Dropdown preview is Blood's first cell, not Details' unrelated logo cell.
			equal(#entry.texcoord, 4); equal(table.concat(entry.texcoord, ','), '0,0.125,0,0.125')
			equal(entry.iconsize[1], 16); equal(entry.iconsize[2], 16)
		else
			classes = classes + 1
			if entry.label == 'Fabled Class (Class)' then
				foundClass = true
				equal(entry.value, [[Interface\AddOns\JiberishIcons\Media\Class\fabledclass]])
			end
			equal(entry.isSpec, false); expect(entry.label:find(' %(Class%)$'))
			expect(entry.value:find([[\Media\Class\]], 1, true))
		end
	end
	equal(classes, 11); equal(specs, 1); expect(foundClass)
end)

test('Details absence and missing API are harmless on Retail, Forever and legacy clients', function()
	for _, client in ipairs({ 'retail', 'forever', 'legacy' }) do
		local f = detailsFixture(client ~= 'retail' and client or nil)
		f.JI:SetupDetails(); equal(#f.entries, 0) -- global exists but addon has not loaded
		f.state.addons.Details = true
		local details = f.env.Details
		f.env.Details = nil; f.JI:SetupDetails(); equal(#f.entries, 0)
		f.env.Details = {}; f.JI:SetupDetails(); equal(#f.entries, 0)
		f.env.Details = details; f.JI:SetupDetails(); equal(#f.entries, 12)
	end
end)

test('Details late loading registers through the existing addon event without duplicate menu rows', function()
	local f = detailsFixture('forever')
	f.JI.Initialized = true
	f.JI:SetupDetails(); equal(#f.entries, 0)
	f.state.addons.Details = true
	f.JI:Init('ADDON_LOADED', 'Details'); equal(#f.entries, 12)
	f.JI:Init('ADDON_LOADED', 'Details'); equal(#f.entries, 12)
	f.JI:Init('ADDON_LOADED', 'UnrelatedAddon'); equal(#f.entries, 12)
end)

test('Details preserves custom class filenames and skips missing or incompatible textures', function()
	local f = detailsFixture()
	f.state.addons.Details = true
	f.JI.mergedStylePacks.class.styles.custom = { name = 'Custom', path = [[Interface\AddOns\Custom\]], fileName = 'actual-file' }
	f.JI.mergedStylePacks.class.styles.broken = { name = 'Broken', path = [[Interface\AddOns\missing\]] }
	f.JI.mergedStylePacks.spec.styles.unsupported = { name = 'Different Layout' }
	local spec = f.JI.mergedStylePacks.spec.styles.fabledspecializations
	local fileName = spec.detailsFileName
	spec.detailsFileName = 'missing'
	f.JI:SetupDetails(); equal(#f.entries, 12)
	local found
	for _, entry in ipairs(f.entries) do
		expect(not entry.isSpec)
		if entry.label == 'Custom (Class)' then
			found = true; equal(entry.value, [[Interface\AddOns\Custom\actual-file]])
		end
	end
	expect(found)
	spec.detailsFileName = fileName
	f.JI:SetupDetails(); equal(#f.entries, 13); equal(f.entries[13].isSpec, true)
end)

local function meterFixture(client, base)
	local f = base or fixture(false, client)
	-- Meter integration must not inspect live units or read combat amounts/GUIDs.
	-- Forever live views are the exception, exercised with the real talent fixture.
	if not base then
		f.JI.GetUnitSpecialization = function() error('meter queried live talents') end
		f.env.NotifyInspect = function() error('meter requested inspection') end
	end
	f.env.SetCVar = function() error('meter changed a Blizzard setting') end
	f.env.Enum = {DamageMeterSessionType = {Overall = 0, Current = 1, Expired = 2}}
	f.windows = {}
	function f.entry(class, spec)
		local entry = f.frame('meter')
		entry.texture = entry:CreateTexture()
		entry.texture:SetTexCoord(.0625, .9, .0626, .9) -- DamageMeterEntry.xml's native crop
		function entry:GetIcon() return self.texture end
		function entry:GetElementData() return self.elementData end
		-- Blizzard's UpdateIcon memoization intentionally skips identical inputs.
		function entry:UpdateIcon()
			local atlas = self.classFilename and self.classFilename ~= '' and (not self.specIconID or self.specIconID == 0) and self.classFilename
			if atlas then
				if self.iconAtlasElement ~= atlas then
					self.iconAtlasElement, self.iconTexture = atlas, nil
					self.texture:SetAtlas(atlas)
				end
			elseif self.specIconID and self.specIconID ~= 0 then
				if self.iconTexture ~= self.specIconID then
					self.iconTexture, self.iconAtlasElement = self.specIconID, nil
					self.texture:SetTexture(self.specIconID)
				end
			else
				self.iconTexture, self.iconAtlasElement = nil, nil
				self.texture:SetTexture(nil)
			end
		end
		function entry:Init(source)
			self.elementData, self.isLocalPlayer = source, source.isLocalPlayer
			self.classFilename, self.specIconID = source.class, source.spec
			self:UpdateIcon()
		end
		entry:Init({class = class, spec = spec})
		return entry
	end
	function f.window()
		local w = { rows = {}, pinned = f.entry('MAGE', 135932), sessionType = 1 }
		function w:GetSessionType() return self.sessionType end
		function w:GetSessionID() return self.sessionID end
		function w:GetScrollBox() return self end
		function w:ForEachFrame(fn) for _, entry in ipairs(self.rows) do fn(entry, entry.elementData) end end
		function w:GetLocalPlayerEntry() return self.pinned end
		function w:InitEntry(entry, source) entry:Init(source) end
		f.windows[#f.windows + 1] = w
		return w
	end
	function f.blizzard()
		f.env.DamageMeter = {
			ForEachSessionWindow = function(_, fn) for _, w in ipairs(f.windows) do fn(w) end end,
			SetupSessionWindow = function() end, OnEditModeEnter = function() end, OnEditModeExit = function() end,
		}
		return f.env.DamageMeter
	end
	function f.eui()
		local ns = { _windows = {}, RegisterDMUnlock = function() end }
		f.env.EllesmereUI = { _ModuleNS = { EllesmereUIDamageMeters = ns } }
		f.euiNS = ns
		return ns
	end
	function f.euiWindow()
		local function row() return { classIcon = f.frame('euiMeter'):CreateTexture() } end
		local w = { rowPool = {row(), row()}, stickyPlayer = row(), curSession = 1, Refresh = function() end }
		f.euiNS._windows[#f.euiNS._windows + 1] = w
		return w
	end
	function f.renderEUI(w, bar, class, spec, sticky, hidden, source)
		if sticky then w._stickyClassCache, w._stickySpecCache = class, spec
		else bar._cachedClass, bar._cachedSpecIcon = class, spec end
		if hidden then bar.classIcon:Hide(); return end
		bar.classIcon:SetTexture(spec or 'native-class-'..class)
		bar.classIcon:SetTexCoord(.06, .94, .06, .94)
		bar.classIcon:Show()
		-- Ellesmere assigns the source after painting the native icon.
		bar._src = source or {classFilename = class, specIconID = spec}
	end
	return f
end

test('meter options default off, separate providers, exclude race styles and retain native Edit Mode controls', function()
	local f = meterFixture()
	local opts = f.JI.Options.args.damageMeters.args
	equal(f.JI.db.damageMeters.blizzard.enable, false); equal(f.JI.db.damageMeters.ellesmere.enable, false)
	local styles = opts.blizzard.args.style.values()
	equal(styles.fabledclass, 'Fabled Class (Class)'); expect(styles.fabledspecializations); expect(styles.fabledregalia); equal(styles.fabledazeroth, nil)
	opts.blizzard.set({'enable'}, true)
	equal(opts.blizzard.get({'enable'}), true); equal(opts.ellesmere.get({'enable'}), false)
	expect(opts.blizzard.args.editMode.disabled())
	f.env.EditModeManagerFrame = {}; local opened = 0
	f.env.ShowUIPanel = function(frame) equal(frame, f.env.EditModeManagerFrame); opened = opened + 1 end
	opts.blizzard.args.editMode.func(); equal(opened, 1)
	f.state.combat = true; expect(opts.blizzard.args.editMode.disabled())
	opts.blizzard.args.editMode.func(); equal(opened, 1)
end)

test('meters safely no-op without either API on Retail, Forever and older Classic', function()
	for _, client in ipairs({'retail', 'forever', 'legacy'}) do
		local f = meterFixture(client ~= 'retail' and client or nil)
		f.JI:SetupDamageMeters(); f.JI:SetupDamageMeters(); f.JI:UpdateDamageMeters()
		f.fire('ADDON_LOADED', 'UnrelatedAddon'); f.fire('PLAYER_LOGIN'); f.flush()
		equal(#f.windows, 0)
	end
end)

test('meter spec lookup validates class, handles unknown/secret metadata and accepts current client icon IDs', function()
	local f = meterFixture('forever')
	f.env.GetSpecializationInfoByID = function(id) return id, 'Spec', '', id == 65 and 98765 or nil end
	f.JI.db.damageMeters.blizzard.enable = true; f.JI:SetupDamageMeters()
	local cases = {{'PALADIN',135920,65},{'PALADIN',98765,65},{'SHAMAN',237581,263},{'MAGE',135846,64},{'DEMONHUNTER',7455385,1480}}
	for _, c in ipairs(cases) do equal(f.JI:GetDamageMeterIcon('blizzard', c[1], c[2]), f.JI.dataHelper.specialization[c[3]]) end
	for _, file in ipairs({0, 9999, 135846, f.secret}) do
		local icon, path = f.JI:GetDamageMeterIcon('blizzard', 'PALADIN', file)
		equal(icon, f.JI.dataHelper.class.PALADIN); expect(path:find('fabledregalia', 1, true))
	end
	equal(f.JI:GetDamageMeterIcon('blizzard', f.secret, 135846), nil)
	equal(f.JI:GetDamageMeterIcon('blizzard', '', 135846), nil)
	f.JI.db.damageMeters.blizzard.style = 'fabledazeroth'
	equal(f.JI:GetDamageMeterIcon('blizzard', 'PALADIN', 135920), nil)
end)

test('Blizzard meters replace existing, recycled and pinned icons and restore native memoized textures', function()
	local f = meterFixture(); local w = f.window(); local meter = f.blizzard()
	local entry = f.entry('MAGE', 135810); w.rows[1] = entry
	local db = f.JI.db.damageMeters.blizzard; db.enable = true
	f.JI:SetupDamageMeters()
	local path = [[Interface\AddOns\JiberishIcons\Media\Spec\fabledspecializations]]
	equal(entry.texture.path, path); equal(w.pinned.texture.path, path)
	local old = table.concat(entry.texture.coords, ',')
	w:InitEntry(entry, {class = 'MAGE', spec = 135846})
	expect(table.concat(entry.texture.coords, ',') ~= old)
	equal(table.concat(entry.texture.coords, ','), table.concat(f.JI.dataHelper.specialization[64].texCoords, ','))
	entry:UpdateIcon(); equal(entry.texture.path, path) -- native texture was memoized
	db.enable = false; f.JI:UpdateDamageMeters()
	equal(entry.texture.path, 135846); equal(table.concat(entry.texture.coords, ','), '0.0625,0.9,0.0626,0.9')
	equal(w.pinned.texture.path, 135932)
	db.enable = true; f.JI:UpdateDamageMeters()
	w:InitEntry(entry, {class = 'MAGE', spec = 0}); expect(entry.texture.path:find('fabledregalia', 1, true))
	db.enable = false; f.JI:UpdateDamageMeters(); equal(entry.texture.path, 'atlas:MAGE')
	db.enable = true; f.JI:UpdateDamageMeters()
	w:InitEntry(entry, {class = '', spec = 0}); equal(entry.texture.path, nil)
end)

test('Blizzard late loading, extra windows, combat and Edit Mode preserve visibility, sizing and spell icons', function()
	local f = meterFixture('forever'); f.JI.db.damageMeters.blizzard.enable = true
	f.JI:SetupDamageMeters()
	local w = f.window(); local meter = f.blizzard()
	f.fire('ADDON_LOADED', 'Blizzard_DamageMeter')
	local row = f.entry('SHAMAN', 237581)
	w.rows[1] = row; w:InitEntry(row, {class = 'SHAMAN', spec = 237581})
	expect(row.texture.path:find('fabledspecializations', 1, true))
	local other = f.window(); meter:SetupSessionWindow()
	expect(other.pinned.texture.path:find('fabledspecializations', 1, true))
	row.texture:Hide(); f.state.combat = true
	f.JI.db.damageMeters.blizzard.reverse = true; f.JI:UpdateDamageMeters()
	equal(row.texture.coords[1], f.JI.dataHelper.specialization[263].texCoords[5])
	expect(not row.texture:IsShown()); equal(row.texture.width, nil); equal(row.texture.point, nil)
	meter:OnEditModeEnter(); meter:OnEditModeExit(); expect(not row.texture:IsShown())
	local spell = f.entry(nil, 12345) -- not in the player session pool
	f.JI:UpdateDamageMeters(); equal(spell.texture.path, 12345)
end)

test('Ellesmere replaces ordinary and pinned rows, including deferred same-class spec changes', function()
	local f = meterFixture(); local ns = f.eui(); local w = f.euiWindow()
	f.JI.db.damageMeters.ellesmere.enable = true; f.JI:SetupDamageMeters()
	local row, pinned = w.rowPool[1], w.stickyPlayer
	f.renderEUI(w, row, 'MAGE', 135932)
	f.renderEUI(w, pinned, 'PALADIN', 135920, true)
	expect(row.classIcon.path:find('fabledspecializations', 1, true))
	equal(table.concat(pinned.classIcon.coords, ','), table.concat(f.JI.dataHelper.specialization[65].texCoords, ','))
	f.env.C_Timer.After(0, function() f.renderEUI(w, row, 'MAGE', 135846) end); f.flush()
	equal(table.concat(row.classIcon.coords, ','), table.concat(f.JI.dataHelper.specialization[64].texCoords, ','))
	f.state.combat = true
	f.renderEUI(w, pinned, 'PALADIN', 135873, true)
	equal(table.concat(pinned.classIcon.coords, ','), table.concat(f.JI.dataHelper.specialization[70].texCoords, ','))
	equal(row.classIcon.width, nil) -- no layout mutations, even in combat
end)

test('Ellesmere native texture/zoom restore immediately and hidden or spell rows stay under its control', function()
	local f = meterFixture(); f.eui(); local w = f.euiWindow()
	local row = w.rowPool[1]
	f.renderEUI(w, row, 'MAGE', 135810) -- attach to an already painted window
	local db = f.JI.db.damageMeters.ellesmere; db.enable = true; f.JI:SetupDamageMeters()
	db.enable = false; f.JI:UpdateDamageMeters()
	equal(row.classIcon.path, 135810); equal(table.concat(row.classIcon.coords, ','), '0.06,0.94,0.06,0.94')
	db.enable = true; f.JI:UpdateDamageMeters()
	f.renderEUI(w, row, 'MAGE', 135810, false, true) -- Ellesmere None
	f.JI:UpdateDamageMeters(); expect(not row.classIcon:IsShown())
	f.renderEUI(w, row, 'PALADIN', nil)
	expect(row.classIcon.path:find('fabledregalia', 1, true))
	db.enable = false; f.JI:UpdateDamageMeters(); equal(row.classIcon.path, 'native-class-PALADIN')
	w.spellPool = {{classIcon = f.frame('spell'):CreateTexture()}}
	w.spellPool[1].classIcon:SetTexture(12345)
	db.enable = true; f.JI:UpdateDamageMeters(); equal(w.spellPool[1].classIcon.path, 12345)
end)

test('Ellesmere delayed login, newly added windows and profile rebuilds bind once without polling', function()
	local f = meterFixture(); f.JI.db.damageMeters.ellesmere.enable = true; f.JI:SetupDamageMeters()
	local ns = f.eui(); f.fire('ADDON_LOADED', 'EllesmereUIDamageMeters')
	local w = f.euiWindow(); ns.RegisterDMUnlock()
	local hook = w.rowPool[1].classIcon.SetTexture
	f.JI:SetupDamageMeters(); ns.RegisterDMUnlock(); equal(w.rowPool[1].classIcon.SetTexture, hook)
	f.renderEUI(w, w.rowPool[1], 'WARRIOR', 132355)
	expect(w.rowPool[1].classIcon.path:find('fabledspecializations', 1, true))
	local other = f.euiWindow(); ns.RegisterDMUnlock()
	f.renderEUI(other, other.rowPool[1], 'WARRIOR', 132341)
	equal(table.concat(other.rowPool[1].classIcon.coords, ','), table.concat(f.JI.dataHelper.specialization[73].texCoords, ','))
	for i = #ns._windows, 1, -1 do ns._windows[i] = nil end
	local rebuilt = f.euiWindow(); ns.RegisterDMUnlock()
	f.renderEUI(rebuilt, rebuilt.rowPool[1], 'DRUID', 132115)
	expect(rebuilt.rowPool[1].classIcon.path:find('fabledspecializations', 1, true)); f.flush()
end)

test('meter class/reverse choices, custom-pack refresh and AceDB profile resets update both renderers', function()
	local f = meterFixture(); local bw = f.window(); f.blizzard(); f.eui(); local ew = f.euiWindow()
	f.JI.db.damageMeters.blizzard.enable = true; f.JI.db.damageMeters.ellesmere.enable = true
	f.JI:SetupDamageMeters(); f.renderEUI(ew, ew.rowPool[1], 'MAGE', 135932)
	local options = f.JI.Options.args.damageMeters.args
	options.blizzard.set({'style'}, 'fabledregalia'); options.ellesmere.set({'style'}, 'fabledregalia')
	options.ellesmere.args.reverse.set({}, true)
	expect(bw.pinned.texture.path:find('fabledregalia', 1, true))
	equal(ew.rowPool[1].classIcon.coords[1], f.JI.dataHelper.class.MAGE.texCoords[5])
	f.JI:MergeStylePacks(); expect(ew.rowPool[1].classIcon.path:find('fabledregalia', 1, true))
	f.JI.data:SetProfile('Other')
	equal(bw.pinned.texture.path, 135932); equal(ew.rowPool[1].classIcon.path, 135932)
	f.JI.data:SetProfile('Default') -- profile name is resolved by AceDB; explicitly reset whichever is active
	f.JI.data:ResetProfile()
	equal(f.JI.db.damageMeters.blizzard.enable, false); equal(f.JI.db.damageMeters.ellesmere.reverse, false)
end)

test('Forever live PALADIN 626003 uses committed Holy talents in both damage meters', function()
	local f = meterFixture('forever', inspectionFixture())
	local w = f.window(); f.blizzard(); f.eui(); local ew = f.euiWindow()
	local row = f.entry('PALADIN', 626003); w.rows[1] = row
	row:Init({class = 'PALADIN', spec = 626003, isLocalPlayer = true})
	w.pinned:Init({class = 'PALADIN', spec = 626003, isLocalPlayer = true})
	f.JI.db.damageMeters.blizzard.enable = true; f.JI.db.damageMeters.ellesmere.enable = true
	f.JI:SetupSpecializationIcons(); f.JI:SetupDamageMeters()
	f.renderEUI(ew, ew.rowPool[1], 'PALADIN', 626003, false, false, {isLocalPlayer = true})
	f.renderEUI(ew, ew.stickyPlayer, 'PALADIN', 626003, true, false, {isLocalPlayer = true})
	f.flush()
	for _, texture in ipairs({row.texture, w.pinned.texture, ew.rowPool[1].classIcon, ew.stickyPlayer.classIcon}) do
		expect(texture.path:find('fabledspecializations', 1, true), 'Forever class-only meter metadata fell back to Regalia')
		equal(table.concat(texture.coords, ','), table.concat(f.JI.dataHelper.specialization[65].texCoords, ','))
	end
	-- Changes to the committed build repaint without needing a different class icon.
	f.state.points[101] = {0, 0, 8}; f.fire('TRAIT_CONFIG_UPDATED', 101); f.flush()
	equal(table.concat(row.texture.coords, ','), table.concat(f.JI.dataHelper.specialization[70].texCoords, ','))
	equal(table.concat(ew.rowPool[1].classIcon.coords, ','), table.concat(f.JI.dataHelper.specialization[70].texCoords, ','))
	f.state.points[101] = {0, 0, 0}; f.fire('TRAIT_CONFIG_UPDATED', 101); f.flush()
	expect(row.texture.path:find('fabledregalia', 1, true))
	expect(ew.rowPool[1].classIcon.path:find('fabledregalia', 1, true))
end)

test('Forever meter inspection identifies exact GUIDs and recycled same-class rows in both providers', function()
	local f = meterFixture('forever', inspectionFixture())
	f.frame('party1', 'SHAMAN'); f.state.guids.party1 = 'Player-enh'
	local w = f.window(); f.blizzard(); f.eui(); local ew = f.euiWindow()
	local row = f.entry('SHAMAN', 626006); w.rows[1] = row
	row:Init({class = 'SHAMAN', spec = 626006, sourceGUID = 'Player-enh'})
	f.JI.db.damageMeters.blizzard.enable = true; f.JI.db.damageMeters.ellesmere.enable = true
	f.JI:SetupSpecializationIcons(); f.JI:SetupDamageMeters()
	f.renderEUI(ew, ew.rowPool[1], 'SHAMAN', 626006, false, false, {sourceGUID = 'Player-enh'})
	f.flush(); equal(#f.state.notifies, 1); equal(f.state.notifies[1].unit, 'party1')
	f.ready('Player-enh', {0, 11, 0}); f.flush()
	local function shows(spec)
		for _, texture in ipairs({row.texture, ew.rowPool[1].classIcon}) do
			expect(texture.path:find('fabledspecializations', 1, true))
			equal(table.concat(texture.coords, ','), table.concat(f.JI.dataHelper.specialization[spec].texCoords, ','))
		end
	end
	shows(263)
	f.frame('party2', 'SHAMAN'); f.state.guids.party2 = 'Player-resto'
	w:InitEntry(row, {class = 'SHAMAN', spec = 626006, sourceGUID = 'Player-resto'})
	-- Actual Ellesmere optimization: same class + same generic texture, no texture setter.
	ew.rowPool[1]._src = {sourceGUID = 'Player-resto'}; ew.Refresh(); f.flush()
	expect(ew.rowPool[1].classIcon.path:find('fabledregalia', 1, true))
	f.tick(2); equal(#f.state.notifies, 2); equal(f.state.notifies[2].unit, 'party2')
	f.ready('Player-resto', {0, 0, 11}); f.flush(); shows(264)
	-- Equal class names never substitute for matching the combatant's GUID.
	w:InitEntry(row, {class = 'SHAMAN', spec = 626006, sourceGUID = 'Player-unknown'})
	ew.rowPool[1]._src = {sourceGUID = 'Player-unknown'}; ew.Refresh(); f.flush()
	expect(row.texture.path:find('fabledregalia', 1, true))
	expect(ew.rowPool[1].classIcon.path:find('fabledregalia', 1, true)); equal(#f.state.notifies, 2)
end)

test('Forever live meter resolution refuses historical, mismatched, pet and restricted identities', function()
	local f = meterFixture('forever', inspectionFixture())
	f.JI.db.damageMeters.blizzard.enable = true; f.JI:SetupDamageMeters()
	local function get(class, file, source, sessionType, sessionID)
		return f.JI:GetDamageMeterIcon('blizzard', class, file, source, sessionType, sessionID)
	end
	local own = {isLocalPlayer = true, sourceGUID = f.secret}
	for _, sessionType in ipairs({0, 1}) do
		equal(get('PALADIN', 626003, own, sessionType), f.JI.dataHelper.specialization[65])
	end
	-- Any forbidden route must exit before querying talent/identity data.
	f.JI.GetUnitSpecialization = function() error('unexpected talent read') end
	for _, c in ipairs({
		{own, 1, 42}, {own, 1, f.secret}, {own, 2}, {own, f.secret},
		{f.secret, 1}, {{sourceGUID = f.secret}, 1}, {{isLocalPlayer = f.secret}, 1},
		{{sourceGUID = 'Player-absent'}, 1}, {{sourceGUID = 'Creature-pet'}, 1},
		{{isLocalPlayer = true, sourceCreatureID = 123}, 1}, {{isLocalPlayer = true, threatPet = true}, 1},
	}) do equal(get('PALADIN', 626003, c[1], c[2], c[3]), f.JI.dataHelper.class.PALADIN) end
	equal(get('PALADIN', f.secret, own, 1), f.JI.dataHelper.class.PALADIN)
	equal(get('SHAMAN', 626006, own, 1), f.JI.dataHelper.class.SHAMAN)
	-- A real recorded spec takes priority even for a historical fight.
	equal(get('PALADIN', 135873, own, 1, 42), f.JI.dataHelper.specialization[70])
	local retail = meterFixture(); retail.JI.db.damageMeters.blizzard.enable = true; retail.JI:SetupDamageMeters()
	equal(retail.JI:GetDamageMeterIcon('blizzard', 'PALADIN', 626003, own, 1), retail.JI.dataHelper.class.PALADIN)
end)

test('Forever meter session switching, deferred paints, reverse and disabling restore the correct textures', function()
	local f = meterFixture('forever', inspectionFixture())
	local w = f.window(); f.blizzard(); f.eui(); local ew = f.euiWindow()
	local row = f.entry('PALADIN', 626003); w.rows[1] = row
	row:Init({class = 'PALADIN', spec = 626003, isLocalPlayer = true})
	ew.Refresh = function()
		f.env.C_Timer.After(0, function()
			f.renderEUI(ew, ew.rowPool[1], 'PALADIN', 626003, false, false, {isLocalPlayer = true})
		end)
	end
	f.JI.db.damageMeters.blizzard.enable = true; f.JI.db.damageMeters.ellesmere.enable = true
	f.JI:SetupSpecializationIcons(); f.JI:SetupDamageMeters(); ew.Refresh(); f.flush()
	expect(ew.rowPool[1].classIcon.path:find('fabledspecializations', 1, true))
	for _, sessionType in ipairs({0, 1}) do
		w.sessionType, ew.curSession = sessionType, sessionType
		f.JI:UpdateDamageMeters(); ew.Refresh(); f.flush()
		expect(row.texture.path:find('fabledspecializations', 1, true))
		expect(ew.rowPool[1].classIcon.path:find('fabledspecializations', 1, true))
	end
	w.sessionID, ew.curSessionID = 23, 23
	f.JI:UpdateDamageMeters(); ew.Refresh(); f.flush()
	expect(row.texture.path:find('fabledregalia', 1, true))
	expect(ew.rowPool[1].classIcon.path:find('fabledregalia', 1, true))
	w.sessionID, ew.curSessionID = nil, nil
	f.JI.db.damageMeters.blizzard.reverse = true; f.JI.db.damageMeters.ellesmere.reverse = true
	f.JI:UpdateDamageMeters(); f.flush()
	equal(row.texture.coords[1], f.JI.dataHelper.specialization[65].texCoords[5])
	equal(ew.rowPool[1].classIcon.coords[1], f.JI.dataHelper.specialization[65].texCoords[5])
	f.JI.db.damageMeters.blizzard.enable = false; f.JI.db.damageMeters.ellesmere.enable = false
	f.JI:UpdateDamageMeters(); f.flush()
	equal(row.texture.path, 626003); equal(ew.rowPool[1].classIcon.path, 626003)
	equal(table.concat(ew.rowPool[1].classIcon.coords, ','), '0.06,0.94,0.06,0.94')
end)

test('Forever spec meters inspect party members before rows exist and share results with public GUID rows', function()
	local f = meterFixture('forever', inspectionFixture())
	f.frame('party1', 'SHAMAN'); f.state.guids.party1 = 'Player-party'
	f.frame('target', 'SHAMAN'); f.state.guids.target = 'Player-party'
	-- Forever can restrict the selected-spec API independently of trait results.
	f.env.C_SpecializationInfo.GetInspectSpecialization = function() return f.secret end
	local w = f.window(); f.blizzard()
	f.JI.db.damageMeters.blizzard.enable = true
	f.JI:SetupSpecializationIcons(); f.JI:SetupDamageMeters(); f.flush()
	equal(#f.state.notifies, 1); equal(f.state.notifies[1].unit, 'party1')
	f.ready('Player-party', {0, 11, 0}); f.flush()
	equal(f.JI:GetUnitSpecialization('party1'), 263)
	local row = f.entry('SHAMAN', 626006); w.rows[1] = row
	w:InitEntry(row, {class = 'SHAMAN', spec = 626006, sourceGUID = 'Player-party'})
	equal(table.concat(row.texture.coords, ','), table.concat(f.JI.dataHelper.specialization[263].texCoords, ','))
	-- Roster changes prime new members even with no corresponding visible row.
	f.frame('party2', 'PALADIN'); f.state.guids.party2 = 'Player-new'
	f.fire('GROUP_ROSTER_UPDATE'); f.flush(); f.tick(2)
	equal(#f.state.notifies, 2); equal(f.state.notifies[2].unit, 'party2')
end)

test('Forever meters refetch restricted row data after restrictions lift and keep native scrolling', function()
	local f = meterFixture('forever', inspectionFixture())
	f.env.C_Timer.After = function(delay, callback) f.env.C_Timer.NewTimer(delay, callback) end
	f.env.Enum.AddOnRestrictionState = {Inactive = 0, Activating = 1, Active = 2}
	f.frame('party1', 'SHAMAN'); f.state.guids.party1 = 'Player-party'
	local w = f.window(); f.blizzard(); f.eui(); local ew = f.euiWindow()
	local row = f.entry('SHAMAN', 626006); w.rows[1] = row
	local restricted = {class = 'SHAMAN', spec = 626006, sourceGUID = f.secret}
	local public = {class = 'SHAMAN', spec = 626006, sourceGUID = 'Player-party'}
	local data, blizzardReads, ellesmereReads = restricted, 0, 0
	row:Init(restricted)
	f.renderEUI(ew, ew.rowPool[1], 'SHAMAN', 626006, false, false, restricted)
	function w:Refresh(retain)
		equal(retain, true); blizzardReads = blizzardReads + 1
		self:InitEntry(row, data)
	end
	ew.Refresh = function()
		ellesmereReads = ellesmereReads + 1
		-- A native same-class refresh can replace only the data, not its texture.
		ew.rowPool[1]._src = data
	end
	f.JI.db.damageMeters.blizzard.enable = true; f.JI.db.damageMeters.ellesmere.enable = true
	f.JI:SetupSpecializationIcons(); f.JI:SetupDamageMeters(); f.flush()
	equal(#f.state.notifies, 1) -- public party tokens work despite restricted meter rows
	f.ready('Player-party', {0, 11, 0}); f.flush()
	expect(row.texture.path:find('fabledregalia', 1, true))
	f.state.combat = true
	f.fire('ADDON_RESTRICTION_STATE_CHANGED', 0, 1); f.tick(1)
	equal(blizzardReads, 0); equal(ellesmereReads, 0)
	f.state.combat = false
	f.fire('PLAYER_REGEN_ENABLED'); f.tick(.5)
	equal(blizzardReads, 1); equal(ellesmereReads, 1)
	expect(row.texture.path:find('fabledregalia', 1, true)) -- identity still restricted
	data = public -- newly fetched data is now public; old tables stay secret
	f.fire('ADDON_RESTRICTION_STATE_CHANGED', 0, 0)
	f.fire('ADDON_RESTRICTION_STATE_CHANGED', 1, 0)
	f.tick(.5)
	equal(blizzardReads, 2); equal(ellesmereReads, 2) -- events coalesce
	for _, texture in ipairs({row.texture, ew.rowPool[1].classIcon}) do
		expect(texture.path:find('fabledspecializations', 1, true))
		equal(table.concat(texture.coords, ','), table.concat(f.JI.dataHelper.specialization[263].texCoords, ','))
	end
	equal(#f.state.notifies, 1)
end)

test('Forever meter preinspection respects combat, manual inspection and provider settings', function()
	for _, provider in ipairs({'blizzard', 'ellesmere'}) do
		local f = meterFixture('forever', inspectionFixture())
		f.frame('party1', 'SHAMAN'); f.state.guids.party1 = 'Player-party'
		local w
		if provider == 'blizzard' then w = f.window(); f.blizzard()
		else f.eui(); w = f.euiWindow() end
		f.JI:SetupSpecializationIcons(); f.JI:SetupDamageMeters(); f.flush()
		equal(#f.state.notifies, 0)
		local db = f.JI.db.damageMeters[provider]; db.enable = true; db.style = 'fabledregalia'
		f.JI:UpdateDamageMeters(); f.flush(); equal(#f.state.notifies, 0)
		db.style = 'fabledspecializations'; w.sessionID, w.curSessionID = 42, 42
		f.JI:UpdateDamageMeters(); f.flush(); equal(#f.state.notifies, 0)
		w.sessionID, w.curSessionID = nil, nil; f.state.combat = true
		f.JI:UpdateDamageMeters(); f.flush(); f.tick(2); equal(#f.state.notifies, 0)
		f.state.combat = false; f.env.InspectFrame = f.env.CreateFrame('Frame')
		f.fire('PLAYER_REGEN_ENABLED'); f.flush(); f.tick(2); equal(#f.state.notifies, 0)
		f.env.InspectFrame:Hide(); f.tick(1)
		equal(#f.state.notifies, 1); equal(f.state.notifies[1].unit, 'party1')
	end
end)

test('Forever meter GUID cache survives leaving a group without leaking or extending expired results', function()
	local f = meterFixture('forever', inspectionFixture())
	f.frame('party1', 'SHAMAN'); f.state.guids.party1 = 'Player-party'
	f.JI.db.damageMeters.blizzard.enable = true; f.JI:SetupSpecializationIcons(); f.JI:SetupDamageMeters()
	f.JI:GetUnitSpecialization('party1'); f.flush(); f.ready('Player-party', {0, 11, 0}); f.flush()
	f.world.party1.exists = false; f.state.guids.party1 = nil; f.fire('GROUP_ROSTER_UPDATE'); f.flush()
	local function icon(guid, class, sessionID)
		return f.JI:GetDamageMeterIcon('blizzard', class or 'SHAMAN', 626006, {sourceGUID = guid}, 1, sessionID)
	end
	equal(icon('Player-party'), f.JI.dataHelper.specialization[263])
	equal(icon('Player-other'), f.JI.dataHelper.class.SHAMAN)
	equal(icon('Player-party', 'PALADIN'), f.JI.dataHelper.class.PALADIN)
	equal(icon(f.secret), f.JI.dataHelper.class.SHAMAN)
	equal(icon('Player-party', 'SHAMAN', 42), f.JI.dataHelper.class.SHAMAN)
	f.tick(299); equal(icon('Player-party'), f.JI.dataHelper.specialization[263])
	f.tick(2); equal(icon('Player-party'), f.JI.dataHelper.class.SHAMAN)
	equal(#f.state.notifies, 1)
end)

test('Forever Ellesmere keeps verified player icons when unrelated creature fields become restricted', function()
	local f = meterFixture('forever', inspectionFixture())
	f.eui(); local w = f.euiWindow()
	f.frame('party1', 'SHAMAN'); f.state.guids.party1 = 'Player-party'
	f.JI.db.damageMeters.ellesmere.enable = true
	f.JI:SetupSpecializationIcons(); f.JI:SetupDamageMeters(); f.flush()
	f.ready('Player-party', {0, 11, 0}); f.flush()
	local own, other = w.rowPool[1], w.rowPool[2]
	for _, combat in ipairs({false, true, false}) do
		f.state.combat = combat
		for _, creature in ipairs({0, f.secret, 0, f.secret}) do
			f.renderEUI(w, own, 'PALADIN', 626003, false, false,
				{isLocalPlayer = true, sourceGUID = f.secret, sourceCreatureID = creature})
			f.renderEUI(w, w.stickyPlayer, 'PALADIN', 626003, true, false,
				{isLocalPlayer = true, sourceGUID = f.secret, sourceCreatureID = creature})
			f.renderEUI(w, other, 'SHAMAN', 626006, false, false,
				{isLocalPlayer = false, sourceGUID = 'Player-party', sourceCreatureID = creature})
			f.flush()
			for _, bar in ipairs({own, w.stickyPlayer}) do
				expect(bar.classIcon.path:find('fabledspecializations', 1, true), 'known player flickered to Regalia')
				equal(table.concat(bar.classIcon.coords, ','), table.concat(f.JI.dataHelper.specialization[65].texCoords, ','))
			end
			equal(table.concat(other.classIcon.coords, ','), table.concat(f.JI.dataHelper.specialization[263].texCoords, ','))
		end
	end
end)

test('Forever meters retain confirmed personal talents through temporary read failures but apply real changes', function()
	local f = meterFixture('forever', inspectionFixture())
	f.eui(); local w = f.euiWindow(); local row = w.rowPool[1]
	f.JI.db.damageMeters.ellesmere.enable = true
	f.JI:SetupSpecializationIcons(); f.JI:SetupDamageMeters()
	f.renderEUI(w, row, 'PALADIN', 626003, false, false, {isLocalPlayer = true}); f.flush()
	local function shows(spec)
		w.Refresh(); f.flush()
		equal(table.concat(row.classIcon.coords, ','), table.concat(f.JI.dataHelper.specialization[spec].texCoords, ','))
	end
	shows(65)
	for _, combat in ipairs({true, false}) do
		f.state.combat = combat
		f.state.points[101] = {f.secret, 0, 0}; shows(65)
		f.state.points[101] = {6, 0, 0}; shows(65)
		f.state.staged = f.secret; shows(65); f.state.staged = false
		local info = f.env.C_Traits.GetConfigInfo
		f.env.C_Traits.GetConfigInfo = function() return nil end; shows(65)
		f.env.C_Traits.GetConfigInfo = info
		local group = f.env.C_SpecializationInfo.GetActiveSpecGroup
		f.env.C_SpecializationInfo.GetActiveSpecGroup = function() return f.secret end; shows(65)
		f.env.C_SpecializationInfo.GetActiveSpecGroup = group
	end
	f.state.points[101] = {0, 9, 0}; f.fire('TRAIT_CONFIG_UPDATED', 101); shows(66)
	f.state.points[101] = {0, 0, 0}; f.fire('TRAIT_CONFIG_UPDATED', 101); f.flush()
	expect(row.classIcon.path:find('fabledregalia', 1, true)) -- a known empty build is authoritative
	f.state.points[101] = {6, 0, 0}; shows(65)
	f.state.activeGroup = 2; f.state.points[202] = {f.secret, 0, 0}; w.Refresh(); f.flush()
	expect(row.classIcon.path:find('fabledregalia', 1, true)) -- no old loadout for a new config
	f.state.activeGroup = 1; shows(65)
	f.env.C_SpecializationInfo.GetActiveSpecGroup = function() return f.secret end
	f.fire('ACTIVE_TALENT_GROUP_CHANGED'); f.flush()
	expect(row.classIcon.path:find('fabledregalia', 1, true)) -- an explicit loadout change invalidates it
end)

test('Forever meter public GUID cache survives temporary unit API gaps without crossing identities', function()
	local f = meterFixture('forever', inspectionFixture())
	f.frame('party1', 'SHAMAN'); f.state.guids.party1 = 'Player-party'
	f.JI.db.damageMeters.ellesmere.enable = true; f.JI:SetupSpecializationIcons(); f.JI:SetupDamageMeters()
	f.JI:GetUnitSpecialization('party1'); f.flush(); f.ready('Player-party', {0, 11, 0}); f.flush()
	f.eui(); local w = f.euiWindow(); local row = w.rowPool[1]; f.JI:UpdateDamageMeters()
	f.env.UnitIsUnit = function() return f.secret end
	f.renderEUI(w, row, 'SHAMAN', 626006, false, false, {sourceGUID = 'Player-party'}); f.flush()
	equal(table.concat(row.classIcon.coords, ','), table.concat(f.JI.dataHelper.specialization[263].texCoords, ','))
	-- Recycling this same-class row never carries the confirmed player's icon.
	row._src = {sourceGUID = 'Player-other'}; w.Refresh(); f.flush()
	expect(row.classIcon.path:find('fabledregalia', 1, true))
	row._src = {sourceGUID = f.secret}; w.Refresh(); f.flush()
	expect(row.classIcon.path:find('fabledregalia', 1, true))
end)

local function partyMeterFixture()
	local f = meterFixture('forever', inspectionFixture())
	f.env.IsInRaid = function() return f.state.raid or false end
	f.env.IsInInstance = function() error('party combat support must also work in the open world') end
	f.env.Enum.DamageMeterType = {DamageDone = 0, HealingDone = 2, EnemyDamageTaken = 10}
	f.env.Enum.DamageMeterSourceDisplayType = {Ally = 1, Enemy = 2}
	f.frame('party1', 'SHAMAN'); f.state.guids.party1 = 'Player-shaman'
	local bw = f.window(); f.blizzard(); f.eui(); local ew = f.euiWindow()
	f.bw, f.ew = bw, ew
	bw.meterType, ew.curDMType = 0, 0
	f.session = {combatSources = {}}
	function bw:GetDamageMeterType() return self.meterType end
	function bw:GetCombatSession() return f.session end
	function bw:Refresh()
		for i, source in ipairs(f.session.combatSources) do
			self.rows[i] = self.rows[i] or f.entry(source.class, source.spec)
			self:InitEntry(self.rows[i], source)
		end
	end
	ew.Refresh = function()
		ew._lastSession = f.session
		for i, source in ipairs(f.session.combatSources) do
			ew.rowPool[i] = ew.rowPool[i] or {classIcon = f.frame('extraMeterRow'):CreateTexture()}
			f.renderEUI(ew, ew.rowPool[i], source.classFilename, source.specIconID, false, false, source)
		end
	end
	function f.source(unit, restricted)
		local class = f.world[unit].class
		local file = class == 'PALADIN' and 626003 or 626006
		return {class = class, classFilename = class, spec = file, specIconID = file,
			sourceGUID = restricted and f.secret or f.state.guids[unit], sourceCreatureID = restricted and f.secret or 0,
			isLocalPlayer = unit == 'player', sourceDisplayType = 1}
	end
	function f.refresh(sources)
		f.session = {combatSources = sources}
		bw:Refresh(); ew.Refresh(); f.flush()
	end
	function f.shows(index, spec, class)
		local info = spec and f.JI.dataHelper.specialization[spec] or f.JI.dataHelper.class[class]
		for _, texture in ipairs({bw.rows[index].texture, ew.rowPool[index].classIcon}) do
			expect(texture.path:find(spec and 'fabledspecializations' or 'fabledregalia', 1, true))
			equal(table.concat(texture.coords, ','), table.concat(info.texCoords, ','))
		end
	end
	f.JI.db.damageMeters.blizzard.enable = true; f.JI.db.damageMeters.ellesmere.enable = true
	f.JI:SetupSpecializationIcons(); f.JI:RememberPublicSpecialization('party1', 263)
	f.JI:SetupDamageMeters(); f.flush()
	return f
end

test('Forever open-world party snapshots preserve unambiguous icons in both combat meters as rows reorder', function()
	local f = partyMeterFixture()
	f.refresh({f.source('player'), f.source('party1')}); f.shows(2, 263)
	f.state.combat = true
	for i = 1, 3 do
		f.refresh({f.source('party1', true), f.source('player', true)})
		f.shows(1, 263); f.shows(2, 65)
		f.refresh({f.source('player', true), f.source('party1', true)})
		f.shows(1, 65); f.shows(2, 263)
	end
	f.state.combat = false
	-- Identity declassification may lag combat end; retain the same inference.
	f.refresh({f.source('party1', true), f.source('player', true)}); f.shows(1, 263)
	f.refresh({f.source('party1'), f.source('player')}); f.shows(1, 263)
	-- An empty Current between pulls must not discard the unchanged party's keys.
	f.refresh({}); f.state.combat = true
	f.refresh({f.source('party1', true)}); f.shows(1, 263)
end)

test('party combat inference rejects different or unknown same-class builds but accepts a shared spec', function()
	local f = partyMeterFixture()
	f.frame('party2', 'SHAMAN'); f.state.guids.party2 = 'Player-second'
	f.refresh({f.source('party1')}) -- second member has not appeared on this meter yet
	f.state.combat = true
	f.refresh({f.source('party1', true)}); f.shows(1, nil, 'SHAMAN')
	f.JI:RememberPublicSpecialization('party2', 264)
	f.refresh({f.source('party1', true)}); f.shows(1, nil, 'SHAMAN')
	f.JI:RememberPublicSpecialization('party2', 263)
	f.refresh({f.source('party1', true), f.source('party2', true)})
	f.shows(1, 263); f.shows(2, 263)
	-- Own-row metadata rules out the local player's different build.
	f.state.combat = false; f.world.party1.class = 'PALADIN'; f.state.guids.party2 = nil; f.world.party2.exists = false
	f.JI:RememberPublicSpecialization('party1', 70)
	f.refresh({f.source('player'), f.source('party1')}); f.state.combat = true
	f.refresh({f.source('party1', true), f.source('player', true)})
	f.shows(1, 70); f.shows(2, 65)
end)

test('party combat snapshot invalidation prevents reuse after membership, spec, zone or meter reset changes', function()
	for _, event in ipairs({'GROUP_ROSTER_UPDATE', 'PLAYER_SPECIALIZATION_CHANGED', 'PLAYER_ENTERING_WORLD', 'DAMAGE_METER_RESET'}) do
		local f = partyMeterFixture()
		f.refresh({f.source('party1')}); f.state.combat = true
		f.refresh({f.source('party1', true)}); f.shows(1, 263)
		f.fire(event, event == 'PLAYER_SPECIALIZATION_CHANGED' and 'party1' or nil); f.flush()
		f.refresh({f.source('party1', true)}); f.shows(1, nil, 'SHAMAN')
		f.state.combat = false; f.JI:RememberPublicSpecialization('party1', 264)
		f.refresh({f.source('party1')}); f.state.combat = true
		f.refresh({f.source('party1', true)}); f.shows(1, 264)
	end
	local f = partyMeterFixture()
	f.refresh({f.source('party1')}); f.state.combat = true
	f.state.guids.party1 = 'Player-replacement' -- reject even before the roster event arrives
	f.JI:RememberPublicSpecialization('party1', 263)
	f.refresh({f.source('party1', true)}); f.shows(1, nil, 'SHAMAN')
end)

test('party combat inference requires prior evidence and excludes raids, historical and enemy views', function()
	local f = partyMeterFixture()
	f.state.combat = true; f.refresh({f.source('party1', true)}); f.shows(1, nil, 'SHAMAN')
	f.state.combat = false; f.refresh({f.source('party1')}); f.state.combat = true
	f.refresh({f.source('party1', true)}); f.shows(1, 263)
	f.state.raid = true; f.refresh({f.source('party1', true)}); f.shows(1, nil, 'SHAMAN'); f.state.raid = false
	f.bw.sessionID, f.ew.curSessionID = 42, 42
	f.refresh({f.source('party1', true)}); f.shows(1, nil, 'SHAMAN')
	f.bw.sessionID, f.ew.curSessionID = nil, nil
	f.bw.meterType, f.ew.curDMType = 10, 10
	f.refresh({f.source('party1', true)}); f.shows(1, nil, 'SHAMAN')
	f.bw.meterType, f.ew.curDMType = 0, 0
	local enemy = f.source('party1', true); enemy.sourceDisplayType = 2
	f.refresh({enemy}); f.shows(1, nil, 'SHAMAN')
	local pet = f.source('party1', true); pet.threatPet = true
	f.refresh({pet}); f.shows(1, nil, 'SHAMAN')
	local missing = f.source('party1', true); missing.sourceGUID = nil
	f.refresh({missing}); f.shows(1, nil, 'SHAMAN')
	local unknownOwn = f.source('party1', true); unknownOwn.isLocalPlayer = f.secret
	f.refresh({unknownOwn}); f.shows(1, nil, 'SHAMAN')
	f.tick(301); f.refresh({f.source('party1', true)}); f.shows(1, nil, 'SHAMAN')
end)

test('complete meter snapshots block outsider and pet keys even when the visible party member is unambiguous', function()
	for _, guid in ipairs({'Player-departed', 'Pet-other'}) do
		local f = partyMeterFixture()
		f.bw.sessionType, f.ew.curSession = 0, 0
		local outsider = f.source('party1'); outsider.sourceGUID = guid
		f.session = {combatSources = {f.source('party1'), outsider}}
		-- The conflicting participant may be off-screen; capture the full session.
		f.ew._lastSession = f.session; f.JI:UpdateDamageMeters(); f.flush()
		f.state.combat = true
		f.refresh({f.source('party1', true)}); f.shows(1, nil, 'SHAMAN')
		f.state.combat = false; f.refresh({f.source('party1')})
		f.state.combat = true; f.refresh({f.source('party1', true)}); f.shows(1, nil, 'SHAMAN')
	end
end)

print(passed..' integration tests passed')
