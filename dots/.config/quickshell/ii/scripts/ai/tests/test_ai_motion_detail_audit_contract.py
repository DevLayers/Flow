"""Contracts for the AI chat movement-and-detail audit items."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[3]
CONFIG = (ROOT / "modules/common/Config.qml").read_text(encoding="utf-8")
SETTINGS = (ROOT / "modules/settings/configs/AiAssistantConfig.qml").read_text(encoding="utf-8")
CHAT = (ROOT / "modules/ii/sidebarPolicies/AiChat.qml").read_text(encoding="utf-8")
MESSAGE = (ROOT / "modules/ii/sidebarPolicies/aiChat/AiMessage.qml").read_text(encoding="utf-8")
CONTROL_BAR = (ROOT / "modules/ii/sidebarPolicies/aiChat/ChatControlBar.qml").read_text(encoding="utf-8")
PICKER = (ROOT / "services/ai/blocks/AiModelPickerPopover.qml").read_text(encoding="utf-8")
SEARCH_SURFACE = (ROOT / "services/ai/AiSearchSurface.qml").read_text(encoding="utf-8")
SEARCH_NAVIGATOR = (ROOT / "services/ai/AiSearchNavigator.qml").read_text(encoding="utf-8")
AI_SERVICE = (ROOT / "services/Ai.qml").read_text(encoding="utf-8")


class MotionPreferenceTests(unittest.TestCase):
    def test_one_persisted_preference_drives_search_and_sidebar(self):
        self.assertIn("property bool reducedMotion: false", CONFIG)
        self.assertIn("Reduce motion in AI chat", SETTINGS)
        self.assertIn("Config.options.sidebar.ai.reducedMotion", SEARCH_SURFACE)
        self.assertIn("Config.options.sidebar.ai.reducedMotion", SEARCH_NAVIGATOR)
        self.assertIn("readonly property bool reducedMotion", CHAT)

    def test_reopening_only_staggers_settled_visible_messages(self):
        for token in (
            "transcriptRevealToken",
            "transcriptRevealDelay",
            "!root.streaming",
            "Appearance.animation.elementMoveEnter",
            "Appearance.rounding.verysmall",
        ):
            with self.subTest(token=token):
                self.assertIn(token, MESSAGE)


class DetailTests(unittest.TestCase):
    def test_composer_has_a_context_ruler_that_warns_before_pruning(self):
        for token in (
            "id: contextRuler",
            "Ai.estimatedContextTokens",
            "Ai.estimateMessageTokens({ attachments: Ai.attachments })",
            "Saved memory",
            "pruningOnNextPrompt",
            "summarize the oldest turns",
        ):
            with self.subTest(token=token):
                self.assertIn(token, CHAT)

    def test_activity_rows_are_linked_by_an_animated_vertical_ruler(self):
        self.assertIn("id: timelineRuler", MESSAGE)
        self.assertIn("visibleStepCount > 1", MESSAGE)
        self.assertIn("Appearance.animation.elementMoveSmall", MESSAGE)

    def test_approval_body_exits_while_a_result_row_enters(self):
        self.assertIn("approvalCardKinds", AI_SERVICE)
        self.assertIn("resolvedApprovalStates", AI_SERVICE)
        self.assertIn("id: pendingCard", MESSAGE)
        self.assertIn("id: resolutionRow", MESSAGE)
        self.assertIn("Appearance.animation.elementMoveExit", MESSAGE)
        self.assertIn("Appearance.animation.elementMoveEnter", MESSAGE)

    def test_small_transcript_details_have_direct_interactions(self):
        for token in (
            "newItemCount",
            "onDoubleClicked: root.editRequested",
            "function selectPinnedModel",
            "DropArea",
        ):
            with self.subTest(token=token):
                self.assertIn(token, CHAT if token != "onDoubleClicked: root.editRequested" else MESSAGE)
        self.assertIn("togglePinned", PICKER)
        self.assertIn("modelChipTooltip", CONTROL_BAR)


if __name__ == "__main__":
    unittest.main()
