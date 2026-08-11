import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.welcome

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

                WelcomeKeybindCard {
                    Layout.fillWidth: true
                    title: Translation.tr("Settings")
                    materialIcon: "settings"
                    key1: "󰖳"
                    key2: "I"
                }
                WelcomeKeybindCard {
                    Layout.fillWidth: true
                    title: Translation.tr("Control dashboard")
                    materialIcon: "side_navigation"
                    key1: "󰖳"
                    key2: "N"
                }
                WelcomeKeybindCard {
                    Layout.fillWidth: true
                    title: Translation.tr("AI sidebar")
                    materialIcon: "neurology"
                    key1: "󰖳"
                    key2: "A"
                }
                WelcomeKeybindCard {
                    Layout.fillWidth: true
                    title: Translation.tr("Overview")
                    materialIcon: "grid_view"
                    key1: "󰖳"
                    key2: "Tab"
                }
                WelcomeKeybindCard {
                    Layout.fillWidth: true
                    title: Translation.tr("App launcher")
                    materialIcon: "search"
                    key1: "󰖳"
                    key2: "Space"
                }
                WelcomeKeybindCard {
                    Layout.fillWidth: true
                    title: Translation.tr("Cheatsheet")
                    materialIcon: "help"
                    key1: "󰖳"
                    key2: "/"
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
                    onClicked: Qt.openUrlExternally("https://github.com/P3DROVFX/ii-p3drovfx")
                }

                WelcomeActionCard {
                    Layout.fillWidth: true
                    materialIcon: "help_center"
                    title: Translation.tr("Documentation wiki")
                    description: Translation.tr("Usage notes and additional guides")
                    onClicked: Qt.openUrlExternally("https://end-4.github.io/dots-hyprland-wiki/en/ii-qs/02usage/")
                }
            }
        }
    }
}
