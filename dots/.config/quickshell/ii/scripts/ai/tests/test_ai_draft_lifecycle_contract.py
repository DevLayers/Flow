#!/usr/bin/env python3
"""Regression contracts for the QML AI draft lifecycle.

The composer can accept input before its on-disk draft store has finished
loading.  These checks keep that early input, and a successful send that
clears it, from being overwritten by the delayed hydration path.
"""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
AI_QML = (ROOT / "services" / "Ai.qml").read_text(encoding="utf-8")
SEARCH_WIDGET_QML = (ROOT / "modules" / "ii" / "overview" / "SearchWidget.qml").read_text(encoding="utf-8")


class AiDraftLifecycleContractTests(unittest.TestCase):
    def test_preload_draft_mutations_are_flushed_before_hydration(self):
        self.assertTrue("property var pendingDraftMutations" in AI_QML)
        self.assertTrue("function writeOrStageDraft" in AI_QML)
        self.assertTrue("function flushPendingDraftMutations" in AI_QML)
        self.assertTrue("root.flushPendingDraftMutations()" in AI_QML)

    def test_started_submission_clears_the_draft_session_captured_at_submit(self):
        self.assertTrue("draftSessionId: root.sessionDraftId()" in AI_QML)
        self.assertTrue("root.clearDraftForSession(pending.draftSessionId" in AI_QML)

    def test_leaving_ai_resets_only_the_search_surface_state(self):
        self.assertTrue("function resetAiSearchState" in SEARCH_WIDGET_QML)
        self.assertTrue("root.searchingText = \"\"" in SEARCH_WIDGET_QML)
        self.assertTrue("root.resetAiSearchState(false)" in SEARCH_WIDGET_QML)


if __name__ == "__main__":
    unittest.main()
