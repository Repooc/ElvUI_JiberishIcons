-- Run from the repository root: lua5.1 tests/ellesmereui.lua
-- Loads the real addon defaults/options, AceDB and adapter with a small WoW UI mock.
local root = 'ElvUI_JiberishIcons/'
local passed = 0
local function expect(value, message) assert(value, message or 'expectation failed') end
local function equal(actual, expected) assert(actual == expected, tostring(actual)..' ~= '..tostring(expected)) end

local function fixture(loaded)
	local env = setmetatable({}, { __index = _G })
	env._G = env
	local world, timers, objects = {}, {}, {}
	local secret = {}
	local state = { combat = false, loaded = loaded ~= false }
	env.issecretvalue = function(v) return rawequal(v, secret) end
	env.securecallfunction = function(fn, ...) return fn(...) end
	env.wipe = function(t) for k in pairs(t) do t[k] = nil end; return t end
	env.format, env.gsub, env.strupper, env.sort = string.format, string.gsub, string.upper, table.sort
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
		GetAddOnMetadata = function(_, key) return key == 'Title' and 'JiberishIcons' or '1.4.6' end,
		IsAddOnLoaded = function(name) return name == 'EllesmereUIUnitFrames' and state.loaded end,
	}
	env.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
	local methods = {}
	function methods:SetScript(event, fn) self.scripts[event] = fn end
	function methods:HookScript(event, fn)
		local old = self.scripts[event]
		self.scripts[event] = function(...) if old then old(...) end; fn(...) end
	end
	function methods:RegisterEvent(event) self.events[event] = true end
	function methods:Show()
		local changed = not self.shown
		self.shown = true
		if changed and self.scripts.OnShow then self.scripts.OnShow(self) end
	end
	function methods:Hide() self.shown = false end
	function methods:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
	function methods:SetTexture(path) self.path = path end
	function methods:GetTexture() return self.path and not self.path:find('missing', 1, true) and self.path or nil end
	function methods:SetTexCoord(...) self.coords = {...} end
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
	env.hooksecurefunc = function(owner, name, fn)
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
	load('Init.lua', 'ElvUI_JiberishIcons', {})
	load('Locales/enUS.lua')
	load('Core/API.lua')
	load('Core/Defaults/Profile.lua')
	load('Core/Defaults/Global.lua')
	load('Core/Core.lua')
	-- Formatting unrelated to this adapter uses WoW's UTF8 helpers.
	JI.TextGradient = function(_, value) return value end
	JI.StripString = function(_, value) return value end
	JI.UpdateMedia = function() end
	load('Core/Options.lua', 'ElvUI_JiberishIcons')
	load('Core/EllesmereUI.lua')
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
		flush = flush, fire = fire, frame = frame, icon = icon, objects = objects }
end

local function test(name, fn)
	fn(); passed = passed + 1; print('PASS '..name)
end

test('real AceDB defaults and existing integration options', function()
	local f = fixture()
	for _, key in ipairs(f.JI.dataHelper.ellesmereUnitList) do
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
	for _, key in ipairs(f.JI.dataHelper.ellesmereUnitList) do
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

print(passed..' integration tests passed')
