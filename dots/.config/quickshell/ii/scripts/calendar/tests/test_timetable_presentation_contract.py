#!/usr/bin/env python3
"""Static contracts for the timetable editor presentation."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
TIMETABLE = ROOT / "modules" / "ii" / "cheatsheet" / "timetable"


class TimetablePresentationContractTests(unittest.TestCase):
    def test_week_zoom_uses_persistent_discrete_slot_heights(self) -> None:
        persistent = (ROOT / "modules" / "common" / "Persistent.qml").read_text(encoding="utf-8")
        week = (TIMETABLE / "WeekView.qml").read_text(encoding="utf-8")

        self.assertIn("property int timetableSlotHeight: 56", persistent)
        self.assertIn("readonly property list<int> slotHeightSteps: [40, 56, 72, 96, 120]", week)
        self.assertIn("property int slotHeight: Persistent.states.cheatsheet.timetableSlotHeight", week)
        self.assertIn("function zoomSlotHeight(direction, viewportY)", week)
        self.assertIn("acceptedModifiers: Qt.ControlModifier", week)
        self.assertIn("Persistent.states.cheatsheet.timetableSlotHeight = nextHeight", week)
        self.assertIn("const focalMinutes = (styledFlickable.contentY + focalY) / oldPixelsPerMinute", week)

    def test_week_grid_draws_one_shared_hour_ruler(self) -> None:
        week = (TIMETABLE / "WeekView.qml").read_text(encoding="utf-8")
        time_column = (TIMETABLE / "TimetableTimeColumn.qml").read_text(encoding="utf-8")

        self.assertIn("property int timeColumnWidth: 56", week)
        self.assertEqual(week.count("id: gridLineLayer"), 1)
        self.assertIn("model: root.totalSlots", week)
        self.assertIn("y: parent.height / 2", week)
        self.assertIn("H.withOpacity(Appearance.colors.colOutlineVariant", week)
        self.assertIn("anchors.right: parent.right", time_column)
        self.assertIn("horizontalAlignment: Text.AlignRight", time_column)

    def test_all_day_lane_caps_rows_and_expands_with_internal_scroll(self) -> None:
        week = (TIMETABLE / "WeekView.qml").read_text(encoding="utf-8")
        header = (TIMETABLE / "TimetableHeader.qml").read_text(encoding="utf-8")

        self.assertIn("property bool allDayExpanded: false", week)
        self.assertIn("readonly property int collapsedAllDayRows: 2", week)
        self.assertIn("readonly property int expandedAllDayRows: 5", week)
        self.assertIn("readonly property int visibleAllDayRows", week)
        self.assertIn("Behavior on headerHeight", week)
        self.assertIn("visibleAllDayRows: root.visibleAllDayRows", week)
        self.assertIn("onAllDayExpansionRequested: expanded => root.allDayExpanded = expanded", week)
        self.assertIn("id: allDayArea", header)
        self.assertIn("interactive: headerRow.expanded && contentHeight > height", header)
        self.assertIn("Translation.tr(\"%1 more\").arg(String(dayDelegate.hiddenChipCount))", header)

    def test_week_day_columns_shade_pre_dawn_and_evening(self) -> None:
        day_column = (TIMETABLE / "TimetableDayColumn.qml").read_text(encoding="utf-8")

        self.assertIn("readonly property int sunriseMinutes", day_column)
        self.assertIn("H.parseTimeToMinutes(Weather.data?.sunrise", day_column)
        self.assertIn("readonly property int sunsetMinutes", day_column)
        self.assertIn("readonly property bool hasSolarTimes", day_column)
        self.assertIn("id: preDawnShade", day_column)
        self.assertIn("id: eveningShade", day_column)
        self.assertEqual(day_column.count("color: H.withOpacity(Appearance.colors.colLayer0, 0.22)"), 2)

    def test_month_density_modes_are_persistent_and_reduce_cell_chrome(self) -> None:
        persistent = (ROOT / "modules" / "common" / "Persistent.qml").read_text(encoding="utf-8")
        month = (TIMETABLE / "MonthView.qml").read_text(encoding="utf-8")
        cell = (TIMETABLE / "MonthDayCell.qml").read_text(encoding="utf-8")

        self.assertIn('property string timetableMonthDensity: "compact"', persistent)
        self.assertIn('readonly property var densityModes: ["comfortable", "compact", "dots"]', month)
        self.assertIn("Persistent.states.cheatsheet.timetableMonthDensity = root.densityModes[index]", month)
        self.assertIn("densityMode: root.densityMode", month)
        self.assertIn("readonly property real headerHeight: 22", cell)
        self.assertIn("readonly property real chipSpacing: 2", cell)
        self.assertIn('readonly property real chipHeight: root.densityMode === "comfortable" ? 24 : 16', cell)
        self.assertIn('visible: root.densityMode === "dots" && root.entryCount > 0', cell)
        self.assertIn("id: densityDots", cell)
        self.assertEqual(cell.count("root.isToday || root.isTomorrow || cellPointer.containsMouse"), 2)

    def test_week_navigation_uses_a_real_anchor_and_shared_picker(self) -> None:
        helper = (TIMETABLE / "TimetableHelpers.js").read_text(encoding="utf-8")
        week = (TIMETABLE / "WeekView.qml").read_text(encoding="utf-8")

        self.assertIn("function weekStartFor(date, firstDayOfWeek, todayFirst)", helper)
        self.assertIn("property date viewWeekStart", week)
        self.assertIn("function shiftWeek(delta)", week)
        self.assertIn("function goToday()", week)
        self.assertIn('datePicker.purpose = "navigate"', week)
        self.assertIn('if (datePicker.purpose === "navigate")', week)
        self.assertIn("const calendarEvents = CalendarService.eventsByDay", week)
        self.assertNotIn("CalendarService.eventsInWeek", week)
        self.assertIn("onRevealKeyChanged: dayColDelegate.replayEntrance()", week)

    def test_day_three_day_week_and_month_share_the_persisted_selector(self) -> None:
        persistent = (ROOT / "modules" / "common" / "Persistent.qml").read_text(encoding="utf-8")
        host = (ROOT / "modules" / "ii" / "cheatsheet" / "CheatsheetTimetable.qml").read_text(encoding="utf-8")
        selector = (TIMETABLE / "TimetableViewSwitch.qml").read_text(encoding="utf-8")
        week = (TIMETABLE / "WeekView.qml").read_text(encoding="utf-8")

        self.assertIn('// "day" | "threeDay" | "week" | "month"', persistent)
        self.assertIn('readonly property var supportedModes: ["day", "threeDay", "week", "month"]', host)
        self.assertIn('active: root.activeMode !== "month"', host)
        self.assertIn("viewMode: root.activeMode", host)
        self.assertIn('readonly property var modes: ["day", "threeDay", "week", "month"]', selector)
        self.assertEqual(selector.count('"icon":'), 4)
        self.assertIn("Persistent.states.cheatsheet.timetableView = root.modes[index]", selector)
        self.assertIn('readonly property int visibleDayCount: root.viewMode === "day" ? 1 : (root.viewMode === "threeDay" ? 3 : 7)', week)
        self.assertIn("for (let i = 0; i < root.visibleDayCount; i++)", week)
        self.assertIn("delta * root.visibleDayCount", week)
        self.assertIn("onViewModeChanged: {", week)

    def test_week_and_month_share_semantic_event_colors(self) -> None:
        helper = (TIMETABLE / "TimetableHelpers.js").read_text(encoding="utf-8")
        week = (TIMETABLE / "WeekView.qml").read_text(encoding="utf-8")
        block = (TIMETABLE / "EventBlock.qml").read_text(encoding="utf-8")
        header = (TIMETABLE / "TimetableHeader.qml").read_text(encoding="utf-8")

        self.assertIn("function chipColor(event, palette)", helper)
        self.assertIn("H.chipColor(eventData?.sourceEvent ?? eventData, Appearance.colors)", block)
        self.assertIn("H.chipColor(modelData?.sourceEvent ?? modelData, Appearance.colors)", header)
        self.assertIn("H.chipColor(root.timedMutationEvent, Appearance.colors)", week)
        self.assertNotIn("getEventColorRadial", helper + week + block)
        self.assertNotIn("maxLogicalDistance", week + block)

    def test_week_surfaces_do_not_use_rectangle_borders(self) -> None:
        for name in ("EventBlock.qml", "TimetableDayColumn.qml", "TimetableHeader.qml", "TimetableNextEventFAB.qml"):
            source = (TIMETABLE / name).read_text(encoding="utf-8")
            self.assertNotIn("border.width", source, name)
            self.assertNotIn("border.color", source, name)

    def test_color_picker_uses_semantic_hover_tokens(self) -> None:
        helper = (TIMETABLE / "TimetableHelpers.js").read_text(encoding="utf-8")
        picker = (TIMETABLE / "ColorPickerRow.qml").read_text(encoding="utf-8")

        for token in ("primary", "secondary", "tertiary", "error", "primarycontainer", "secondarycontainer", "tertiarycontainer", "errorcontainer"):
            self.assertIn(f'case "{token}"', helper)
        self.assertIn("function themeHoverColorForToken", helper)
        self.assertIn("H.themeHoverColorForToken(modelData.token, Appearance.colors)", picker)
        self.assertNotIn("ColorUtils.mix(tokenColor, Appearance.colors.colOnSurface", picker)
        self.assertIn("import qs.modules.common.functions", picker)

    def test_color_tooltips_use_the_delegate_hover_state(self) -> None:
        picker = (TIMETABLE / "ColorPickerRow.qml").read_text(encoding="utf-8")

        self.assertIn("id: colorButton", picker)
        self.assertIn("extraVisibleCondition: colorButton.hovered", picker)
        self.assertNotIn("extraVisibleCondition: parent.hovered", picker)

    def test_task_tooltip_reads_the_hover_handler_state(self) -> None:
        task_chip = (TIMETABLE / "TaskChip.qml").read_text(encoding="utf-8")

        self.assertIn("extraVisibleCondition: taskPointer.hovered", task_chip)
        self.assertNotIn("taskPointer.containsMouse", task_chip)

    def test_time_fields_are_centered_over_the_dial(self) -> None:
        picker = (TIMETABLE / "TimePickerPopup.qml").read_text(encoding="utf-8")

        self.assertIn("id: timeFields", picker)
        self.assertIn("anchors.horizontalCenter: parent.horizontalCenter", picker)
        self.assertIn("width: Math.max(root.dialSize, timeFields.implicitWidth)", picker)

    def test_month_forecast_uses_google_weather_assets(self) -> None:
        day_cell = (TIMETABLE / "MonthDayCell.qml").read_text(encoding="utf-8")

        self.assertIn("Image {\n            id: weatherIcon", day_cell)
        self.assertIn("WeatherIcons.getWeatherIcon(root.forecast?.code ?? 113, false)", day_cell)
        self.assertNotIn("function weatherSymbol", day_cell)

    def test_month_events_leave_space_below_the_day_header(self) -> None:
        day_cell = (TIMETABLE / "MonthDayCell.qml").read_text(encoding="utf-8")

        self.assertIn("readonly property real headerEventSpacing: 2", day_cell)
        self.assertIn("topMargin: root.headerEventSpacing", day_cell)
        self.assertIn("root.headerHeight - root.headerEventSpacing - root.cellPadding", day_cell)

    def test_event_metadata_inputs_have_helpful_placeholders(self) -> None:
        sidebar = (TIMETABLE / "EventSidebar.qml").read_text(encoding="utf-8")

        for placeholder in ("Add a label", "Add meeting link", "Add location"):
            self.assertIn(f'Translation.tr("{placeholder}")', sidebar)
            self.assertNotIn(f'placeholderText: Translation.tr("{placeholder}")', sidebar)
        self.assertNotIn("placeholderTextColor", sidebar)

    def test_dashed_borders_render_as_geometry_without_a_canvas_texture(self) -> None:
        dashed_border = (ROOT / "modules" / "common" / "widgets" / "DashedBorder.qml").read_text(encoding="utf-8")
        sidebar = (TIMETABLE / "EventSidebar.qml").read_text(encoding="utf-8")
        secondary_action = sidebar.split("component SecondaryAction:", 1)[1].split("component DurationChip:", 1)[0]

        self.assertIn("import QtQuick.Shapes", dashed_border)
        self.assertIn("ShapePath {", dashed_border)
        self.assertIn("PathRectangle {", dashed_border)
        self.assertIn('fillColor: "transparent"', dashed_border)
        self.assertIn("strokeStyle: root.gapLength > 0 ? ShapePath.DashLine : ShapePath.SolidLine", dashed_border)
        self.assertIn("strokeAdjustment: dashedPath.strokeWidth", dashed_border)
        self.assertNotIn("Canvas {", dashed_border)
        self.assertNotIn('getContext("2d")', dashed_border)
        self.assertIn("DashedBorder {", secondary_action)

    def test_calendar_notifications_use_an_installed_calendar_icon(self) -> None:
        notifier = (ROOT / "services" / "CalendarNotifier.qml").read_text(encoding="utf-8")

        self.assertIn('appIcon: "x-office-calendar"', notifier)
        self.assertIn("Notifications.publishInternalNotification", notifier)
        self.assertNotIn("notify-send", notifier)

    def test_upcoming_rail_highlights_the_current_or_next_event(self) -> None:
        panel = (TIMETABLE / "MonthUpcomingPanel.qml").read_text(encoding="utf-8")

        self.assertIn("readonly property string featuredEventRowKey", panel)
        self.assertIn("const inProgress = allDayToday ||", panel)
        self.assertIn("return current?.rowKey ?? next?.rowKey ?? \"\"", panel)
        self.assertIn("colBackground: featured ? accent : Appearance.colors.colLayer1", panel)
        self.assertIn("ColorUtils.getContrastingTextColor(accent)", panel)

    def test_upcoming_rail_shares_filters_and_lists_overdue_tasks(self) -> None:
        month = (TIMETABLE / "MonthView.qml").read_text(encoding="utf-8")
        panel = (TIMETABLE / "MonthUpcomingPanel.qml").read_text(encoding="utf-8")

        self.assertEqual(panel.count("Todo.getOverdueTasks("), 1)
        self.assertIn('rowKey: "task:overdue:"', panel)
        self.assertIn("buckets.today.push({", panel)
        self.assertIn("property string categoryFilter", panel)
        self.assertIn("property var holidaysByDay", panel)
        self.assertNotIn("Config.options.calendar.holidays", panel)
        self.assertIn("categoryFilter: root.categoryFilter", month)
        self.assertIn("holidaysByDay: root.holidayMap", month)

    def test_upcoming_rail_uses_fixed_hero_and_persistent_horizon_groups(self) -> None:
        config = (ROOT / "modules" / "common" / "Config.qml").read_text(encoding="utf-8")
        persistent = (ROOT / "modules" / "common" / "Persistent.qml").read_text(encoding="utf-8")
        panel = (TIMETABLE / "MonthUpcomingPanel.qml").read_text(encoding="utf-8")

        self.assertIn("property int upcomingHorizonDays: 14", config)
        self.assertIn("Config.options.calendar.timetable.upcomingHorizonDays ?? 14", panel)
        self.assertIn("Layout.preferredHeight: 128", panel)
        self.assertNotIn("model: root.todayTasks", panel)
        self.assertIn('for (const key of ["today", "tomorrow", "thisWeek", "later"])', panel)
        self.assertIn('rowType: "group"', panel)
        self.assertIn("function toggleGroup(key)", panel)
        self.assertIn("property list<string> timetableCollapsedUpcomingGroups: []", persistent)
        self.assertIn("Persistent.states.cheatsheet.timetableCollapsedUpcomingGroups =", panel)

    def test_cancelled_events_are_struck_in_both_sidebars(self) -> None:
        upcoming = (TIMETABLE / "MonthUpcomingPanel.qml").read_text(encoding="utf-8")
        day_row = (TIMETABLE / "MonthDayEventRow.qml").read_text(encoding="utf-8")

        self.assertIn("font.strikeout: eventButton.cancelled", upcoming)
        self.assertIn("font.strikeout: root.cancelled", day_row)

    def test_timetable_hot_paths_do_not_log_unconditionally(self) -> None:
        host = (ROOT / "modules" / "ii" / "cheatsheet" / "CheatsheetTimetable.qml").read_text(encoding="utf-8")
        week = (TIMETABLE / "WeekView.qml").read_text(encoding="utf-8")
        month = (TIMETABLE / "MonthView.qml").read_text(encoding="utf-8")

        self.assertNotIn('console.info("[Timetable', host + week + month)

    def test_lineups_use_a_valid_material_apparel_symbol(self) -> None:
        details = (TIMETABLE / "SportsEventDetails.qml").read_text(encoding="utf-8")

        self.assertIn('modelData.group === "starters" ? "apparel"', details)
        self.assertNotIn('"sports_jersey"', details)


if __name__ == "__main__":
    unittest.main()
