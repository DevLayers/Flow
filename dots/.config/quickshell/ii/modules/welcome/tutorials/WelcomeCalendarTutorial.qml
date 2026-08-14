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

    title: Translation.tr("Set up Google Calendar")
    subtitle: Translation.tr("Bring your Google Calendar events and upcoming schedules into II through khal and vdirsyncer.")
    materialIcon: "calendar_month"
    statusText: WelcomeTutorialRegistry.statusTextFor("calendar")
    statusKind: WelcomeTutorialRegistry.stateKindFor("calendar")
    usedInChips: ["Calendar", "Agenda"]

    signal openSettingsTarget(string pageId, string subPageId, string sectionId)

    // Visual Flow Architecture Box
    Rectangle {
        Layout.fillWidth: true
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        implicitHeight: flowCol.implicitHeight + 24

        ColumnLayout {
            id: flowCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 8

            StyledText {
                text: Translation.tr("How II Calendar Integration Works")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Node 1: Google Calendar
                Rectangle {
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                    implicitHeight: 32
                    implicitWidth: gCalRow.implicitWidth + 16
                    RowLayout {
                        id: gCalRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol { text: "cloud"; iconSize: 16; color: Appearance.colors.colPrimary }
                        StyledText { text: "Google Calendar"; font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.DemiBold; color: Appearance.colors.colOnLayer1 }
                    }
                }

                MaterialSymbol { text: "arrow_forward"; iconSize: 14; color: Appearance.colors.colOnLayer2 }

                // Node 2: vdirsyncer
                Rectangle {
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colSecondaryContainer
                    implicitHeight: 32
                    implicitWidth: vdirRow.implicitWidth + 16
                    RowLayout {
                        id: vdirRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol { text: "sync"; iconSize: 16; color: Appearance.colors.colOnSecondaryContainer }
                        StyledText { text: "vdirsyncer (Sync)"; font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.DemiBold; color: Appearance.colors.colOnSecondaryContainer }
                    }
                }

                MaterialSymbol { text: "arrow_forward"; iconSize: 14; color: Appearance.colors.colOnLayer2 }

                // Node 3: khal
                Rectangle {
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colPrimaryContainer
                    implicitHeight: 32
                    implicitWidth: khalRow.implicitWidth + 16
                    RowLayout {
                        id: khalRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol { text: "terminal"; iconSize: 16; color: Appearance.colors.colOnPrimaryContainer }
                        StyledText { text: "khal (Reader)"; font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.DemiBold; color: Appearance.colors.colOnPrimaryContainer }
                    }
                }

                MaterialSymbol { text: "arrow_forward"; iconSize: 14; color: Appearance.colors.colOnLayer2 }

                // Node 4: II Calendar
                Rectangle {
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colPrimary
                    implicitHeight: 32
                    implicitWidth: iiRow.implicitWidth + 16
                    RowLayout {
                        id: iiRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol { text: "calendar_month"; iconSize: 16; color: Appearance.colors.colOnPrimary }
                        StyledText { text: "II Calendar"; font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.DemiBold; color: Appearance.colors.colOnPrimary }
                    }
                }
            }
        }
    }

    readonly property string installCommand: {
        const id = SystemInfo.distroId.toLowerCase();
        switch (id) {
            case "arch":
            case "artix":
            case "endeavouros":
            case "cachyos":
            case "manjaro":
                return "sudo pacman -S khal vdirsyncer";
            case "ubuntu":
            case "debian":
            case "popos":
            case "linuxmint":
            case "zorin":
            case "kali":
            case "raspbian":
                return "sudo apt install khal vdirsyncer";
            case "opensuse":
            case "opensuse-tumbleweed":
            case "opensuse-leap":
                return "sudo zypper install khal vdirsyncer";
            case "nixos":
                return "nix-env -iA nixos.khal nixos.vdirsyncer";
            case "gentoo":
            case "funtoo":
                return "sudo emerge --ask app-misc/khal net-misc/vdirsyncer";
            case "void":
                return "sudo xbps-install -S khal vdirsyncer";
            case "alpine":
                return "sudo apk add khal vdirsyncer";
            case "fedora":
            case "rhel":
            case "centos":
            case "nobara":
            default:
                return "sudo dnf install khal vdirsyncer";
        }
    }

    // Step 1: Install tools
    WelcomeTutorialStep {
        stepNumber: "1"
        stateKind: CalendarService.khalAvailable ? "complete" : "current"
        title: Translation.tr("Install the calendar tools (khal & vdirsyncer)")
        supportingText: Translation.tr("II reads calendar events via khal, while vdirsyncer handles 2-way synchronization with Google Calendar.")

        Rectangle {
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer2
            implicitHeight: 38
            implicitWidth: installRow.implicitWidth + 24

            RowLayout {
                id: installRow
                anchors.centerIn: parent
                spacing: 12

                StyledText {
                    text: root.installCommand
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                }

                MaterialSymbol {
                    text: "content_copy"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colPrimary
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["wl-copy", root.installCommand])
            }
        }
    }

    // Step 2: Google Calendar credentials
    WelcomeTutorialStep {
        stepNumber: "2"
        stateKind: CalendarService.khalAvailable ? "complete" : "pending"
        title: Translation.tr("Create Google Calendar OAuth credentials")
        supportingText: Translation.tr("In Google Cloud Console, enable the Google Calendar API and create an OAuth Client ID for a Desktop Application.")

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
                onClicked: Qt.openUrlExternally("https://console.cloud.google.com/apis/credentials")
            }
        }
    }

    // Step 3: Configure vdirsyncer
    WelcomeTutorialStep {
        stepNumber: "3"
        stateKind: CalendarService.khalAvailable ? "complete" : "pending"
        title: Translation.tr("Configure vdirsyncer (~/.config/vdirsyncer/config)")
        supportingText: Translation.tr("Create the configuration file to link your Google Calendar to a local calendar directory (click to copy template):")

        Rectangle {
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer2
            implicitHeight: 74
            Layout.fillWidth: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: "~/.config/vdirsyncer/config"
                        font.weight: Font.DemiBold
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colPrimary
                    }
                    Item { Layout.fillWidth: true }
                    MaterialSymbol { text: "content_copy"; iconSize: 14; color: Appearance.colors.colPrimary }
                }

                StyledText {
                    text: "[general]\nstatus_path = \"~/.local/share/vdirsyncer/status/\""
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller - 1
                    color: Appearance.colors.colOnLayer2
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const sample = '[general]\nstatus_path = "~/.local/share/vdirsyncer/status/"\n\n[pair google_calendar]\na = "google_calendar_local"\nb = "google_calendar_remote"\ncollections = ["from a", "from b"]\n\n[storage google_calendar_local]\ntype = "filesystem"\npath = "~/.local/share/calendars/"\nfileext = ".ics"\n\n[storage google_calendar_remote]\ntype = "google_calendar"\nclient_id = "YOUR_CLIENT_ID"\nclient_secret = "YOUR_CLIENT_SECRET"';
                    Quickshell.execDetached(["wl-copy", sample]);
                }
            }
        }
    }

    // Step 4: Discover & Sync
    WelcomeTutorialStep {
        stepNumber: "4"
        stateKind: CalendarService.khalAvailable ? "complete" : "pending"
        title: Translation.tr("Discover and synchronize calendars")
        supportingText: Translation.tr("Run discovery once to authorize Google Calendar, then run your first sync:")

        RowLayout {
            spacing: 10

            Rectangle {
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                implicitHeight: 36
                implicitWidth: discRow.implicitWidth + 20

                RowLayout {
                    id: discRow
                    anchors.centerIn: parent
                    spacing: 8
                    StyledText { text: "vdirsyncer discover"; font.family: Appearance.font.family.monospace; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1 }
                    MaterialSymbol { text: "content_copy"; iconSize: 14; color: Appearance.colors.colPrimary }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["wl-copy", "vdirsyncer discover"])
                }
            }

            Rectangle {
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                implicitHeight: 36
                implicitWidth: syncRow.implicitWidth + 20

                RowLayout {
                    id: syncRow
                    anchors.centerIn: parent
                    spacing: 8
                    StyledText { text: "vdirsyncer sync"; font.family: Appearance.font.family.monospace; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1 }
                    MaterialSymbol { text: "content_copy"; iconSize: 14; color: Appearance.colors.colPrimary }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["wl-copy", "vdirsyncer sync"])
                }
            }
        }
    }

    // Step 5: Configure khal
    WelcomeTutorialStep {
        stepNumber: "5"
        stateKind: CalendarService.khalAvailable ? "complete" : "pending"
        title: Translation.tr("Configure khal (~/.config/khal/config)")
        supportingText: Translation.tr("Point khal to the synchronized calendars directory:")

        Rectangle {
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer2
            implicitHeight: 38
            implicitWidth: khalConfRow.implicitWidth + 24

            RowLayout {
                id: khalConfRow
                anchors.centerIn: parent
                spacing: 10
                StyledText { text: "khal configure"; font.family: Appearance.font.family.monospace; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1 }
                MaterialSymbol { text: "content_copy"; iconSize: 14; color: Appearance.colors.colPrimary }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["wl-copy", "khal configure"])
            }
        }
    }

    // Step 6: Verify in II
    WelcomeTutorialStep {
        stepNumber: "6"
        isLast: true
        stateKind: CalendarService.khalAvailable ? "complete" : "pending"
        title: Translation.tr("Verify calendar in II")
        supportingText: CalendarService.khalAvailable
            ? Translation.tr("✓ Calendar ready! Your schedule is active in the cheatsheet and bar.")
            : Translation.tr("Once khal is configured with local calendars, events will appear automatically.")

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }

            RippleButtonWithIcon {
                materialIcon: "calendar_month"
                mainText: Translation.tr("Open Calendar in Cheatsheet")
                centerContent: true
                horizontalPadding: 16
                buttonRadius: Appearance.rounding.full
                implicitHeight: 40
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                colText: Appearance.colors.colOnPrimary
                onClicked: root.openSettingsTarget("cheatSheet", "", "calendar_month")
            }
        }
    }
}
