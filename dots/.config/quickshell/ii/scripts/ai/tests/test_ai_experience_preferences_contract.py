"""Contracts for persisted AI chat presentation preferences."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[3]
CONFIG = (ROOT / "modules/common/Config.qml").read_text(encoding="utf-8")
MESSAGE = (ROOT / "modules/ii/sidebarPolicies/aiChat/AiMessage.qml").read_text(encoding="utf-8")
TEXT_BLOCK = (ROOT / "services/ai/blocks/AiMessageTextBlock.qml").read_text(encoding="utf-8")
CODE_BLOCK = (ROOT / "services/ai/blocks/AiMessageCodeBlock.qml").read_text(encoding="utf-8")


class AiExperiencePreferenceTests(unittest.TestCase):
    def test_sidebar_preferences_are_typed_and_persisted(self):
        for token in (
            'property string density: "comfortable"',
            "property bool showTimestamps",
            "property bool showResponseTime",
            "property bool showAnswerModel",
            "property string activityDefault",
            "property bool autoScroll",
            "property string sendKey",
            "property bool renderMarkdown",
            "property bool renderLatex",
            "property bool codeWrap",
            "property bool codeLineNumbers",
            "property bool collapseLongAnswers",
            "property list<string> barKeys",
            "property string greeting",
            "property bool emptyStateKeys",
            "property bool soundOnAnswer",
        ):
            with self.subTest(token=token):
                self.assertIn(token, CONFIG)

    def test_transcript_uses_display_and_long_answer_preferences(self):
        for token in (
            "Config.options.sidebar.ai.density",
            "activityDefaultMode",
            "collapseLongAnswer",
            "Show full answer",
            "showTimestamps",
            "showResponseTime",
            "showAnswerModel",
        ):
            with self.subTest(token=token):
                self.assertIn(token, MESSAGE)

    def test_markdown_latex_and_code_preferences_reach_the_renderers(self):
        self.assertIn("Config.options.sidebar.ai.renderMarkdown", TEXT_BLOCK)
        self.assertIn("Config.options.sidebar.ai.renderLatex", TEXT_BLOCK)
        self.assertIn("property bool wrapCode: Config.options.sidebar.ai.codeWrap", CODE_BLOCK)
        self.assertIn("property bool showLineNumbers: Config.options.sidebar.ai.codeLineNumbers", CODE_BLOCK)


if __name__ == "__main__":
    unittest.main()
