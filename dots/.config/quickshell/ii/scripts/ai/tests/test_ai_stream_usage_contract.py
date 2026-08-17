#!/usr/bin/env python3
"""Regression contracts for streamed answers and their usage accounting."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
OPENAI_STRATEGY = (ROOT / "services" / "ai" / "OpenAiCompatStrategy.qml").read_text(encoding="utf-8")
AI_SERVICE = (ROOT / "services" / "Ai.qml").read_text(encoding="utf-8")
AI_MESSAGE = (ROOT / "services" / "ai" / "AiMessageData.qml").read_text(encoding="utf-8")
AI_USAGE = (ROOT / "services" / "AiUsage.qml").read_text(encoding="utf-8")
SEARCH_MESSAGE = (ROOT / "modules" / "ii" / "overview" / "AiChatPanelMessage.qml").read_text(encoding="utf-8")


class AiStreamUsageContractTests(unittest.TestCase):
    def test_native_ollama_uses_native_generation_and_terminal_counters(self):
        self.assertIn("num_predict: maxOutputTokens(model)", OPENAI_STRATEGY)
        self.assertIn("data?.prompt_eval_count", OPENAI_STRATEGY)
        self.assertIn("data?.eval_count", OPENAI_STRATEGY)
        self.assertIn("nativeMessage.content", OPENAI_STRATEGY)

    def test_finished_stream_is_accounted_after_the_last_frame(self):
        on_line = AI_SERVICE.split("onLine: data =>", 1)[1].split("onRetrying:", 1)[0]
        on_finished = AI_SERVICE.split("onFinished: (reason, status, code) =>", 1)[1]
        self.assertNotIn("root.markDone(requester.message)", on_line)
        self.assertIn("root.markDone(message)", on_finished)

    def test_turn_owns_usage_and_session_persists_it(self):
        for token_property in ("inputTokens", "outputTokens", "totalTokens"):
            self.assertIn(f"property int {token_property}: -1", AI_MESSAGE)
            self.assertIn(f'"{token_property}": message.{token_property}', AI_SERVICE)
            self.assertIn(f'"{token_property}": data.{token_property} ?? -1', AI_SERVICE)

    def test_usage_waits_for_its_persisted_ledger(self):
        self.assertIn("property var pendingResponses: []", AI_USAGE)
        self.assertIn("root.flushPendingResponses()", AI_USAGE)
        self.assertIn("root.applyResponse(record)", AI_USAGE)

    def test_restored_final_answer_has_a_direct_transcript_dependency(self):
        self.assertIn("readonly property string transcriptContent", SEARCH_MESSAGE)
        self.assertIn("blocksForContent(root.transcriptContent)", SEARCH_MESSAGE)


if __name__ == "__main__":
    unittest.main()
