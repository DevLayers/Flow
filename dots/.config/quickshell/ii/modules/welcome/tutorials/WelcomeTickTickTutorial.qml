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

    title: Translation.tr("Set up TickTick sync")
    subtitle: Translation.tr("Keep your tasks synchronized across II's sidebar and task widgets with your TickTick account.")
    materialIcon: "task_alt"
    statusText: WelcomeTutorialRegistry.statusTextFor("ticktick")
    statusKind: WelcomeTutorialRegistry.stateKindFor("ticktick")
    usedInChips: ["Tasks sidebar", "Tasks"]

    signal openSettingsTarget(string pageId, string subPageId, string sectionId)

    property string tempClientId: TickTickService.clientId || ""
    property string tempClientSecret: TickTickService.clientSecret || ""
    property bool authRunning: false
    property string authErrorMsg: ""

    Process {
        id: authTokenProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.authRunning = false;
                try {
                    let data = JSON.parse(text);
                    if (data.access_token) {
                        TickTickService.saveCredentials(root.tempClientId, root.tempClientSecret, data.access_token);
                    } else if (data.error) {
                        root.authErrorMsg = data.error;
                    }
                } catch(e) {
                    root.authErrorMsg = Translation.tr("Failed to parse authorization response");
                }
            }
        }
    }

    // Step 1: Create Developer App
    WelcomeTutorialStep {
        stepNumber: "1"
        stateKind: String(TickTickService.accessToken || "").length > 0 ? "complete" : "current"
        title: Translation.tr("Create a TickTick developer app")
        supportingText: Translation.tr("Open TickTick Developer Center and register a new application for II.")

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }

            RippleButtonWithIcon {
                materialIcon: "open_in_new"
                mainText: Translation.tr("Open Developer Center")
                centerContent: true
                horizontalPadding: 16
                buttonRadius: Appearance.rounding.full
                implicitHeight: 40
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colText: Appearance.colors.colOnSecondaryContainer
                onClicked: Qt.openUrlExternally("https://developer.ticktick.com/manage")
            }
        }
    }

    // Step 2: Configure Redirect URL
    WelcomeTutorialStep {
        stepNumber: "2"
        stateKind: String(TickTickService.accessToken || "").length > 0 ? "complete" : "current"
        title: Translation.tr("Configure the redirect URL")
        supportingText: Translation.tr("Set this local redirect URL in your TickTick developer application settings (click to copy):")

        Rectangle {
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer2
            implicitHeight: 38
            implicitWidth: redirectUrlRow.implicitWidth + 24

            RowLayout {
                id: redirectUrlRow
                anchors.centerIn: parent
                spacing: 12

                StyledText {
                    text: "http://localhost:18321"
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
                onClicked: {
                    Quickshell.execDetached(["wl-copy", "http://localhost:18321"]);
                }
            }
        }
    }

    // Step 3: Enter Credentials
    WelcomeTutorialStep {
        stepNumber: "3"
        stateKind: String(TickTickService.accessToken || "").length > 0 ? "complete" : (root.tempClientId.length > 0 ? "current" : "pending")
        title: Translation.tr("Add your TickTick credentials")
        supportingText: Translation.tr("Enter the Client ID and Client Secret generated in the Developer Center.")

        ConfigTextField {
            Layout.fillWidth: true
            text: Translation.tr("Client ID")
            icon: "key"
            placeholderText: Translation.tr("Enter your TickTick Client ID")
            inputText: root.tempClientId
            textField.onTextChanged: root.tempClientId = textField.text.trim()
        }

        ConfigTextField {
            Layout.fillWidth: true
            text: Translation.tr("Client Secret")
            icon: "vpn_key"
            placeholderText: Translation.tr("Enter your TickTick Client Secret")
            inputText: root.tempClientSecret
            textField.echoMode: TextInput.Password
            textField.onTextChanged: root.tempClientSecret = textField.text.trim()
        }
    }

    // Step 4: Authorize in Browser
    WelcomeTutorialStep {
        stepNumber: "4"
        stateKind: String(TickTickService.accessToken || "").length > 0 ? "complete" : (root.tempClientId.length > 0 && root.tempClientSecret.length > 0 ? "current" : "pending")
        title: Translation.tr("Authorize TickTick")
        supportingText: Translation.tr("II will open TickTick in your browser. Approve access to your tasks to complete the authorization.")

        StyledText {
            visible: root.authErrorMsg.length > 0
            text: root.authErrorMsg
            color: Appearance.colors.colError
            font.pixelSize: Appearance.font.pixelSize.small
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }

            RippleButton {
                implicitHeight: 44
                implicitWidth: 260
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                enabled: !root.authRunning && root.tempClientId.length > 0 && root.tempClientSecret.length > 0
                onClicked: {
                    root.authRunning = true;
                    root.authErrorMsg = "";
                    authTokenProc.command = ["python3", Quickshell.shellPath("scripts/ticktick/get_token.py"), root.tempClientId, root.tempClientSecret];
                    authTokenProc.running = false;
                    authTokenProc.running = true;
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialSymbol {
                        text: root.authRunning ? "hourglass_empty" : "key"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnPrimary
                    }
                    StyledText {
                        text: root.authRunning ? Translation.tr("Authorizing in browser…") : Translation.tr("Authorize & Generate Token")
                        color: Appearance.colors.colOnPrimary
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }

    // Step 5: Verify Synchronization
    WelcomeTutorialStep {
        stepNumber: "5"
        isLast: true
        stateKind: TickTickService.available ? "complete" : "pending"
        title: Translation.tr("Verify synchronization")
        supportingText: TickTickService.available
            ? Translation.tr("✓ TickTick connected! Your tasks are synchronized across II.")
            : Translation.tr("Create or edit a task in TickTick and verify that it appears in the Tasks sidebar.")

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }

            RippleButtonWithIcon {
                materialIcon: "settings"
                mainText: Translation.tr("Open TickTick Settings")
                centerContent: true
                horizontalPadding: 16
                buttonRadius: Appearance.rounding.full
                implicitHeight: 40
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                colText: Appearance.colors.colOnPrimary
                onClicked: root.openSettingsTarget("tasksAccounts", "", "ticktick")
            }
        }
    }
}
