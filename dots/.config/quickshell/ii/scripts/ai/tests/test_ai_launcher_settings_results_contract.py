#!/usr/bin/env python3
"""Settings matches in the launcher must behave like launcher results."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
LAUNCHER = (ROOT / "services" / "LauncherSearch.qml").read_text(encoding="utf-8")
SEARCH_WIDGET = (ROOT / "modules" / "ii" / "overview" / "SearchWidget.qml").read_text(encoding="utf-8")
SETTING_CARD = (ROOT / "services" / "ai" / "blocks" / "AiSettingResultCard.qml").read_text(encoding="utf-8")


class LauncherSettingsResultsTests(unittest.TestCase):
    def test_applications_precede_settings_matches(self):
        apps = LAUNCHER.index("result = result.concat(appResultObjects);")
        settings = LAUNCHER.index("result = result.concat(settingsResultObjects);")
        self.assertLess(apps, settings)

    def test_settings_cards_use_the_same_inset_as_application_rows(self):
        card_loader = SEARCH_WIDGET.split("id: settingResultCard", 1)[1].split("id: normalSearchItem", 1)[0]
        self.assertIn("Appearance.sizes.elevationMargin", card_loader)
        self.assertIn("launcherStyle: true", card_loader)

    def test_launcher_card_has_its_own_surface_background(self):
        self.assertIn("property bool launcherStyle: false", SETTING_CARD)
        self.assertIn("Appearance.colors.colSurfaceContainerHigh", SETTING_CARD)


if __name__ == "__main__":
    unittest.main()
