#!/usr/bin/env python3
"""Contract tests for the optional token-speed metric in the chat toolbar."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONFIG = (ROOT / "modules" / "common" / "Config.qml").read_text(encoding="utf-8")
ADVANCED = (ROOT / "modules" / "settings" / "configs" / "ai" / "AdvancedAiConfig.qml").read_text(encoding="utf-8")
AI = (ROOT / "services" / "Ai.qml").read_text(encoding="utf-8")
TOOLBAR = (ROOT / "modules" / "ii" / "sidebarPolicies" / "aiChat" / "ChatControlBar.qml").read_text(encoding="utf-8")


class TokenToolbarMetricTests(unittest.TestCase):
    def test_config_defaults_to_accumulated_usage(self):
        self.assertIn("property bool showTokensPerSecond: false", CONFIG)

    def test_advanced_config_exposes_the_persistent_toggle(self):
        self.assertIn('text: Translation.tr("Show tokens per second in the chat toolbar")', ADVANCED)
        self.assertIn("checked: Config.options.ai.showTokensPerSecond", ADVANCED)
        self.assertIn("Config.options.ai.showTokensPerSecond = checked;", ADVANCED)

    def test_speed_uses_latest_completed_user_visible_answer(self):
        self.assertIn("readonly property real lastAnswerTokensPerSecond", AI)
        self.assertIn("message.outputTokens", AI)
        self.assertIn("message.completedAt", AI)
        self.assertIn("message.createdAt", AI)
        self.assertIn("function formatTokensPerSecond", AI)

    def test_toolbar_switches_between_usage_and_speed(self):
        self.assertIn("readonly property bool perSecond: Config.options.ai.showTokensPerSecond", TOOLBAR)
        self.assertIn("Ai.formatTokensPerSecond(tokenIndicator.rate)", TOOLBAR)
        self.assertIn("Ai.shortTokenCount(tokenIndicator.total)", TOOLBAR)
        self.assertIn('text: tokenIndicator.perSecond ? "speed"', TOOLBAR)


if __name__ == "__main__":
    unittest.main()
