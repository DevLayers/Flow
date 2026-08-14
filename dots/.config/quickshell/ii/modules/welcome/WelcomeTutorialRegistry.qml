pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import qs.services

QtObject {
    id: root

    readonly property var tutorials: [{
        "id": "gmail",
        "titleKey": "Gmail",
        "descriptionKey": "Read, organize and send email from II.",
        "icon": "mail",
        "estimatedMinutes": 8,
        "usedInChips": ["Email", "Cheatsheet"],
        "component": Qt.resolvedUrl("tutorials/WelcomeGmailTutorial.qml")
    }, {
        "id": "ticktick",
        "titleKey": "TickTick",
        "descriptionKey": "Keep your tasks synchronized across II.",
        "icon": "task_alt",
        "estimatedMinutes": 5,
        "usedInChips": ["Tasks sidebar", "Tasks"],
        "component": Qt.resolvedUrl("tutorials/WelcomeTickTickTutorial.qml")
    }, {
        "id": "calendar",
        "titleKey": "Google Calendar",
        "descriptionKey": "Bring your calendars and upcoming events into II.",
        "icon": "calendar_month",
        "estimatedMinutes": 10,
        "usedInChips": ["Calendar", "Agenda"],
        "component": Qt.resolvedUrl("tutorials/WelcomeCalendarTutorial.qml")
    }, {
        "id": "drive",
        "titleKey": "Google Drive",
        "descriptionKey": "Back up II settings and selected folders.",
        "icon": "cloud_sync",
        "estimatedMinutes": 7,
        "usedInChips": ["Accounts & Backup", "Backup"],
        "component": Qt.resolvedUrl("tutorials/WelcomeDriveTutorial.qml")
    }]

    function tutorialFor(value): var {
        const id = typeof value === "string" ? value : (value ? value.id : "");
        for (let i = 0; i < root.tutorials.length; i++) {
            if (root.tutorials[i].id === id)
                return root.tutorials[i];
        }
        return null;
    }

    function stateFor(value): var {
        const tutorial = root.tutorialFor(value);
        if (!tutorial)
            return ({
                state: "neutral",
                text: Translation.tr("Not configured")
            });

        if (tutorial.id === "gmail") {
            if (EmailService.checkingCredentials || EmailService.authenticating)
                return { state: "neutral", text: Translation.tr("Connecting…") };
            if (EmailService.authenticated)
                return { state: "ready", text: Translation.tr("Connected") };
            if (EmailService.credentialsConfigured)
                return { state: "configured", text: Translation.tr("Credentials saved") };
            return { state: "neutral", text: Translation.tr("Setup required") };
        }

        if (tutorial.id === "ticktick") {
            if (TickTickService.syncing)
                return { state: "neutral", text: Translation.tr("Syncing…") };
            if (TickTickService.available)
                return { state: "ready", text: Translation.tr("Connected") };
            if (String(TickTickService.accessToken || "").length > 0)
                return { state: "configured", text: Translation.tr("Credentials saved") };
            return { state: "neutral", text: Translation.tr("Setup required") };
        }

        if (tutorial.id === "calendar") {
            if (CalendarService.khalAvailable === true)
                return { state: "ready", text: Translation.tr("Ready") };
            if (CalendarService.khalAvailable === false)
                return { state: "attention", text: Translation.tr("Tools missing") };
            return { state: "neutral", text: Translation.tr("Setup required") };
        }

        if (tutorial.id === "drive") {
            if (!GoogleDriveService.rcloneInstalled)
                return { state: "attention", text: Translation.tr("rclone missing") };
            if (GoogleDriveService.checking)
                return { state: "neutral", text: Translation.tr("Checking…") };
            if (GoogleDriveService.configured)
                return { state: "ready", text: Translation.tr("Configured") };
            return { state: "neutral", text: Translation.tr("Setup required") };
        }

        return {
            state: "neutral",
            text: Translation.tr("Setup required")
        };
    }

    function statusTextFor(value): string {
        return root.stateFor(value).text;
    }

    function stateKindFor(value): string {
        return root.stateFor(value).state;
    }

    function titleFor(tutorial): string {
        return tutorial ? Translation.tr(tutorial.titleKey) : "";
    }

    function descriptionFor(tutorial): string {
        return tutorial ? Translation.tr(tutorial.descriptionKey) : "";
    }

    function estimatedTimeFor(tutorial): string {
        return tutorial
            ? Translation.tr("About %1 minutes").arg(String(tutorial.estimatedMinutes))
            : "";
    }
}
