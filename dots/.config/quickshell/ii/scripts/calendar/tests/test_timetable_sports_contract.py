#!/usr/bin/env python3
"""Static contracts for read-only ESPN games in the timetable."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
TIMETABLE = ROOT / "modules" / "ii" / "cheatsheet" / "timetable"
SPORTS_SERVICE = (ROOT / "services" / "SportsService.qml").read_text(encoding="utf-8")


class TimetableSportsContractTests(unittest.TestCase):
    def test_sports_projection_is_read_only_and_never_written_to_khal(self) -> None:
        self.assertIn("readOnly: true", SPORTS_SERVICE)
        self.assertIn("sportEvent: true", SPORTS_SERVICE)
        self.assertIn('uid: ""', SPORTS_SERVICE)
        self.assertNotIn("CalendarService.addEvent", SPORTS_SERVICE)
        self.assertNotIn("CalendarService.updateEvent", SPORTS_SERVICE)
        self.assertNotIn("CalendarService.removeEvent", SPORTS_SERVICE)

        sidebar = (TIMETABLE / "MonthEventSidebar.qml").read_text(encoding="utf-8")
        self.assertIn("if (eventData.sportEvent === true)", sidebar)
        self.assertIn("SportsService.focusGame(eventData)", sidebar)
        self.assertIn("} else {\n            CalendarService.readEvent", sidebar)

    def test_schedule_and_full_details_use_persistent_cache(self) -> None:
        directories = (ROOT / "modules" / "common" / "Directories.qml").read_text(encoding="utf-8")

        self.assertIn("sportsCachePath", directories)
        self.assertIn("FileView {", SPORTS_SERVICE)
        self.assertIn("atomicWrites: true", SPORTS_SERVICE)
        self.assertIn("scheduleCache", SPORTS_SERVICE)
        self.assertIn("detailsCache", SPORTS_SERVICE)
        self.assertIn("scoreboard?dates=", SPORTS_SERVICE)
        self.assertIn("/summary?event=", SPORTS_SERVICE)
        self.assertIn("data: parsed", SPORTS_SERVICE)

    def test_user_leagues_and_team_filter_drive_the_projection(self) -> None:
        self.assertIn("Config.options.bar.sports.monitoredLeagues", SPORTS_SERVICE)
        self.assertIn("property string teamFilter: Config.options.bar.sports.teamFilter", SPORTS_SERVICE)
        self.assertIn("matchesConfiguredTeams", SPORTS_SERVICE)
        self.assertIn("monitoredLeagueEntries", SPORTS_SERVICE)

    def test_both_views_request_and_render_espn_games(self) -> None:
        month = (TIMETABLE / "MonthView.qml").read_text(encoding="utf-8")
        day_cell = (TIMETABLE / "MonthDayCell.qml").read_text(encoding="utf-8")
        week = (TIMETABLE / "WeekView.qml").read_text(encoding="utf-8")

        self.assertIn("SportsService.requestTimetableRange", month)
        self.assertIn("SportsService.gamesForDate", day_cell)
        self.assertNotIn("SportsService.allGames", day_cell)
        self.assertIn("data?.sportEvent === true ||", day_cell)
        self.assertIn("SportsService.requestTimetableRange", week)
        self.assertIn("SportsService.gamesForDate(date)", week)
        self.assertIn("eventSidebar.showEvent(event)", week)

    def test_live_refresh_runs_only_for_an_active_timetable(self) -> None:
        host = (ROOT / "modules" / "ii" / "cheatsheet" / "CheatsheetTimetable.qml").read_text(encoding="utf-8")

        self.assertIn("SportsService.acquireTimetableSubscriber()", host)
        self.assertIn("SportsService.releaseTimetableSubscriber()", host)
        self.assertIn("id: timetableRefreshTimer", SPORTS_SERVICE)
        self.assertIn("running: root.timetableActive", SPORTS_SERVICE)
        self.assertIn("rangeNeedsLiveRefresh", SPORTS_SERVICE)
        self.assertIn("gameNeedsLiveRefresh", SPORTS_SERVICE)
        self.assertIn("gameNearKickoff", SPORTS_SERVICE)
        self.assertIn("pregameDetailsCacheTtlMs", SPORTS_SERVICE)
        self.assertIn("root.requestGameDetails(focused, root.gameNeedsLiveRefresh(focused))", SPORTS_SERVICE)
        self.assertIn("timetableRangeCoversToday", SPORTS_SERVICE)
        self.assertIn("!timetableActive || !root.timetableRangeCoversToday", SPORTS_SERVICE)

    def test_sidebar_surfaces_rich_espn_summary_sections(self) -> None:
        details = (TIMETABLE / "SportsEventDetails.qml").read_text(encoding="utf-8")

        for field in (
            "rosters",
            "boxscore",
            "leaders",
            "keyEvents",
            "commentary",
            "lastFiveGames",
            "seasonseries",
            "news",
            "videos",
            "odds",
            "officials",
            "broadcasts",
        ):
            self.assertIn(field, details)
        self.assertIn("ESPN data retained in cache", details)
        self.assertIn("Qt.openUrlExternally", details)


if __name__ == "__main__":
    unittest.main()
