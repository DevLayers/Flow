import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    signal openSettingsPage(string pageId)

    ContentPage {
        anchors.fill: parent
        bottomContentPadding: 28

        ContentSection {
            Layout.fillWidth: true
            icon: "keyboard"
            title: Translation.tr("Essential shortcuts")

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 880 ? 3 : (width >= 580 ? 2 : 1)
                columnSpacing: 10
                rowSpacing: 10

                Repeater {
                    model: WelcomeKeybindRegistry.actions
                    delegate: WelcomeKeybindCard {
                        required property var modelData
                        Layout.fillWidth: true
                        title: Translation.tr(modelData.labelKey)
                        materialIcon: modelData.icon
                        keys: WelcomeKeybindRegistry.keysFor(modelData.id)
                    }
                }
            }
        }

        ContentSection {
            Layout.fillWidth: true
            icon: "explore"
            title: Translation.tr("Useful places")

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 780 ? 2 : 1
                columnSpacing: 12
                rowSpacing: 12

                WelcomeActionCard {
                    Layout.fillWidth: true
                    materialIcon: "menu_book"
                    title: Translation.tr("Open the complete cheatsheet")
                    description: Translation.tr("See every shortcut, command and workspace action")
                    onClicked: Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "cheatsheet", "open"])
                }

                WelcomeActionCard {
                    Layout.fillWidth: true
                    materialIcon: "settings"
                    title: Translation.tr("Explore Settings")
                    description: Translation.tr("All II features, grouped by purpose")
                    onClicked: root.openSettingsPage("")
                }

                WelcomeActionCard {
                    Layout.fillWidth: true
                    materialIcon: "code"
                    title: Translation.tr("II on GitHub")
                    description: Translation.tr("Updates, source code and issue tracker")
                    onClicked: Qt.openUrlExternally(WelcomeProjectLinks.repositoryUrl)
                }

                WelcomeActionCard {
                    Layout.fillWidth: true
                    visible: WelcomeProjectLinks.documentationAvailable
                    materialIcon: "help_center"
                    title: Translation.tr("Documentation wiki")
                    description: Translation.tr("Usage notes and additional guides")
                    onClicked: Qt.openUrlExternally(WelcomeProjectLinks.documentationUrl)
                }
            }
        }

        ContentSection {
            Layout.fillWidth: true
            icon: "terminal"
            title: Translation.tr("Useful commands")

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Keep these small commands nearby when you need to troubleshoot or reopen II surfaces.")
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 860 ? 3 : (width >= 580 ? 2 : 1)
                columnSpacing: 10
                rowSpacing: 10

                HelperCodeBox {
                    Layout.fillWidth: true
                    title: Translation.tr("Follow shell logs")
                    text: Translation.tr("Useful when reporting a problem.")
                    icon: "receipt_long"
                    codeSnippet: "qs log -f -c ii"
                }

                HelperCodeBox {
                    Layout.fillWidth: true
                    title: Translation.tr("Reopen Welcome")
                    text: Translation.tr("Open the setup flow without changing first-run state.")
                    icon: "waving_hand"
                    codeSnippet: "qs -c ii ipc call welcome open"
                }

                HelperCodeBox {
                    Layout.fillWidth: true
                    title: Translation.tr("Open Settings")
                    text: Translation.tr("Launch Settings directly from a terminal.")
                    icon: "settings"
                    codeSnippet: "qs -c ii ipc call settings open"
                }
            }
        }
    }
}
