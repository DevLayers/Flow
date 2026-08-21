#!/usr/bin/env python3
"""The assistant's time tools stay local, bounded and approval-first."""

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
AI = (ROOT / "services/Ai.qml").read_text(encoding="utf-8")
REGISTRY = (ROOT / "services/ai/AiToolRegistry.qml").read_text(encoding="utf-8")
TIME = (ROOT / "services/ai/integrations/AiTimeIntegration.qml").read_text(encoding="utf-8")
ALARMS = (ROOT / "services/AlarmService.qml").read_text(encoding="utf-8")
CARD = (ROOT / "services/ai/blocks/AiReminderCard.qml").read_text(encoding="utf-8")
MESSAGE = (ROOT / "modules/ii/sidebarPolicies/aiChat/AiMessage.qml").read_text(encoding="utf-8")


class AiTimeIntegrationContractTests(unittest.TestCase):
    def test_registry_exposes_only_the_planned_time_tools(self):
        for tool in (
            'id: "reminder_create"',
            'id: "alarms_list"',
            'id: "calendar_list_events"',
            'id: "weather_get"',
        ):
            with self.subTest(tool=tool):
                self.assertIn(tool, REGISTRY)
        reminder = REGISTRY.split('id: "reminder_create"', 1)[1].split('\n        },', 1)[0]
        self.assertIn('kind: "localWrite"', reminder)
        self.assertIn('defaultApproval: "ask"', reminder)
        weather = REGISTRY.split('id: "weather_get"', 1)[1].split('\n        },', 1)[0]
        self.assertIn('network: "required"', weather)

    def test_adapter_uses_existing_services_and_bounded_dtos(self):
        for token in (
            "AlarmService.addAlarm(",
            "CalendarService.getTasksByDate(",
            "Weather.getData()",
            "maximumCalendarEvents: 20",
            "function normalizeReminder(",
            "function relativeMinutes(",
            "function calendarEvents(",
            "function weather()",
        ):
            with self.subTest(token=token):
                self.assertIn(token, TIME)
        self.assertNotIn("execDetached", TIME)
        self.assertNotIn("Process", TIME)

    def test_relative_reminders_require_an_explicit_unit(self):
        registry = REGISTRY.split('id: "reminder_create"', 1)[1].split('\n        },', 1)[0]
        self.assertIn('whenRelative: { type: "string"', registry)
        self.assertIn("Never pass bare seconds", registry)
        self.assertIn("invalidRelativeTime", TIME)

    def test_future_reminders_keep_their_local_date(self):
        self.assertIn('function addAlarm(time, label, days, date = "")', ALARMS)
        self.assertIn('date: date || ""', ALARMS)
        self.assertIn('String(alarm.date) === dateString', ALARMS)

    def test_reminder_has_a_preview_and_journalled_side_effect(self):
        for token in (
            "readonly property AiTimeIntegration timeIntegration",
            '"reminder_create": call => root.toolReminderCreate(call)',
            "function approveReminder(message: AiMessageData)",
            "root.beginToolExecution(message, \"reminder_create\"",
            '"reminder_create": pending => root.createReminderNow',
            "function rejectReminder(message: AiMessageData)",
        ):
            with self.subTest(token=token):
                self.assertIn(token, AI)
        self.assertIn("Ai.approveReminder(root.messageData)", CARD)
        self.assertIn("Ai.rejectReminder(root.messageData)", CARD)
        self.assertIn('case "reminderPreview"', MESSAGE)


if __name__ == "__main__":
    unittest.main()
