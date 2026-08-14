import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.welcome
import qs.modules.welcome.tutorials
import qs.services
import Quickshell
import Quickshell.Io
import "."

WelcomeIntegrationTutorial {
    id: root

    title: Translation.tr("Set up Google Drive backup")
    subtitle: Translation.tr("Automate remote backups of your II configuration and selected folders to Google Drive using rclone.")
    materialIcon: "cloud_sync"
    statusText: WelcomeTutorialRegistry.statusTextFor("drive")
    statusKind: WelcomeTutorialRegistry.stateKindFor("drive")
    usedInChips: ["Accounts & Backup", "Backup"]

    signal openSettingsTarget(string pageId, string subPageId, string sectionId)

    readonly property string rcloneInstallCommand: {
        const id = SystemInfo.distroId.toLowerCase();
        switch (id) {
            case "arch":
            case "artix":
            case "endeavouros":
            case "cachyos":
            case "manjaro":
                return "sudo pacman -S rclone";
            case "ubuntu":
            case "debian":
            case "popos":
            case "linuxmint":
            case "zorin":
            case "kali":
            case "raspbian":
                return "sudo apt install rclone";
            case "opensuse":
            case "opensuse-tumbleweed":
            case "opensuse-leap":
                return "sudo zypper install rclone";
            case "nixos":
                return "nix-env -iA nixos.rclone";
            case "gentoo":
            case "funtoo":
                return "sudo emerge --ask net-misc/rclone";
            case "void":
                return "sudo xbps-install -S rclone";
            case "alpine":
                return "sudo apk add rclone";
            case "fedora":
            case "rhel":
            case "centos":
            case "nobara":
            default:
                return "sudo dnf install rclone";
        }
    }

    // Step 1: Check rclone
    WelcomeTutorialStep {
        stepNumber: "1"
        stateKind: GoogleDriveService.rcloneInstalled ? "complete" : "current"
        title: Translation.tr("Check rclone installation")
        supportingText: Translation.tr("II uses rclone to transfer encrypted backup snapshots to Google Drive.")

        RowLayout {
            spacing: 12

            Rectangle {
                radius: Appearance.rounding.full
                implicitHeight: 28
                implicitWidth: rcloneStatusText.implicitWidth + 18
                color: GoogleDriveService.rcloneInstalled
                    ? Appearance.colors.colPrimaryContainer
                    : Appearance.colors.colErrorContainer

                StyledText {
                    id: rcloneStatusText
                    anchors.centerIn: parent
                    text: GoogleDriveService.rcloneInstalled ? Translation.tr("rclone installed") : Translation.tr("rclone missing")
                    color: GoogleDriveService.rcloneInstalled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnErrorContainer
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                visible: !GoogleDriveService.rcloneInstalled
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                implicitHeight: 32
                implicitWidth: rcloneInstallRow.implicitWidth + 18

                RowLayout {
                    id: rcloneInstallRow
                    anchors.centerIn: parent
                    spacing: 8
                    StyledText { text: root.rcloneInstallCommand; font.family: Appearance.font.family.monospace; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1 }
                    MaterialSymbol { text: "content_copy"; iconSize: 14; color: Appearance.colors.colPrimary }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["wl-copy", root.rcloneInstallCommand])
                }
            }
        }
    }

    // Step 2: Prepare Drive API
    WelcomeTutorialStep {
        stepNumber: "2"
        stateKind: GoogleDriveService.configured ? "complete" : "pending"
        title: Translation.tr("Prepare Google Drive access")
        supportingText: Translation.tr("Enable the Google Drive API in Google Cloud Console. You can reuse the same project and credentials created for Gmail.")

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }

            RippleButtonWithIcon {
                materialIcon: "open_in_new"
                mainText: Translation.tr("Open Google Cloud Console")
                centerContent: true
                horizontalPadding: 16
                buttonRadius: Appearance.rounding.full
                implicitHeight: 40
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colText: Appearance.colors.colOnSecondaryContainer
                onClicked: Qt.openUrlExternally("https://console.cloud.google.com/apis/library/drive.googleapis.com")
            }
        }
    }

    // Step 3: Configure Drive in II
    WelcomeTutorialStep {
        stepNumber: "3"
        stateKind: GoogleDriveService.configured ? "complete" : "pending"
        title: Translation.tr("Connect Google Drive in Settings")
        supportingText: Translation.tr("Open the Google Drive dashboard in Accounts & Backup to authorize access and select which folders to back up.")

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }

            RippleButtonWithIcon {
                materialIcon: "settings"
                mainText: Translation.tr("Open Google Drive Setup")
                centerContent: true
                horizontalPadding: 16
                buttonRadius: Appearance.rounding.full
                implicitHeight: 40
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                colText: Appearance.colors.colOnPrimary
                onClicked: root.openSettingsTarget("tasksAccounts", "widgets/GoogleDriveBackupConfig.qml", "drive")
            }
        }
    }

    // Step 4: Run First Backup
    WelcomeTutorialStep {
        stepNumber: "4"
        isLast: true
        stateKind: GoogleDriveService.configured ? "complete" : "pending"
        title: Translation.tr("Verify backup snapshot")
        supportingText: GoogleDriveService.configured
            ? Translation.tr("✓ Google Drive configured! Backups will run automatically on schedule.")
            : Translation.tr("Configure Google Drive to start protecting your data and shell settings.")

        RowLayout {
            Layout.fillWidth: true
            visible: GoogleDriveService.configured
            Item { Layout.fillWidth: true }

            RippleButtonWithIcon {
                materialIcon: "cloud_sync"
                mainText: Translation.tr("Manage Backups in Settings")
                centerContent: true
                horizontalPadding: 16
                buttonRadius: Appearance.rounding.full
                implicitHeight: 40
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                colText: Appearance.colors.colOnPrimary
                onClicked: root.openSettingsTarget("tasksAccounts", "widgets/GoogleDriveBackupConfig.qml", "drive")
            }
        }
    }
}
