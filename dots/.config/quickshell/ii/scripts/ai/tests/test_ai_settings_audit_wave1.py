"""Contracts for the first remediation wave of the AI Settings audit."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[3]
AI_SETTINGS = ROOT / "modules/settings/configs/AiAssistantConfig.qml"
ENTRY_BUTTON = ROOT / "modules/common/widgets/SubPageEntryButton.qml"


class SubPageEntryButtonTests(unittest.TestCase):
    def test_ai_entries_use_the_shared_navigation_component(self):
        source = AI_SETTINGS.read_text(encoding="utf-8")

        self.assertEqual(source.count("SubPageEntryButton {"), 3)
        self.assertNotIn("component SubPageEntryButton:", source)

    def test_shared_entry_is_neutral_and_keeps_colour_on_its_icon(self):
        source = ENTRY_BUTTON.read_text(encoding="utf-8")

        self.assertIn("colBackground: Appearance.colors.colSurfaceContainerHigh", source)
        self.assertIn("colBackgroundHover: Appearance.colors.colSurfaceContainerHighest", source)
        self.assertIn("color: root.entryAccent", source)
        self.assertNotIn("colTertiaryContainer", source)


if __name__ == "__main__":
    unittest.main()
