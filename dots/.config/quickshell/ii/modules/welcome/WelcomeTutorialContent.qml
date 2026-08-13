pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

/**
 * Compact orientation copy for the Welcome catalog. Canonical setup remains
 * in Cheatsheet/Settings; these cards explain the path without duplicating it.
 */
QtObject {
    function contentFor(contentId: string): var {
        if (contentId === "gmail") {
            return ({
                "intro": "Use the existing Gmail Cheatsheet flow for credentials, OAuth and the first inbox sync.",
                "prerequisites": ["A Google account and the OAuth credentials used by the existing Gmail flow."],
                "steps": [
                    { "title": "Load the Gmail setup", "body": "Open the Email tab in Cheatsheet; it owns the live credentials and OAuth instructions." },
                    { "title": "Authenticate in your browser", "body": "Complete the current OAuth flow, then return to II after the browser confirms access." },
                    { "title": "Check the inbox", "body": "The Email surface should report the authenticated state and begin its normal sync." }
                ],
                "actionLabel": "Open Gmail setup in Cheatsheet",
                "actionPage": "cheatSheet",
                "actionSubPage": "",
                "actionSection": "mail"
            });
        }

        if (contentId === "ticktick") {
            return ({
                "intro": "TickTick is optional. Add its developer credentials and token through Accounts & Backup, then let the existing service sync.",
                "prerequisites": ["A TickTick developer application and an access token."],
                "steps": [
                    { "title": "Create or load the token", "body": "Use TickTick's developer flow to obtain the client ID, client secret and access token." },
                    { "title": "Save the credentials", "body": "Enter them in Accounts & Backup. Welcome never stores tokens or starts a sync itself." },
                    { "title": "Confirm the task surfaces", "body": "Return to the Tasks sidebar or task widgets after the service reports its normal sync state." }
                ],
                "actionLabel": "Open TickTick settings",
                "actionPage": "tasksAccounts",
                "actionSubPage": "",
                "actionSection": ""
            });
        }

        if (contentId === "calendar") {
            return ({
                "intro": "Calendar uses khal and vdirsyncer locally. Configure the provider once, synchronize it, then let CalendarService read the result.",
                "prerequisites": ["khal, vdirsyncer and a configured calendar provider."],
                "steps": [
                    { "title": "Configure the provider", "body": "Set up the vdirsyncer collection and point khal at the synchronized calendar directory." },
                    { "title": "Synchronize the local database", "body": "Run the provider's normal sync from your system workflow before opening the calendar surface." },
                    { "title": "Open the calendar guide", "body": "Use the canonical Cheatsheet timetable for the current guide and confirm events appear in II." }
                ],
                "actionLabel": "Open Calendar guide in Cheatsheet",
                "actionPage": "cheatSheet",
                "actionSubPage": "",
                "actionSection": "calendar_month"
            });
        }

        if (contentId === "drive") {
            return ({
                "intro": "Google Drive backups reuse rclone and the existing Google OAuth credentials. Configure the remote, then choose what II should back up.",
                "prerequisites": ["rclone installed and available in PATH."],
                "steps": [
                    { "title": "Authorize the Drive remote", "body": "Use the existing Google Drive configuration to complete rclone and OAuth authorization." },
                    { "title": "Choose backup behavior", "body": "Select folders, retention and schedule in Accounts & Backup; Welcome does not run rclone." },
                    { "title": "Run the first backup", "body": "Start a manual backup when ready, then review the latest status in the Drive configuration." }
                ],
                "actionLabel": "Open Google Drive setup",
                "actionPage": "tasksAccounts",
                "actionSubPage": "widgets/GoogleDriveBackupConfig.qml",
                "actionSection": ""
            });
        }

        return ({
            "intro": "This tutorial is not available yet.",
            "prerequisites": [],
            "steps": [],
            "actionLabel": "",
            "actionPage": "",
            "actionSubPage": "",
            "actionSection": ""
        });
    }
}
