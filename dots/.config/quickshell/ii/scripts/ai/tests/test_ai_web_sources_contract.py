#!/usr/bin/env python3
"""Source provenance and freshness contracts for the web integration."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE = (ROOT / "scripts" / "ai" / "ai_web.py").read_text(encoding="utf-8")
class AiWebSourceTests(unittest.TestCase):
    def test_qml_tracks_source_freshness_and_keeps_a_short_cache(self):
        ai = (ROOT / "services" / "Ai.qml").read_text(encoding="utf-8")
        self.assertIn("property var webCache", ai)
        self.assertIn("webCacheTtlMs", ai)
        self.assertIn("function decorateWebPayload", ai)
        self.assertIn("fetchedAt", ai)
        self.assertIn("freshness", ai)
        self.assertIn("cacheHit: true", ai)

    def test_qml_respects_web_mode_off_before_running_a_process(self):
        ai = (ROOT / "services" / "Ai.qml").read_text(encoding="utf-8")
        self.assertIn('root.webMode === "off"', ai)


if __name__ == "__main__":
    unittest.main()
