-- Exercise the bundled AceGUI constructor/acquire/click/recycle path without
-- Blizzard's old global SetDesaturation helper. Run with Lua 5.1 from repo root.
local root = 'JiberishIcons/Libs/Ace3/'
local function equal(actual, expected) assert(actual == expected, tostring(actual)..' ~= '..tostring(expected)) end
local env = setmetatable({}, {__index = _G})
env._G = env
env.SetDesaturation = nil
env.table = setmetatable({wipe = function(t) for k in pairs(t) do t[k] = nil end end}, {__index = table})
env.xpcall = function(fn, handler, ...)
	local args = {...}
	return xpcall(function() return fn(unpack(args)) end, handler)
end
env.geterrorhandler = function() return error end
local sounds = {}
env.PlaySound = function(id) sounds[#sounds + 1] = id end

local methods = {}
local function object()
	return setmetatable({scripts = {}, shown = true}, {__index = methods})
end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetPoint(...) self.point = {...} end
function methods:ClearAllPoints() self.point = nil end
function methods:SetAllPoints(target) self.allPoints = target end
function methods:SetParent(parent) self.parent = parent end
function methods:EnableMouse(enabled) self.mouse = enabled end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:CreateTexture() return object() end
function methods:CreateFontString() return object() end
function methods:SetTexture(texture) self.texture = texture end
function methods:GetTexture() return self.texture end
function methods:SetTexCoord(...) self.coords = {...} end
function methods:SetBlendMode(mode) self.blend = mode end
function methods:SetDesaturated(value) self.desaturated = value end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:GetStringHeight() return 14 end
function methods:SetTextColor(...) self.color = {...} end
function methods:SetJustifyH(value) self.justifyH = value end
function methods:SetJustifyV(value) self.justifyV = value end
env.UIParent = object()
env.CreateFrame = object
local function load(path)
	setfenv(assert(loadfile(root..path)), env)()
end
load('LibStub/LibStub.lua')
load('AceGUI-3.0/AceGUI-3.0.lua')
local gui = env.LibStub('AceGUI-3.0')
load('AceGUI-3.0/widgets/AceGUIWidget-CheckBox.lua')
local box = gui:Create('CheckBox')
equal(gui:GetWidgetVersion('CheckBox'), 27)
equal(box:GetValue(), false); equal(box.check.shown, false); equal(box.frame.enabled, true)
equal(box.check.desaturated, false)
print('PASS real AceGUI acquisition works without SetDesaturation')

box:SetValue(true)
equal(box:GetValue(), true); equal(box.check.shown, true); equal(box.check.desaturated, false)
box:SetDisabled(true); equal(box.frame.enabled, false); equal(box.check.desaturated, true)
box:SetDisabled(false); equal(box.frame.enabled, true); equal(box.check.desaturated, false)
box:SetTriState(true); box:ToggleChecked()
equal(box:GetValue(), nil); equal(box.check.shown, true); equal(box.check.desaturated, true)
box:ToggleChecked(); equal(box:GetValue(), false); equal(box.check.shown, false)
box:ToggleChecked(); equal(box:GetValue(), true); equal(box.check.desaturated, false)
print('PASS checked, disabled, enabled and unknown tristate visuals')

box:SetTriState(false); box:SetValue(false)
local values = {}
box:SetCallback('OnValueChanged', function(_, _, value) values[#values + 1] = value end)
box.frame.scripts.OnMouseDown(box.frame, 'LeftButton')
box.frame.scripts.OnMouseUp(box.frame, 'LeftButton')
equal(values[1], true); equal(sounds[1], 856)
box.frame.scripts.OnMouseUp(box.frame, 'LeftButton')
equal(values[2], false); equal(sounds[2], 857)
box:SetDisabled(true); box.frame.scripts.OnMouseUp(box.frame, 'LeftButton')
equal(#values, 2); equal(#sounds, 2)
print('PASS real mouse clicks fire values/sounds and disabled clicks are ignored')

box:SetTriState(true); box:SetValue(nil)
gui:Release(box)
local reused = gui:Create('CheckBox')
equal(reused, box); equal(reused:GetValue(), false)
equal(reused.check.shown, false); equal(reused.check.desaturated, false); equal(reused.frame.enabled, true)
local constructor = gui.WidgetRegistry.CheckBox
load('AceGUI-3.0/widgets/AceGUIWidget-CheckBox.lua')
equal(gui.WidgetRegistry.CheckBox, constructor)
-- Simulate an older widget registered before ours, with an old pooled instance.
gui.WidgetVersions.CheckBox = 26
gui.WidgetRegistry.CheckBox = function() error('obsolete checkbox constructor selected') end
gui:Release(reused); reused.AceGUIWidgetVersion = 26
load('AceGUI-3.0/widgets/AceGUIWidget-CheckBox.lua')
local upgraded = gui:Create('CheckBox')
assert(upgraded ~= reused); equal(upgraded:GetValue(), false)
equal(gui:GetWidgetVersion('CheckBox'), 27)
print('PASS recycled widgets reset cleanly and equal-version libraries coexist')
print('4 checkbox regression checks passed')
