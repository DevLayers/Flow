import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    signal openSettingsPage(string pageId)
    signal openTutorial(string tutorialId)

    property bool khalInstalled: false
    property bool khalUsable: false
    property bool vdirsyncerInstalled: false
    property bool dependencyChecksStarted: false
    property string lastCopiedCommand: ""

    readonly property bool checking: khalCheckProcess.running
        || khalUsabilityCheckProcess.running
        || vdirsyncerCheckProcess.running
        || EmailService.checkingCredentials
        || GoogleDriveService.checking
    readonly property string welcomeShortcut: WelcomeKeybindRegistry.keysFor("welcome").join(" + ")
    readonly property var statusItems: root.buildStatusItems()

    function semanticLabel(kind: string): string {
        switch (kind) {
        case "ready":
            return Translation.tr("Ready");
        case "configured":
            return Translation.tr("Configured");
        case "dependency":
            return Translation.tr("Dependency missing");
        case "attention":
            return Translation.tr("Needs attention");
        case "verifying":
            return Translation.tr("Checking");
        case "error":
            return Translation.tr("Error");
        case "optional":
            return Translation.tr("Optional");
        default:
            return Translation.tr("Not configured");
        }
    }

    function makeStatus(icon: string, title: string, description: string, kind: string, settingsPage: string, commandText: string, tutorialId: string): var {
        return {
            "icon": icon,
            "title": title,
            "description": description,
            "kind": kind,
            "label": root.semanticLabel(kind),
            "settingsPage": settingsPage,
            "command": commandText,
            "tutorialId": tutorialId
        };
    }

    function buildStatusItems(): var {
        const items = [];

        let wifiKind = "optional";
        let wifiDescription = Translation.tr("Choose a wireless network when you need one.");
        if (Network.lastWifiError.length > 0 && !Network.wifiConnecting) {
            wifiKind = "error";
            wifiDescription = Network.lastWifiError;
        } else if (Network.wifiConnecting) {
            wifiKind = "verifying";
            wifiDescription = Translation.tr("Connecting to a wireless network.");
        } else if (Network.wifiStatus === "connected") {
            wifiKind = "ready";
            wifiDescription = Network.networkName || Network.active?.ssid || Translation.tr("Wireless connection is active.");
        } else if (Network.wifiEnabled) {
            wifiKind = "attention";
            wifiDescription = Translation.tr("Wi-Fi is on, but no network is connected.");
        }
        items.push(root.makeStatus(
            Network.materialSymbol,
            Translation.tr("Wi-Fi"),
            wifiDescription,
            wifiKind,
            "",
            "nmcli radio wifi",
            ""
        ));

        let bluetoothKind = "optional";
        let bluetoothDescription = Translation.tr("Pair headphones and other accessories when needed.");
        if (!BluetoothStatus.available) {
            bluetoothKind = "dependency";
            bluetoothDescription = Translation.tr("No Bluetooth adapter was detected.");
        } else if (BluetoothStatus.connected) {
            bluetoothKind = "ready";
            bluetoothDescription = BluetoothStatus.firstActiveDevice?.name || Translation.tr("A device is connected.");
        } else if (BluetoothStatus.enabled) {
            bluetoothDescription = Translation.tr("Bluetooth is on, but no device is connected.");
        }
        items.push(root.makeStatus(
            BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth",
            Translation.tr("Bluetooth"),
            bluetoothDescription,
            bluetoothKind,
            "",
            "bluetoothctl show",
            ""
        ));

        let audioKind = "dependency";
        let audioDescription = Translation.tr("No output device is available yet.");
        if (Audio.ready && Audio.sink) {
            audioKind = Audio.muted ? "attention" : "ready";
            audioDescription = Audio.muted
                ? Translation.tr("%1 is muted.").arg(Audio.friendlyDeviceName(Audio.sink))
                : Translation.tr("%1 at %2%.").arg(Audio.friendlyDeviceName(Audio.sink)).arg(String(Math.round(Audio.value * 100)));
        }
        items.push(root.makeStatus(
            Audio.muted ? "volume_off" : "volume_up",
            Translation.tr("Audio output"),
            audioDescription,
            audioKind,
            "soundAlerts",
            "wpctl status",
            ""
        ));

        let gmailKind = "optional";
        let gmailDescription = Translation.tr("Connect Gmail when you want mail in the cheatsheet.");
        if (EmailService.checkingCredentials || EmailService.authenticating) {
            gmailKind = "verifying";
            gmailDescription = Translation.tr("Checking Gmail credentials.");
        } else if (EmailService.authenticated) {
            gmailKind = "ready";
            gmailDescription = EmailService.userEmail || Translation.tr("Gmail is authenticated.");
        } else if (EmailService.credentialsConfigured) {
            gmailKind = "attention";
            gmailDescription = Translation.tr("OAuth credentials are present; sign in to finish.");
        } else if (EmailService.credentialsCheckFailed) {
            gmailKind = "error";
            gmailDescription = Translation.tr("Gmail credentials could not be checked.");
        } else {
            gmailKind = "notConfigured";
        }
        items.push(root.makeStatus(
            "mail",
            Translation.tr("Gmail"),
            gmailDescription,
            gmailKind,
            "cheatSheet",
            "",
            "gmail"
        ));

        let tickKind = TickTickService.syncing
            ? "verifying"
            : TickTickService.available ? "ready" : "notConfigured";
        const tickDescription = TickTickService.syncing
            ? Translation.tr("TickTick is syncing tasks.")
            : TickTickService.available
                ? Translation.tr("An access token is available.")
                : Translation.tr("Add a token when you want TickTick tasks.");
        items.push(root.makeStatus(
            "task_alt",
            Translation.tr("TickTick"),
            tickDescription,
            tickKind,
            "tasksAccounts",
            "",
            "ticktick"
        ));

        let khalKind = "verifying";
        let khalDescription = Translation.tr("Checking khal and its calendar configuration.");
        if (!khalCheckProcess.running && !khalUsabilityCheckProcess.running) {
            if (!root.khalInstalled) {
                khalKind = "dependency";
                khalDescription = Translation.tr("Install khal to display calendar events.");
            } else if (root.khalUsable || CalendarService.khalAvailable) {
                khalKind = "ready";
                khalDescription = Translation.tr("Calendar events are available.");
            } else {
                khalKind = "notConfigured";
                khalDescription = Translation.tr("khal is installed but has no usable calendar yet.");
            }
        }
        items.push(root.makeStatus(
            "calendar_month",
            Translation.tr("khal"),
            khalDescription,
            khalKind,
            "",
            "khal list today",
            "calendar"
        ));

        const vdirKind = vdirsyncerCheckProcess.running
            ? "verifying"
            : root.vdirsyncerInstalled ? "ready" : "dependency";
        const vdirDescription = vdirsyncerCheckProcess.running
            ? Translation.tr("Checking for the vdirsyncer command.")
            : root.vdirsyncerInstalled
                ? Translation.tr("vdirsyncer is available for calendar sync.")
                : Translation.tr("Install vdirsyncer to synchronize calendars.");
        items.push(root.makeStatus(
            "sync",
            Translation.tr("vdirsyncer"),
            vdirDescription,
            vdirKind,
            "",
            "command -v vdirsyncer",
            "calendar"
        ));

        const rcloneKind = GoogleDriveService.checking
            ? "verifying"
            : !GoogleDriveService.rcloneInstalled
                ? "dependency"
                : GoogleDriveService.errorMessage.length > 0
                    ? "error"
                    : "ready";
        const rcloneDescription = GoogleDriveService.checking
            ? Translation.tr("Checking the rclone installation.")
            : !GoogleDriveService.rcloneInstalled
                ? Translation.tr("Install rclone before authorizing Drive.")
                : GoogleDriveService.errorMessage.length > 0
                    ? GoogleDriveService.errorMessage
                    : Translation.tr("rclone is available.");
        items.push(root.makeStatus(
            "terminal",
            Translation.tr("rclone"),
            rcloneDescription,
            rcloneKind,
            "tasksAccounts",
            "rclone version",
            "drive"
        ));

        const driveKind = GoogleDriveService.checking || GoogleDriveService.syncing
            ? "verifying"
            : !GoogleDriveService.rcloneInstalled
                ? "dependency"
                : GoogleDriveService.errorMessage.length > 0
                    ? "error"
                    : GoogleDriveService.configured ? "ready" : "notConfigured";
        const driveDescription = GoogleDriveService.checking || GoogleDriveService.syncing
            ? Translation.tr("Checking Google Drive status.")
            : !GoogleDriveService.rcloneInstalled
                ? Translation.tr("rclone is required for Google Drive.")
                : GoogleDriveService.errorMessage.length > 0
                    ? GoogleDriveService.errorMessage
                    : GoogleDriveService.configured
                        ? Translation.tr("Google Drive is authorized.")
                        : Translation.tr("Authorize Drive when you want automatic backups.");
        items.push(root.makeStatus(
            "cloud_sync",
            Translation.tr("Google Drive"),
            driveDescription,
            driveKind,
            "tasksAccounts",
            "",
            "drive"
        ));

        return items;
    }

    function verifyAgain(): void {
        if (khalCheckProcess.running || khalUsabilityCheckProcess.running || vdirsyncerCheckProcess.running)
            return;
        root.dependencyChecksStarted = true;
        khalCheckProcess.running = true;
        khalUsabilityCheckProcess.running = true;
        vdirsyncerCheckProcess.running = true;
        if (!EmailService.checkingCredentials)
            EmailService.checkCredentials();
        // GoogleDriveService already owns its boot/scheduled lifecycle.  A
        // pending boot sync must never be nudged by a Welcome diagnostic.
        if (!GoogleDriveService.checking && !GoogleDriveService.bootSyncPending)
            GoogleDriveService.checkRclone();
    }

    function copyCommand(command: string): void {
        if (!command || command.length === 0)
            return;
        Quickshell.clipboardText = command;
        root.lastCopiedCommand = command;
    }

    Process {
        id: khalCheckProcess
        command: ["sh", "-c", "command -v khal >/dev/null 2>&1"]
        running: false
        onExited: exitCode => root.khalInstalled = exitCode === 0
    }

    Process {
        id: khalUsabilityCheckProcess
        command: ["sh", "-c", "khal list today >/dev/null 2>&1"]
        running: false
        onExited: exitCode => root.khalUsable = exitCode === 0
    }

    Process {
        id: vdirsyncerCheckProcess
        command: ["sh", "-c", "command -v vdirsyncer >/dev/null 2>&1"]
        running: false
        onExited: exitCode => root.vdirsyncerInstalled = exitCode === 0
    }

    ContentPage {
        anchors.fill: parent
        bottomContentPadding: 28

        ContentSection {
            Layout.fillWidth: true
            icon: "health_and_safety"
            title: Translation.tr("Everything is optional")

            NoticeBox {
                Layout.fillWidth: true
                materialIcon: root.checking ? "progress_activity" : "fact_check"
                text: root.checking
                    ? Translation.tr("Checking installed dependencies and saved credentials. Nothing is changed.")
                    : Translation.tr("These checks are read-only. They never install, sync or change your settings.")

                RippleButtonWithIcon {
                    materialIcon: "refresh"
                    mainText: Translation.tr("Verify again")
                    enabled: !root.checking
                    onClicked: root.verifyAgain()
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 720 ? 2 : 1
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: root.statusItems

                    delegate: WelcomeStatusCard {
                        required property var modelData
                        Layout.fillWidth: true
                        title: modelData.title
                        description: modelData.description
                        statusKind: modelData.kind
                        statusLabel: modelData.label
                        statusIcon: modelData.icon
                        settingsPage: modelData.settingsPage
                        tutorialId: modelData.tutorialId
                        commandText: modelData.command
                        showSettings: modelData.settingsPage.length > 0
                        showTutorial: modelData.tutorialId.length > 0
                        showCommand: modelData.command.length > 0
                        onSettingsRequested: root.openSettingsPage(modelData.settingsPage)
                        onTutorialRequested: tutorialId => root.openTutorial(tutorialId)
                        onCommandRequested: command => root.copyCommand(command)
                    }
                }
            }
        }

        NoticeBox {
            Layout.fillWidth: true
            materialIcon: "waving_hand"
            text: root.welcomeShortcut.length > 0
                ? Translation.tr("You can reopen Welcome any time with %1.").arg(root.welcomeShortcut)
                : Translation.tr("You can reopen Welcome any time with the IPC command below.")

            RippleButtonWithIcon {
                materialIcon: root.lastCopiedCommand.length > 0 ? "check" : "content_copy"
                mainText: root.lastCopiedCommand.length > 0
                    ? Translation.tr("Copied")
                    : Translation.tr("Copy IPC command")
                onClicked: root.copyCommand("qs -c ii ipc call welcome toggle")
            }
        }
    }

    Component.onCompleted: root.verifyAgain()
}
