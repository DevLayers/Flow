"""Contracts for the first remediation wave of the AI Settings audit."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[3]
AI_SETTINGS = ROOT / "modules/settings/configs/AiAssistantConfig.qml"
ENTRY_BUTTON = ROOT / "modules/common/widgets/SubPageEntryButton.qml"
ADVANCED = ROOT / "modules/settings/configs/ai/AdvancedAiConfig.qml"
POPOVER = ROOT / "services/ai/blocks/AiToolsPopover.qml"
PERMISSION_LIST = ROOT / "services/ai/blocks/AiToolPermissionList.qml"


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


class ToolPermissionGroupingTests(unittest.TestCase):
    def test_both_surfaces_use_the_same_grouped_permission_list(self):
        advanced = ADVANCED.read_text(encoding="utf-8")
        popover = POPOVER.read_text(encoding="utf-8")

        self.assertIn("AiToolPermissionList {", advanced)
        self.assertIn("AiToolPermissionList {", popover)
        self.assertNotIn("component PermissionSegments:", popover)

    def test_permission_list_groups_registry_domains_and_supports_batch_changes(self):
        source = PERMISSION_LIST.read_text(encoding="utf-8")

        self.assertIn("AiToolRegistry.domains", source)
        self.assertIn("function toolsForDomain", source)
        self.assertIn("function setDomainPermission", source)
        self.assertIn("Ai.toolbox.setPermission", source)
        self.assertIn("collapsible: true", source)
        self.assertIn("Ai.toolbox.unavailableReason", source)


if __name__ == "__main__":
    unittest.main()
