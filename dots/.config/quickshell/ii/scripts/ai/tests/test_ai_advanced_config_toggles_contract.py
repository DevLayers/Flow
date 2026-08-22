#!/usr/bin/env python3
"""Every capability this phase added gets a real Settings toggle.

Files, OCR and voice were all wired into `Ai` and the tool registry with
their own opt-in `Config` keys, but for a while none of them had anywhere in
Settings for a person to actually flip — the folder list, the OCR switch and
the voice switch, plus the pre-existing `allowShellInLocalPolicy` gap, all
landed on the Advanced AI page in the same pass these tests pin.
"""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONFIG_PAGE = (ROOT / "modules" / "settings" / "configs" / "ai" / "AdvancedAiConfig.qml").read_text(encoding="utf-8")
CONFIG_QML = (ROOT / "modules" / "common" / "Config.qml").read_text(encoding="utf-8")


def body_between(source: str, start: str, end: str) -> str:
    return source.split(start, 1)[1].split(end, 1)[0]


class ShellInLocalPolicyToggleTests(unittest.TestCase):
    """Pre-existing gap: the option existed with no way to reach it."""

    def test_the_config_key_already_defaults_off(self):
        self.assertIn("property bool allowShellInLocalPolicy: false", CONFIG_QML)

    def test_a_switch_now_binds_to_it(self):
        section = body_between(CONFIG_PAGE, 'title: Translation.tr("Tools")', "\n    ContentSection {")
        self.assertIn("Config.options.ai.tools.allowShellInLocalPolicy", section)
        self.assertIn("checked: Config.options.ai.tools.allowShellInLocalPolicy", section)


class FilesRootsSectionTests(unittest.TestCase):
    def files_section(self) -> str:
        return body_between(CONFIG_PAGE, 'title: Translation.tr("Files the assistant may search")', "\n    ContentSection {")

    def test_the_folder_picker_falls_back_between_zenity_and_kdialog(self):
        self.assertIn("zenity --file-selection --directory", CONFIG_PAGE)
        self.assertIn("kdialog --getexistingdirectory", CONFIG_PAGE)
        self.assertIn("exit 127", CONFIG_PAGE)

    def test_a_missing_picker_surfaces_an_error_instead_of_doing_nothing(self):
        proc = body_between(CONFIG_PAGE, "onExited: (exitCode, exitStatus) => {", "\n        }")
        self.assertIn("exitCode === 127", proc)
        self.assertIn("page.folderPickerError", proc)

    def test_a_chosen_folder_is_added_through_the_integration(self):
        collector = body_between(CONFIG_PAGE, "onStreamFinished: {", "\n            }")
        self.assertIn("Ai.filesIntegration.addRoot(selectedPath)", collector)

    def test_the_list_is_driven_by_the_integrations_roots(self):
        section = self.files_section()
        self.assertIn("model: Ai.filesIntegration.roots", section)
        self.assertIn("Ai.filesIntegration.removeRoot(rootRow.index)", section)

    def test_the_empty_state_says_search_will_not_work_yet(self):
        section = self.files_section()
        self.assertIn("Ai.filesIntegration.roots.length === 0", section)
        self.assertIn("PagePlaceholder", section)


class VisionSectionTests(unittest.TestCase):
    def test_ocr_switch_binds_both_ways(self):
        section = body_between(CONFIG_PAGE, 'title: Translation.tr("Vision")', "\n    ContentSection {")
        self.assertIn("checked: Config.options.ai.vision.ocrEnabled", section)
        self.assertIn("Config.options.ai.vision.ocrEnabled = checked;", section)

    def test_tooltip_is_honest_about_whether_ocr_would_do_anything(self):
        section = body_between(CONFIG_PAGE, 'title: Translation.tr("Vision")', "\n    ContentSection {")
        self.assertIn("Ai.tesseractPresent", section)

    def test_the_config_default_is_on(self):
        vision_block = body_between(CONFIG_QML, "property JsonObject vision: JsonObject {", "}")
        self.assertIn("property bool ocrEnabled: true", vision_block)


class VoiceSectionTests(unittest.TestCase):
    def voice_section(self) -> str:
        return body_between(CONFIG_PAGE, 'title: Translation.tr("Voice")', "\n}")

    def test_voice_switch_binds_both_ways(self):
        section = self.voice_section()
        self.assertIn("checked: Config.options.ai.voice.enabled", section)
        self.assertIn("Config.options.ai.voice.enabled = checked;", section)

    def test_the_config_default_is_on(self):
        voice_block = body_between(CONFIG_QML, "property JsonObject voice: JsonObject {", "}")
        self.assertIn("property bool enabled: true", voice_block)

    def test_status_row_reflects_the_shared_service_not_a_local_guess(self):
        section = self.voice_section()
        self.assertIn("Ai.voiceService.available", section)
        self.assertIn("Ai.voiceService.unavailableReason()", section)
        self.assertIn("Ai.voiceService.backendName", section)

    def test_check_again_forces_redetection_not_a_shell_restart(self):
        section = self.voice_section()
        self.assertIn("Ai.voiceService.redetect()", section)


if __name__ == "__main__":
    unittest.main()
