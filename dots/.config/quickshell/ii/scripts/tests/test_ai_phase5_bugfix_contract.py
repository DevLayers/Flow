#!/usr/bin/env python3
"""Regression contracts for the Phase 5 approval and wallpaper fixes."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
AI = (ROOT / "services/Ai.qml").read_text(encoding="utf-8")
BROKER = (ROOT / "services/ai/AiToolBroker.qml").read_text(encoding="utf-8")


def body_between(source: str, start: str, end: str) -> str:
    return source.split(start, 1)[1].split(end, 1)[0]


class ApprovalLifecycleTests(unittest.TestCase):
    def test_completed_model_round_keeps_its_approval_owner(self):
        finished = body_between(AI, "function onRunFinished(run: var)", "function commitRunSession")
        self.assertIn("root.broker.pendingCount", finished)
        self.assertIn("!waitingOnApproval", finished)

    def test_approval_can_start_after_the_provider_round_completed(self):
        begin = body_between(AI, "function beginToolExecution(message: AiMessageData", "function markToolNeedsInspection")
        self.assertIn('run.state === "completed"', begin)
        self.assertIn("root.broker.isPending(approvalKey)", begin)
        self.assertIn("completedRunOwnsApproval", begin)


if __name__ == "__main__":
    unittest.main()
