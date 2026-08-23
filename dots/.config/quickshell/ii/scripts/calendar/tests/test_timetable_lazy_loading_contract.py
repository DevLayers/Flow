#!/usr/bin/env python3
"""Static contracts for progressive timetable and ESPN loading."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CHEATSHEET = ROOT / "modules" / "ii" / "cheatsheet"
TIMETABLE = CHEATSHEET / "timetable"


class TimetableLazyLoadingContractTests(unittest.TestCase):
    def test_timetable_tab_and_selected_view_incubate_across_frames(self) -> None:
        cheatsheet = (CHEATSHEET / "Cheatsheet.qml").read_text(encoding="utf-8")
        host = (CHEATSHEET / "CheatsheetTimetable.qml").read_text(encoding="utf-8")

        self.assertIn('asynchronous: modelData.icon === "calendar_month"', cheatsheet)
        self.assertGreaterEqual(host.count("asynchronous: true"), 2)

    def test_sports_start_only_after_the_base_view_is_ready(self) -> None:
        host = (CHEATSHEET / "CheatsheetTimetable.qml").read_text(encoding="utf-8")

        self.assertIn("readonly property bool activeViewReady", host)
        self.assertIn("id: sportsActivationTimer", host)
        self.assertIn("sportsEnabled: root.sportsReady", host)
        self.assertIn("SportsService.acquireTimetableSubscriber()", host)
        self.assertNotIn("Component.onCompleted: SportsService.acquireTimetableSubscriber()", host)

    def test_month_cells_are_materialized_progressively(self) -> None:
        month = (TIMETABLE / "MonthView.qml").read_text(encoding="utf-8")
        cell = (TIMETABLE / "MonthDayCell.qml").read_text(encoding="utf-8")

        self.assertIn("property bool sportsEnabled: false", month)
        self.assertIn("property int loadedCellCount: 0", month)
        self.assertIn("readonly property bool initialLoadComplete", month)
        self.assertIn("id: cellLoadTimer", month)
        self.assertIn("model: root.loadedCellCount", month)
        self.assertIn("sportsEnabled: root.sportsEnabled", month)
        self.assertIn("property bool sportsEnabled: false", cell)
        self.assertIn("root.sportsEnabled ? SportsService.gamesForDate", cell)

    def test_week_columns_are_materialized_progressively(self) -> None:
        week = (TIMETABLE / "WeekView.qml").read_text(encoding="utf-8")

        self.assertIn("property bool sportsEnabled: false", week)
        self.assertIn("property int loadedDayCount: 0", week)
        self.assertIn("readonly property bool initialLoadComplete", week)
        self.assertIn("id: dayLoadTimer", week)
        self.assertIn("days: root.days.slice(0, root.loadedDayCount)", week)
        self.assertIn("model: root.loadedDayCount", week)

    def test_espn_projection_has_a_per_frame_time_budget(self) -> None:
        sports = (ROOT / "services" / "SportsService.qml").read_text(encoding="utf-8")

        self.assertIn("readonly property int timetableProjectionBudgetMs", sports)
        self.assertIn("id: timetableProjectionTimer", sports)
        self.assertIn("Date.now() - startedAt < root.timetableProjectionBudgetMs", sports)
        self.assertIn("if (!root.timetableActive)", sports)
        self.assertIn("function cachedRangeSources()", sports)
        self.assertNotIn("root.timetableProjectionSource = root.cachedRangeEvents()", sports)
        self.assertIn("timetableProjectionCompactEvents", sports)
        self.assertNotIn("const rawEvents = root.timetableProjectionRawEvents", sports)


if __name__ == "__main__":
    unittest.main()
