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

    def test_month_renders_games_and_week_routes_them_to_a_day_browser(self) -> None:
        month = (TIMETABLE / "MonthView.qml").read_text(encoding="utf-8")
        day_cell = (TIMETABLE / "MonthDayCell.qml").read_text(encoding="utf-8")
        week = (TIMETABLE / "WeekView.qml").read_text(encoding="utf-8")

        self.assertIn("SportsService.requestTimetableRange", month)
        self.assertIn("SportsService.gamesForDate", day_cell)
        self.assertNotIn("SportsService.allGames", day_cell)
        self.assertIn("data?.sportEvent === true ||", day_cell)
        self.assertIn("SportsService.requestTimetableRange", week)
        self.assertIn("SportsService.gamesForDate(date)", week)
        self.assertIn("readonly property var sportsDays", week)
        self.assertIn("eventSidebar.showSportsDay", week)
        self.assertIn("sportsListOnly: true", week)
        self.assertNotIn(".concat(SportsService.gamesForDate(date))", week)

    def test_month_sports_chips_use_a_distinct_tertiary_fill(self) -> None:
        chip = (TIMETABLE / "MonthEventChip.qml").read_text(encoding="utf-8")

        self.assertIn("readonly property bool sportEvent", chip)
        self.assertIn("Appearance.colors.colTertiaryContainer", chip)
        self.assertIn("Appearance.colors.colTertiaryContainerHover", chip)
        self.assertIn('text: "sports_score"', chip)
        self.assertIn("visible: !root.allDay && !root.sportEvent", chip)

    def test_day_sidebar_separates_calendar_events_from_sports(self) -> None:
        sidebar = (TIMETABLE / "MonthEventSidebar.qml").read_text(encoding="utf-8")
        row = (TIMETABLE / "MonthDayEventRow.qml").read_text(encoding="utf-8")

        self.assertIn("property bool sportsListOnly: false", sidebar)
        self.assertIn("function showSportsDay(date)", sidebar)
        self.assertIn("readonly property var dayCalendarEvents", sidebar)
        self.assertIn("readonly property var daySports", sidebar)
        self.assertIn('text: Translation.tr("Sports").toUpperCase()', sidebar)
        self.assertIn("model: root.sportsListOnly ? [] : root.dayCalendarEvents", sidebar)
        self.assertIn("model: root.daySports", sidebar)
        self.assertIn("Appearance.colors.colTertiaryContainer", row)
        self.assertIn("Appearance.colors.colTertiaryContainerHover", row)
        self.assertIn('text: "sports_score"', row)

    def test_read_only_details_use_the_full_sidebar_height(self) -> None:
        sidebar = (TIMETABLE / "MonthEventSidebar.qml").read_text(encoding="utf-8")

        self.assertIn("bottom: root.eventReadOnly ? parent.bottom : detailsActions.top", sidebar)
        self.assertIn("bottomMargin: root.eventReadOnly ? 0 : 12", sidebar)

    def test_empty_espn_collections_render_real_empty_states(self) -> None:
        details = (TIMETABLE / "SportsEventDetails.qml").read_text(encoding="utf-8")

        self.assertIn("readonly property var populatedRosters", details)
        self.assertIn("readonly property var populatedBoxscoreTeams", details)
        self.assertIn("readonly property var populatedLeaders", details)
        self.assertIn("component EmptySection", details)
        self.assertIn("root.populatedRosters.length === 0", details)
        self.assertIn("root.populatedBoxscoreTeams.length === 0", details)
        self.assertIn("root.populatedLeaders.length === 0", details)
        self.assertIn('Translation.tr("Unavailable")', details)

    def test_sports_detail_rows_receive_the_sidebar_width(self) -> None:
        details = (TIMETABLE / "SportsEventDetails.qml").read_text(encoding="utf-8")
        detail_component = details.split("component DetailRow: Rectangle", 1)[1]

        self.assertIn("Layout.fillWidth: true", detail_component)
        self.assertIn("text: detailRow.caption", detail_component)
        self.assertIn("text: detailRow.value", detail_component)
        self.assertNotIn("parent.parent.parent.caption", detail_component)

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
