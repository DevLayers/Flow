#!/usr/bin/env python3
"""Static contracts for the timetable editor presentation."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
TIMETABLE = ROOT / "modules" / "ii" / "cheatsheet" / "timetable"


class TimetablePresentationContractTests(unittest.TestCase):
    def test_color_picker_uses_semantic_hover_tokens(self) -> None:
        helper = (TIMETABLE / "TimetableHelpers.js").read_text(encoding="utf-8")
        picker = (TIMETABLE / "ColorPickerRow.qml").read_text(encoding="utf-8")

        for token in ("primary", "secondary", "tertiary", "error", "primarycontainer", "secondarycontainer", "tertiarycontainer", "errorcontainer"):
            self.assertIn(f'case "{token}"', helper)
        self.assertIn("function themeHoverColorForToken", helper)
        self.assertIn("H.themeHoverColorForToken(modelData.token, Appearance.colors)", picker)
        self.assertNotIn("ColorUtils.mix(tokenColor, Appearance.colors.colOnSurface", picker)

    def test_color_tooltips_use_the_delegate_hover_state(self) -> None:
        picker = (TIMETABLE / "ColorPickerRow.qml").read_text(encoding="utf-8")

        self.assertIn("id: colorButton", picker)
        self.assertIn("extraVisibleCondition: colorButton.hovered", picker)
        self.assertNotIn("extraVisibleCondition: parent.hovered", picker)

    def test_task_tooltip_reads_the_hover_handler_state(self) -> None:
        day_cell = (TIMETABLE / "MonthDayCell.qml").read_text(encoding="utf-8")

        self.assertIn("extraVisibleCondition: taskPointer.hovered", day_cell)
        self.assertNotIn("taskPointer.containsMouse", day_cell)

    def test_time_fields_are_centered_over_the_dial(self) -> None:
        picker = (TIMETABLE / "TimePickerPopup.qml").read_text(encoding="utf-8")

        self.assertIn("id: timeFields", picker)
        self.assertIn("anchors.horizontalCenter: parent.horizontalCenter", picker)
        self.assertIn("width: Math.max(root.dialSize, timeFields.implicitWidth)", picker)

    def test_event_metadata_inputs_have_helpful_placeholders(self) -> None:
        sidebar = (TIMETABLE / "MonthEventSidebar.qml").read_text(encoding="utf-8")

        for placeholder in ("Add a label", "Add meeting link", "Add location"):
            self.assertIn(f'Translation.tr("{placeholder}")', sidebar)
        self.assertNotIn("placeholderTextColor", sidebar)


if __name__ == "__main__":
    unittest.main()
