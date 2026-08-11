import QtQuick

QtObject {
    readonly property list<var> tutorials: [{
        "id": "gmail",
        "title": "Gmail",
        "description": "Read, organize and send email from the II cheatsheet.",
        "icon": "mail",
        "estimatedTime": "About 8 minutes",
        "settingsPage": "cheatSheet",
        "videoUrl": "",
        "steps": [
            "Create or select a project in Google Cloud Console.",
            "Enable the Gmail API and configure the OAuth consent screen.",
            "Create Desktop App credentials and add yourself as a test user.",
            "Save the Client ID and Client Secret in the Gmail setup page.",
            "Authorize II in the browser and verify the connected account."
        ]
    }, {
        "id": "ticktick",
        "title": "TickTick sync",
        "description": "Keep your sidebar tasks synchronized with TickTick.",
        "icon": "task_alt",
        "estimatedTime": "About 5 minutes",
        "settingsPage": "tasksAccounts",
        "videoUrl": "",
        "steps": [
            "Create an application in the TickTick developer portal.",
            "Copy the Client ID and Client Secret into Accounts & Backup.",
            "Start browser authorization from the TickTick section.",
            "Approve access and return to II after the callback.",
            "Create a test task and confirm that synchronization works."
        ]
    }, {
        "id": "calendar",
        "title": "Google Calendar",
        "description": "Show and manage calendar events through khal and vdirsyncer.",
        "icon": "calendar_month",
        "estimatedTime": "About 10 minutes",
        "settingsPage": "languageTime",
        "videoUrl": "",
        "steps": [
            "Install khal and vdirsyncer using your distribution packages.",
            "Create the vdirsyncer storage and pair for Google Calendar.",
            "Run the discovery and synchronization steps once.",
            "Configure khal to read the synchronized calendar collection.",
            "Open the II calendar and verify the next events."
        ]
    }, {
        "id": "drive",
        "title": "Google Drive backup",
        "description": "Back up II data with rclone and your Google OAuth credentials.",
        "icon": "cloud_sync",
        "estimatedTime": "About 7 minutes",
        "settingsPage": "tasksAccounts",
        "videoUrl": "",
        "steps": [
            "Install rclone from your distribution packages.",
            "Enable the Google Drive API in the same Google Cloud project.",
            "Open Accounts & Backup and start Drive authorization.",
            "Choose the folders and data that should be included.",
            "Run a manual backup and confirm that the remote folder exists."
        ]
    }]
}
