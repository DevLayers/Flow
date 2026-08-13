import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Shortcuts that make II feel fast.")
            color: Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.large
            wrapMode: Text.WordWrap
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: width >= 780 ? 4 : 2
            columnSpacing: 10
            rowSpacing: 10

            Repeater {
                model: WelcomeKeybindRegistry.actions
                delegate: WelcomeKeybindCard {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 76
                    title: Translation.tr(modelData.labelKey)
                    materialIcon: modelData.icon
                    keys: WelcomeKeybindRegistry.keysFor(modelData.id)
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Useful places")
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.large
            font.weight: Font.DemiBold
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 12
            rowSpacing: 12

            WelcomeActionCard {
                Layout.fillWidth: true
                materialIcon: "menu_book"
                title: Translation.tr("Cheatsheet")
                description: Translation.tr("Shortcuts and features")
                onClicked: GlobalStates.cheatsheetOpen = true
            }

            WelcomeActionCard {
                Layout.fillWidth: true
                enabled: WelcomeProjectLinks.documentationAvailable
                materialIcon: "help_center"
                title: Translation.tr("Documentation")
                description: Translation.tr("Guides and setup help")
                statusText: WelcomeProjectLinks.documentationAvailable
                    ? ""
                    : Translation.tr("Coming soon")
                onClicked: Qt.openUrlExternally(WelcomeProjectLinks.documentationUrl)
            }

            WelcomeActionCard {
                Layout.fillWidth: true
                materialIcon: "code"
                title: Translation.tr("GitHub")
                description: Translation.tr("Source and updates")
                onClicked: Qt.openUrlExternally(WelcomeProjectLinks.repositoryUrl)
            }

            WelcomeActionCard {
                Layout.fillWidth: true
                materialIcon: "forum"
                title: Translation.tr("Discord")
                description: Translation.tr("Community and support")
                onClicked: Qt.openUrlExternally("https://discord.gg/GtdRBXgMwq")
            }
        }
    }
}
