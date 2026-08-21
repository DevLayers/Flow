#!/usr/bin/env python3
"""The semantic Settings tools must stay keyed, validated and reviewable."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
AI = (ROOT / "services/Ai.qml").read_text(encoding="utf-8")
REGISTRY = (ROOT / "services/ai/AiToolRegistry.qml").read_text(encoding="utf-8")
INTEGRATION_PATH = ROOT / "services/ai/integrations/AiSettingsIntegration.qml"


class SemanticSettingsToolsTests(unittest.TestCase):
    def test_settings_adapter_owns_index_read_validation_and_strict_apply(self):
        self.assertTrue(INTEGRATION_PATH.exists())
        source = INTEGRATION_PATH.read_text(encoding="utf-8")
        for token in (
            "settings_index.json",
            "ai_settings_index.py",
            "function search(",
            "function get(",
            "function validate(",
            "function propose(",
            "Config.setNestedValue(key, value, true)",
        ):
            with self.subTest(token=token):
                self.assertIn(token, source)

    def test_registry_exposes_only_the_semantic_settings_schema(self):
        for tool in (
            'id: "settings_search"',
            'id: "settings_get"',
            'id: "settings_open"',
            'id: "settings_propose_changes"',
            'id: "settings_apply_changes"',
        ):
            with self.subTest(tool=tool):
                self.assertIn(tool, REGISTRY)
        self.assertIn('id: "settings_find"', REGISTRY)  # compatibility alias
        self.assertIn('formats: []', REGISTRY.split('id: "settings_find"', 1)[1].split('id:', 1)[0])
        self.assertIn('id: "set_shell_config"', REGISTRY)  # compatibility alias
        self.assertIn('formats: []', REGISTRY.split('id: "set_shell_config"', 1)[1].split('id:', 1)[0])

    def test_ai_routes_semantic_tools_through_the_adapter_and_journal(self):
        for token in (
            "readonly property AiSettingsIntegration settingsIntegration",
            '"settings_search": call => root.toolSettingsSearch(call)',
            '"settings_open": call => root.toolSettingsOpen(call)',
            '"settings_propose_changes": call => root.toolSettingsProposeChanges(call)',
            '"settings_apply_changes": call => root.toolSettingsApplyChanges(call)',
            '"settings_apply_changes": pending => root.applySettingsChangesNow',
        ):
            with self.subTest(token=token):
                self.assertIn(token, AI)


if __name__ == "__main__":
    unittest.main()
