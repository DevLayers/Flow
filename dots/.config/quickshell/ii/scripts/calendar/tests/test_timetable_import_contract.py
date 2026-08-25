#!/usr/bin/env python3
"""Static contracts for Timetable-owned calendar source imports."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
TIMETABLE = ROOT / "modules" / "ii" / "cheatsheet" / "timetable"


class TimetableImportContractTests(unittest.TestCase):
    def test_sources_are_opt_in_and_available_from_each_timetable_view(self) -> None:
        config = (ROOT / "modules" / "common" / "Config.qml").read_text(encoding="utf-8")
        subscriptions = (ROOT / "services" / "CalendarSubscriptions.qml").read_text(encoding="utf-8")
        host = (ROOT / "modules" / "ii" / "cheatsheet" / "CheatsheetTimetable.qml").read_text(encoding="utf-8")
        week = (TIMETABLE / "WeekView.qml").read_text(encoding="utf-8")
        month = (TIMETABLE / "MonthView.qml").read_text(encoding="utf-8")
        panel = (TIMETABLE / "TimetableImportPanel.qml").read_text(encoding="utf-8")

        self.assertIn("property bool enable: false", config)
        self.assertIn("property JsonObject imports: JsonObject", config)
        self.assertIn("readonly property bool importsEnabled", subscriptions)
        self.assertIn("effectiveSubscriptionUrls", subscriptions)
        self.assertIn("TimetableImportPanel", host)
        self.assertIn("signal importsRequested", week)
        self.assertIn("signal importsRequested", month)
        self.assertIn("onImportsRequested: importPanel.open()", host)
        self.assertIn("FileDialog", panel)
        self.assertIn("CalendarService.importFromIcs", panel)
        self.assertIn("CalendarSubscriptions.addSubscription", panel)


if __name__ == "__main__":
    unittest.main()
