#!/usr/bin/env python3
"""Regression contracts for the Timetable's persistent khal default."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


class TimetableCalendarDefaultContractTests(unittest.TestCase):
    def test_created_event_remembers_its_writable_khal_calendar(self) -> None:
        config = (ROOT / "modules" / "common" / "Config.qml").read_text(encoding="utf-8")
        service = (ROOT / "services" / "CalendarService.qml").read_text(encoding="utf-8")
        helper = (ROOT / "scripts" / "calendar" / "ics.py").read_text(encoding="utf-8")

        self.assertIn("property string defaultCalendar", config)
        self.assertIn("function setDefaultCalendar(name, persist = true)", service)
        self.assertIn("root.setDefaultCalendar(persisted, false)", service)
        self.assertIn("root.setDefaultCalendar(khalDefault, false)", service)
        self.assertIn("root.setDefaultCalendar(target)", service)
        self.assertIn('"defaultCalendar": default_calendar', helper)


if __name__ == "__main__":
    unittest.main()
