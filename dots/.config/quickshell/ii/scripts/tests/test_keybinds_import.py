import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "keybinds" / "import_keybinds.py"
SPEC = importlib.util.spec_from_file_location("keybinds_import", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class KeybindImporterTests(unittest.TestCase):
    def test_jsonc_keeps_urls_and_removes_comments(self):
        parsed = json.loads(MODULE.strip_jsonc('[{"key":"ctrl+k", "command":"open", "when":"url == https://x"}, // note\n]'))
        self.assertEqual(parsed[0]["when"], "url == https://x")

    def test_jsonc_keeps_comma_bracket_sequences_inside_strings(self):
        parsed = json.loads(MODULE.strip_jsonc('{"value": "keep,] and ,}", "items": [1,],}'))
        self.assertEqual(parsed["value"], "keep,] and ,}")
        self.assertEqual(parsed["items"], [1])

    def test_vscode_import_preserves_context(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "keybindings.json"
            path.write_text('[{"key":"ctrl+alt+n","command":"workbench.action.showCommands","when":"editorTextFocus"}]', encoding="utf-8")
            result = MODULE.import_vscode(path)
        self.assertEqual(result["keybinds"][0]["description"], "Show command palette")
        self.assertEqual(result["keybinds"][0]["context"], "editorTextFocus")

    def test_neovim_static_import_reads_desc_and_mode(self):
        text = 'vim.keymap.set({"n", "v"}, "<leader>ff", function() end, { desc = "Find files" })'
        result = MODULE.neovim_lua_keybinds(text, "lua/maps.lua")
        self.assertEqual(result[0]["keys"], "<leader>ff")
        self.assertEqual(result[0]["description"], "Find files")
        self.assertEqual(result[0]["context"], "n, v mode")

    def test_neovim_static_import_preserves_unicode(self):
        text = 'vim.keymap.set("n", "<leader>ca", "x", { desc = "Ação rápida" })'
        result = MODULE.neovim_lua_keybinds(text, "lua/maps.lua")
        self.assertEqual(result[0]["description"], "Ação rápida")
        self.assertEqual(result[0]["context"], "n mode")

    def test_jetbrains_import_reads_chords(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "custom.xml"
            path.write_text('<keymap><action id="GotoFile"><keyboard-shortcut first-keystroke="ctrl k" second-keystroke="ctrl o"/></action></keymap>', encoding="utf-8")
            result = MODULE.import_jetbrains(path)
        self.assertEqual(result["keybinds"][0]["keys"], "ctrl k ctrl o")
        self.assertEqual(result["keybinds"][0]["description"], "Go to file")


if __name__ == "__main__":
    unittest.main()
