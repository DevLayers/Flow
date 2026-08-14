import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    signal openSettingsTarget(string pageId, string subPageId, string sectionId)

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Everyday")
            color: Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
        }

        GridLayout {
            Layout.fillWidth: true
            columns: width >= 780 ? 4 : 2
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: WelcomeKeybindRegistry.everydayActions
                delegate: WelcomeKeybindCard {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    title: Translation.tr(modelData.labelKey)
                    materialIcon: modelData.icon
                    keys: WelcomeKeybindRegistry.keysFor(modelData.id)
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 2
            text: Translation.tr("Explore")
            color: Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
        }

        GridLayout {
            Layout.fillWidth: true
            columns: width >= 780 ? 4 : 2
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: WelcomeKeybindRegistry.exploreActions
                delegate: WelcomeKeybindCard {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    title: Translation.tr(modelData.labelKey)
                    materialIcon: modelData.icon
                    keys: WelcomeKeybindRegistry.keysFor(modelData.id)
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 4
            text: Translation.tr("Useful places")
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.DemiBold
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 10
            rowSpacing: 10

            WelcomeActionCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                materialIcon: "menu_book"
                title: Translation.tr("Cheatsheet")
                description: Translation.tr("All shortcuts and shell actions")
                onClicked: root.openSettingsTarget("cheatSheet", "", "keyboard")
            }

            WelcomeActionCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                materialIcon: "description"
                title: Translation.tr("Documentation")
                description: Translation.tr("Setup guides and feature documentation")
                onClicked: Qt.openUrlExternally(WelcomeProjectLinks.documentationUrl)
            }

            WelcomeActionCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                materialIcon: "code"
                title: Translation.tr("GitHub")
                description: Translation.tr("Source code, releases and issues")
                onClicked: Qt.openUrlExternally(WelcomeProjectLinks.repositoryUrl)
            }

            WelcomeActionCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                materialIcon: "forum"
                title: Translation.tr("Discord")
                description: Translation.tr("Community and support")
                onClicked: Qt.openUrlExternally(WelcomeProjectLinks.discordUrl)
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
