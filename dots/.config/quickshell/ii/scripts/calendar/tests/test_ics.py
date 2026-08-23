#!/usr/bin/env python3
"""End-to-end tests for the timetable ICS bridge in an isolated khal home."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from configobj import ConfigObj
from icalendar import Calendar


ROOT = Path(__file__).resolve().parents[3]
HELPER = ROOT / "scripts" / "calendar" / "ics.py"


class IcsHelperTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="ii-calendar-test-")
        self.root = Path(self.temp.name)
        self.calendar_dir = self.root / "calendar"
        self.calendar_dir.mkdir()
        self.config = self.root / "khal.conf"
        self.config.write_text(
            "\n".join([
                "[calendars]",
                "",
                "[[work]]",
                f"path = {self.calendar_dir}",
                "type = calendar",
                "color = light blue",
                "",
                "[[readonly]]",
                f"path = {self.root / 'readonly'}",
                "type = calendar",
                "readonly = True",
                "",
                "[locale]",
                "timeformat = %H:%M",
                "dateformat = %d/%m/%Y",
                "longdateformat = %d/%m/%Y",
                "datetimeformat = %d/%m/%Y %H:%M",
                "longdatetimeformat = %d/%m/%Y %H:%M",
                "",
                "[sqlite]",
                f"path = {self.root / 'khal.db'}",
                "",
                "[default]",
                "default_calendar = work",
                "",
            ]),
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self.temp.cleanup()

    def request(self, payload: dict) -> dict:
        completed = subprocess.run(
            [sys.executable, str(HELPER), "--config", str(self.config)],
            input=json.dumps(payload) + "\n",
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        )
        self.assertEqual(completed.stderr, "")
        return json.loads(completed.stdout)

    def event(self, **changes: object) -> dict:
        result = {
            "summary": "Architecture review",
            "start": "2026-09-15T10:00:00",
            "end": "2026-09-15T11:00:00",
            "description": "Bring the recurrence plan.",
            "url": "https://meet.example.test/review",
            "categories": ["work", "work"],
            "color": "tertiary",
            "recurrence": {"freq": "WEEKLY", "interval": 1, "byDay": ["TU"], "count": 10},
            "alarms": [{"minutesBefore": 30, "action": "DISPLAY"}],
        }
        result.update(changes)
        return result

    def load_event(self, uid: str):
        matches = []
        for path in self.calendar_dir.rglob("*.ics"):
            calendar = Calendar.from_ical(path.read_bytes())
            for component in calendar.walk("VEVENT"):
                if str(component.get("UID")) == uid:
                    matches.append(component)
        self.assertEqual(len(matches), 1)
        return matches[0]

    def listed_uids(self) -> list[str]:
        completed = subprocess.run(
            ["khal", "--config", str(self.config), "list", "--json", "uid", "01/09/2026", "30/09/2026"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        )
        values = []
        for line in completed.stdout.splitlines():
            line = line.strip()
            if line and line != "[]":
                values.extend(item["uid"] for item in json.loads(line))
        return values

    def test_save_update_move_preserves_recurrence_url_categories_and_alarm(self) -> None:
        created = self.request({"op": "save", "calendar": "work", "event": self.event()})
        self.assertTrue(created["ok"])
        uid = created["uid"]

        updated = self.request({
            "op": "save",
            "calendar": "work",
            "event": {
                "uid": uid,
                "summary": "Architecture review (moved)",
                "start": "2026-09-16T14:00:00",
                "end": "2026-09-16T15:00:00",
            },
        })
        self.assertEqual(updated, {"ok": True, "uid": uid})

        event = self.load_event(uid)
        self.assertEqual(str(event.get("SUMMARY")), "Architecture review (moved)")
        self.assertEqual(str(event.get("URL")), "https://meet.example.test/review")
        self.assertEqual(str(event.get("RRULE").to_ical(), "utf-8"), "FREQ=WEEKLY;COUNT=10;BYDAY=TU")
        self.assertEqual(sorted(str(value) for value in event.get("CATEGORIES").cats), ["ii/color=tertiary", "work"])
        alarms = [child for child in event.subcomponents if child.name == "VALARM"]
        self.assertEqual(len(alarms), 1)
        self.assertEqual(str(alarms[0].decoded("TRIGGER")), "-1 day, 23:30:00")

        read = self.request({"op": "read", "uid": uid})
        self.assertTrue(read["ok"])
        self.assertEqual(read["event"]["color"], "tertiary")
        self.assertEqual(read["event"]["categories"], ["work"])
        self.assertEqual(read["event"]["alarms"], [{"minutesBefore": 30, "action": "DISPLAY"}])

    def test_same_summary_deletes_only_requested_uid(self) -> None:
        first = self.request({"op": "save", "calendar": "work", "event": self.event(recurrence=None, alarms=[])})
        second = self.request({"op": "save", "calendar": "work", "event": self.event(recurrence=None, alarms=[], start="2026-09-16T10:00:00", end="2026-09-16T11:00:00")})
        self.assertNotEqual(first["uid"], second["uid"])

        deleted = self.request({"op": "deleteSeries", "uid": first["uid"]})
        self.assertEqual(deleted, {"ok": True})
        self.assertEqual(self.request({"op": "read", "uid": first["uid"]})["ok"], False)
        self.assertTrue(self.request({"op": "read", "uid": second["uid"]})["ok"])
        self.assertNotIn(first["uid"], self.listed_uids())
        self.assertIn(second["uid"], self.listed_uids())

    def test_calendar_color_uses_curated_khal_values(self) -> None:
        calendars = self.request({"op": "calendars"})
        work = next(calendar for calendar in calendars["calendars"] if calendar["name"] == "work")
        self.assertEqual(work["color"], "light blue")

        changed = self.request({"op": "setCalendarColor", "calendar": "work", "color": "light green"})
        self.assertEqual(changed, {"ok": True, "calendar": "work", "color": "light green"})
        self.assertEqual(ConfigObj(str(self.config), encoding="utf-8")["calendars"]["work"]["color"], "light green")
        self.assertFalse(self.request({"op": "setCalendarColor", "calendar": "work", "color": "#123456"})["ok"])
        self.assertFalse(self.request({"op": "setCalendarColor", "calendar": "readonly", "color": "light red"})["ok"])

    def test_occurrence_operations_and_read_only_guard(self) -> None:
        created = self.request({"op": "save", "calendar": "work", "event": self.event()})
        uid = created["uid"]
        expanded = self.request({"op": "expand", "uid": uid, "from": "2026-09-15T00:00:00", "to": "2026-12-01T00:00:00"})
        self.assertEqual(len(expanded["occurrences"]), 10)

        occurrence = expanded["occurrences"][1]["recurrenceId"]
        self.assertEqual(self.request({"op": "deleteOccurrence", "uid": uid, "recurrenceId": occurrence}), {"ok": True})
        after_delete = self.request({"op": "expand", "uid": uid, "from": "2026-09-15T00:00:00", "to": "2026-12-01T00:00:00"})
        self.assertEqual(len(after_delete["occurrences"]), 9)

        override_id = after_delete["occurrences"][1]["recurrenceId"]
        self.assertEqual(self.request({"op": "overrideOccurrence", "uid": uid, "recurrenceId": override_id, "fields": {"summary": "One-off review"}}), {"ok": True})
        split_id = after_delete["occurrences"][2]["recurrenceId"]
        split = self.request({"op": "splitSeries", "uid": uid, "recurrenceId": split_id, "fields": {"summary": "Future reviews"}})
        self.assertTrue(split["ok"])
        self.assertNotEqual(split["uid"], uid)
        prior = self.request({"op": "expand", "uid": uid, "from": "2026-09-15T00:00:00", "to": "2027-02-01T00:00:00"})
        self.assertTrue(all(item["recurrenceId"] < split_id for item in prior["occurrences"]))
        follow_up = self.request({"op": "read", "uid": split["uid"]})
        self.assertEqual(follow_up["event"]["summary"], "Future reviews")
        future = self.request({"op": "expand", "uid": split["uid"], "from": "2026-09-15T00:00:00", "to": "2027-02-01T00:00:00"})
        self.assertEqual(future["occurrences"][0]["recurrenceId"], split_id)
        truncate_id = future["occurrences"][2]["recurrenceId"]
        self.assertEqual(self.request({"op": "truncateSeries", "uid": split["uid"], "recurrenceId": truncate_id}), {"ok": True})
        truncated = self.request({"op": "expand", "uid": split["uid"], "from": "2026-09-15T00:00:00", "to": "2027-02-01T00:00:00"})
        self.assertTrue(all(item["recurrenceId"] < truncate_id for item in truncated["occurrences"]))
        self.assertEqual(self.request({"op": "save", "calendar": "readonly", "event": self.event(summary="Blocked")})["ok"], False)


if __name__ == "__main__":
    unittest.main()
