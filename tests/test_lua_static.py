"""Offline Lua checks: every shipped Lua file parses, stays within the Lua 5.1
compiler limits (200 active locals, 60 upvalues per function), and the HUD
modules never create globals or read undeclared names."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from addon_files import ADDON, required_files
from lua_static import analyze, problems

HUD_FILES = ('Core/HudStyle.lua', 'Core/NavTape.lua', 'Core/NavTapeOptions.lua',
             'Core/AuraTimeline.lua', 'Core/AuraTimelineOptions.lua')
WOW_GLOBALS = {
    '_G', 'C_ActionBar', 'C_CurveUtil', 'C_NamePlate', 'C_Spell', 'C_SpellBook', 'C_Timer', 'C_UnitAuras',
    'CheckInteractDistance', 'CreateFrame', 'Enum', 'GetNumSpellTabs', 'GetPhysicalScreenSize', 'GetPlayerFacing',
    'GetSpellBookItemInfo', 'GetSpellTabInfo', 'GetTime', 'GetUnitSpeed', 'HasAction', 'InCombatLockdown',
    'IsPlayerSpell', 'JiberishIcons', 'LibStub', 'STANDARD_TEXT_FONT', 'UIParent', 'UnitCanAttack', 'UnitClass',
    'UnitIsUnit', 'format', 'geterrorhandler', 'hooksecurefunc', 'ipairs', 'issecretvalue', 'math', 'next',
    'pairs', 'pcall', 'rawget', 'select', 'setmetatable', 'table', 'tonumber', 'tostring', 'type', 'unpack', 'wipe',
}


class LuaStatic(unittest.TestCase):
    def test_shipped_lua_parses_within_compiler_limits(self):
        names = [n for n in required_files() if n.endswith('.lua')]
        self.assertTrue(names)
        for name in names:
            with self.subTest(file=name):
                self.assertEqual(problems((ADDON / name).read_text(encoding='utf-8-sig')), [])

    def test_hud_modules_keep_to_their_locals_and_known_globals(self):
        for name in HUD_FILES:
            with self.subTest(file=name):
                report = analyze((ADDON / name).read_text(encoding='utf-8-sig'))
                self.assertEqual(report.global_writes, {})
                self.assertEqual(set(report.global_reads) - WOW_GLOBALS, set())
                main = next(peak for fn, _, peak, _ in report.functions if fn == 'main chunk')
                self.assertLess(main, 150)

    def test_checker_rejects_broken_code(self):
        self.assertTrue(problems('if x then'))
        self.assertTrue(problems('\n'.join(f'local v{i}' for i in range(201))))
        self.assertEqual(problems('local t = {1, 2; x = 3} for _, v in ipairs(t) do print(v) end'), [])


if __name__ == '__main__':
    unittest.main()
