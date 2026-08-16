#!/usr/bin/env python3
"""Small contract tests for the durable AI session helper."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "ai_sessions.py"


def call(*args: str, payload=None) -> dict:
    completed = subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        input=json.dumps(payload) if payload is not None else None,
        text=True,
        capture_output=True,
        check=True,
    )
    return json.loads(completed.stdout)


class AiSessionsContractTests(unittest.TestCase):
    def test_schema_two_round_trips_to_three_and_preserves_unknown_fields(self):
        with tempfile.TemporaryDirectory() as directory:
            legacy = {
                "schema": 2,
                "id": "chat-1",
                "title": "Legacy",
                "messages": [],
                "futureField": {"keep": True},
                "run": {"runId": "run-1", "state": "needsInspection", "isSeen": False},
            }
            result = call("save", directory, "chat-1", payload=legacy)
            self.assertIn("chat-1", [entry["id"] for entry in result["sessions"]])
            entry = result["sessions"][0]
            self.assertEqual(entry["runState"], "needsInspection")
            self.assertTrue(entry["needsInspection"])
            session_file = Path(directory) / "chat-1.json"
            saved = json.loads(session_file.read_text())
            self.assertEqual(saved["schema"], 3)
            self.assertEqual(saved["futureField"], {"keep": True})

    def test_stage_commit_and_abort_are_acknowledged(self):
        with tempfile.TemporaryDirectory() as directory:
            session = {"id": "chat-2", "title": "Staged", "messages": []}
            staged = call("stage", directory, "chat-2", "op-1", payload=session)
            self.assertTrue(staged["staged"])
            self.assertFalse((Path(directory) / "chat-2.json").exists())

            committed = call("commit-staged", directory, "chat-2", "op-1")
            self.assertTrue(committed["committed"])
            self.assertTrue((Path(directory) / "chat-2.json").exists())

            staged_again = call("stage", directory, "chat-2", "op-2", payload=session)
            self.assertTrue(staged_again["staged"])
            aborted = call("abort-staged", directory, "chat-2", "op-2")
            self.assertTrue(aborted["aborted"])
            self.assertFalse((Path(directory) / ".staging" / "op-2.json").exists())


if __name__ == "__main__":
    unittest.main()
