"""Contracts for local Ollama catalogue pulls in the AI sidebar."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[3]
SERVICE = (ROOT / "services/ai/OllamaCatalog.qml").read_text(encoding="utf-8")
AI = (ROOT / "services/Ai.qml").read_text(encoding="utf-8")
PAGE = (ROOT / "services/ai/blocks/AiOllamaModelsPage.qml").read_text(encoding="utf-8")
PICKER = (ROOT / "services/ai/blocks/AiModelPickerPopover.qml").read_text(encoding="utf-8")
CONTROL_BAR = (ROOT / "modules/ii/sidebarPolicies/aiChat/ChatControlBar.qml").read_text(encoding="utf-8")
AI_CHAT = (ROOT / "modules/ii/sidebarPolicies/AiChat.qml").read_text(encoding="utf-8")


class OllamaPullServiceTests(unittest.TestCase):
    def test_service_imports_the_quickshell_singleton_type(self):
        self.assertIn("\nimport Quickshell\n", SERVICE)

    def test_service_imports_the_translation_singleton_used_by_suggestions(self):
        self.assertIn("\nimport qs.services\n", SERVICE)

    def test_catalogue_is_curated_but_accepts_any_valid_library_tag(self):
        self.assertIn("readonly property var models", SERVICE)
        self.assertIn('name: "qwen3.5:9b"', SERVICE)
        self.assertIn("function normalizeModelName(modelName): string", SERVICE)
        self.assertIn("if (!/^[A-Za-z0-9]", SERVICE)
        self.assertIn('segment === "." || segment === ".."', SERVICE)

    def test_pull_is_one_local_streamed_operation_with_no_shell_interpolation(self):
        self.assertIn('endpoint: "http://127.0.0.1:11434/api/pull"', SERVICE)
        self.assertIn('"curl", "--no-buffer", "--silent", "--show-error"', SERVICE)
        self.assertIn('"--data-binary", "@-"', SERVICE)
        self.assertIn('pullProc.write(JSON.stringify({ name: normalized, stream: true })', SERVICE)
        self.assertIn("stdinEnabled = false;", SERVICE)
        self.assertIn("stdout: SplitParser", SERVICE)
        self.assertNotIn("bash", SERVICE)

    def test_pull_tracks_progress_and_can_be_cancelled(self):
        for token in (
            "property real pullProgress: -1",
            "function cancelPull()",
            "root.pullState = \"cancelled\"",
            "completed / total",
            "status.toLowerCase() === \"success\"",
            "signal pullSucceeded(string modelName)",
        ):
            with self.subTest(token=token):
                self.assertIn(token, SERVICE)

    def test_success_refreshes_models_used_by_the_chat_and_rag_picker(self):
        self.assertIn("function refreshOllamaModels()", AI)
        self.assertIn("AiRagService.refreshInstalledModels();", AI)
        self.assertIn("root.ollamaRefreshPending = true;", AI)
        self.assertIn("Qt.callLater(root.refreshOllamaModels);", AI)


class OllamaSidebarCatalogueTests(unittest.TestCase):
    def test_ollama_catalogue_is_reachable_from_its_provider_group(self):
        self.assertIn('kind: "ollama-catalog"', PICKER)
        self.assertIn("root.ollamaModelsOpen = true", PICKER)
        self.assertIn("AiOllamaModelsPage", PICKER)
        self.assertIn("function closeModelCatalogue()", PICKER)
        self.assertIn("function refreshModelCatalogue()", PICKER)
        self.assertIn('providerIds[i] === "ollama"', PICKER)
        self.assertIn("models.length === 0 && !hasCatalogueEntry", PICKER)

    def test_page_makes_download_explicit_and_shows_live_state(self):
        self.assertIn("Nothing is downloaded until you press Pull.", PAGE)
        self.assertIn("OllamaCatalog.pull(modelName)", PAGE)
        self.assertIn("OllamaCatalog.cancelPull()", PAGE)
        self.assertIn("OllamaCatalog.pullProgress", PAGE)
        self.assertIn("Ai.refreshOllamaModels();", PAGE)

    def test_canvas_header_navigates_both_catalogue_pages(self):
        self.assertIn("readonly property bool modelCatalogueOpen", CONTROL_BAR)
        self.assertIn("modelCatalogueTitle", CONTROL_BAR)
        self.assertIn("picker.closeModelCatalogue()", CONTROL_BAR)

    def test_sidebar_does_not_steal_unaccepted_input_keys_from_a_canvas_field(self):
        keys_handler = AI_CHAT.split("Keys.onPressed: event => {", 1)[1].split("// ── References", 1)[0]
        self.assertIn("if (root.canvasViewOpen)", keys_handler)
        self.assertLess(keys_handler.index("if (root.canvasViewOpen)"), keys_handler.index("messageInputField.forceActiveFocus()"))

    def test_more_controls_can_open_the_ollama_catalogue_directly(self):
        self.assertIn('root.activePopover === "ollamaModels"', CONTROL_BAR)
        self.assertIn("id: ollamaModelsComponent", CONTROL_BAR)
        self.assertIn('root.openView("ollamaModels", "more")', CONTROL_BAR)


if __name__ == "__main__":
    unittest.main()
