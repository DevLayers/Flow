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

    def test_schema_three_keeps_grounding_and_tool_checkpoints(self):
        with tempfile.TemporaryDirectory() as directory:
            session = {
                "id": "chat-3",
                "title": "Grounded",
                "messages": [{
                    "id": "assistant-1",
                    "role": "assistant",
                    "rawContent": "answer",
                    "searchQueries": ["latest status"],
                    "annotationSources": [{"url": "https://example.test", "text": "Source"}],
                    "toolCalls": [{"id": "call-a", "name": "get_shell_config", "args": {}}],
                }],
                "searchQueries": ["latest status"],
                "sources": [{"url": "https://example.test", "text": "Source"}],
                "toolCheckpoints": [{"serial": 4, "status": "done", "id": "get_shell_config"}],
            }
            call("save", directory, "chat-3", payload=session)
            saved = call("open", directory, "chat-3")["session"]
            self.assertEqual(saved["schema"], 3)
            self.assertEqual(saved["searchQueries"], ["latest status"])
            self.assertEqual(saved["sources"][0]["url"], "https://example.test")
            self.assertEqual(saved["toolCheckpoints"][0]["serial"], 4)

    def test_bootstrap_prunes_only_uncommitted_staging_files(self):
        with tempfile.TemporaryDirectory() as directory:
            staging = Path(directory) / ".staging"
            staging.mkdir()
            (staging / "stale.json").write_text("{}")
            (Path(directory) / "keep.txt").write_text("keep")
            result = call("bootstrap", directory)
            self.assertEqual(result["stagingPruned"], 1)
            self.assertFalse(staging.exists())
            self.assertTrue((Path(directory) / "keep.txt").exists())

    def test_trash_restore_and_purge_are_separate_operations(self):
        with tempfile.TemporaryDirectory() as directory:
            session = {"id": "chat-trash", "title": "Trash me", "messages": []}
            call("save", directory, "chat-trash", payload=session)

            removed = call("delete", directory, "chat-trash")
            self.assertNotIn("chat-trash", [entry["id"] for entry in removed["sessions"]])
            self.assertTrue((Path(directory) / ".trash" / "chat-trash.json").exists())

            restored = call("restore", directory, "chat-trash")
            self.assertIn("chat-trash", [entry["id"] for entry in restored["sessions"]])
            call("delete", directory, "chat-trash")
            purged = call("purge", directory, "chat-trash")
            self.assertEqual(purged["purged"], "chat-trash")
            self.assertFalse((Path(directory) / ".trash" / "chat-trash.json").exists())


if __name__ == "__main__":
    unittest.main()
