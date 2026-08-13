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
        "descriptionKey": "Read, organize and send email from the II cheatsheet.",
        "icon": "mail",
        "estimatedMinutes": 8,
        "settingsPage": "cheatSheet",
        "contentId": "gmail",
        "detector": "email",
        "videoUrl": ""
    }, {
        "id": "ticktick",
        "titleKey": "TickTick sync",
        "descriptionKey": "Keep your sidebar tasks synchronized with TickTick.",
        "icon": "task_alt",
        "estimatedMinutes": 5,
        "settingsPage": "tasksAccounts",
        "contentId": "ticktick",
        "detector": "ticktick",
        "videoUrl": ""
    }, {
        "id": "calendar",
        "titleKey": "Google Calendar",
        "descriptionKey": "Show and manage calendar events through khal and vdirsyncer.",
        "icon": "calendar_month",
        "estimatedMinutes": 10,
        "settingsPage": "",
        "contentId": "calendar",
        "detector": "calendar",
        "videoUrl": ""
    }, {
        "id": "drive",
        "titleKey": "Google Drive backup",
        "descriptionKey": "Back up II data with rclone and your Google OAuth credentials.",
        "icon": "cloud_sync",
        "estimatedMinutes": 7,
        "settingsPage": "tasksAccounts",
        "contentId": "drive",
        "detector": "googleDrive",
        "videoUrl": ""
    }]

    function tutorialFor(value): var {
        const id = typeof value === "string" ? value : (value ? value.id : "");
        for (let i = 0; i < root.tutorials.length; i++) {
            if (root.tutorials[i].id === id)
                return root.tutorials[i];
        }
        return null;
    }

    /**
     * Integration state is deliberately read-only here.  Opening Welcome must
     * never start OAuth, a sync, or a dependency check; each service owns its
     * existing lifecycle and the registry only adapts its public state into a
     * small semantic contract for the cards.
     */
    function stateFor(value): var {
        const tutorial = root.tutorialFor(value);
        if (!tutorial)
            return ({
                dependencyPresent: false,
                configured: false,
                usable: false,
                checking: false,
                error: true
            });

        if (tutorial.id === "gmail") {
            return ({
                // Credentials are configuration, not a missing runtime
                // dependency; keep that distinction visible in the card.
                dependencyPresent: true,
                configured: EmailService.credentialsConfigured,
                usable: EmailService.authenticated,
                checking: EmailService.checkingCredentials || EmailService.authenticating,
                error: EmailService.credentialsCheckFailed
            });
        }

        if (tutorial.id === "ticktick") {
            return ({
                // TickTick is built into II; an absent token is simply an
                // unconfigured optional integration.
                dependencyPresent: true,
                configured: String(TickTickService.accessToken || "").length > 0,
                usable: TickTickService.available,
                checking: TickTickService.syncing,
                error: false
            });
        }

        if (tutorial.id === "calendar") {
            // CalendarService currently exposes the result of its khal probe,
            // not a separate installed/configured split.  Keep that nuance in
            // the label rather than pretending it is a complete dependency
            // detector, and do not invoke the probe from Welcome.
            const khalProbePassed = CalendarService.khalAvailable === true;
            return ({
                // CalendarService exposes a khal usability probe, not package
                // installation. Keep dependency presence unknown here; the
                // diagnostics page performs the separate command check.
                dependencyPresent: undefined,
                configured: khalProbePassed,
                usable: khalProbePassed,
                checking: false,
                error: false
            });
        }

        if (tutorial.id === "drive") {
            return ({
                dependencyPresent: GoogleDriveService.rcloneInstalled,
                configured: GoogleDriveService.configured,
                usable: GoogleDriveService.configured && !GoogleDriveService.checking,
                checking: GoogleDriveService.checking,
                error: String(GoogleDriveService.errorMessage || "").length > 0
            });
        }

        return ({
            dependencyPresent: false,
            configured: false,
            usable: false,
            checking: false,
            error: false
        });
    }

    function statusTextFor(value): string {
        const state = root.stateFor(value);
        if (state.checking)
            return Translation.tr("Checking");
        if (state.error)
            return Translation.tr("Needs attention");
        if (state.dependencyPresent === false)
            return Translation.tr("Dependency missing");
        if (state.usable)
            return Translation.tr("Ready");
        if (state.configured)
            return Translation.tr("Configured — verify once");
        return Translation.tr("Not configured");
    }

    function actionTextFor(value): string {
        const state = root.stateFor(value);
        if (state.usable)
            return Translation.tr("Review");
        if (state.dependencyPresent === false)
            return Translation.tr("Install first");
        if (state.configured)
            return Translation.tr("Continue");
        return Translation.tr("Configure");
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
