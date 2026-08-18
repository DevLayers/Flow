import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: subPageRoot
    anchors.fill: parent

    property bool showBackButton: false
    signal goBack()

    ContentPage {
        id: page
        anchors.fill: parent
        forceWidth: false

        RowLayout {
            visible: subPageRoot.showBackButton
            spacing: 12

            RippleButton {
                implicitWidth: implicitHeight
                implicitHeight: 40
                topLeftRadius: Appearance.rounding.full
                topRightRadius: Appearance.rounding.full
                bottomLeftRadius: Appearance.rounding.full
                bottomRightRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: subPageRoot.goBack()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            StyledText {
                text: Translation.tr("App Groups")
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer0
            }
        }

        ContentSection {
            title: Translation.tr("App Groups Behavior")
            icon: "folder_special"

            ConfigSwitch {
                buttonIcon: "folder_special"
                text: Translation.tr("Enable app groups")
                checked: Config.options.dock.enableAppGroups ?? true
                onCheckedChanged: {
                    Config.options.dock.enableAppGroups = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Combine up to six apps into dock groups by dragging one app onto another.")
                }
            }

            ConfigSwitch {
                enabled: Config.options.dock.enableAppGroups ?? true
                buttonIcon: "group_work"
                text: Translation.tr("Smart auto-grouping")
                checked: Config.options.dock.smartGrouping
                onCheckedChanged: {
                    Config.options.dock.smartGrouping = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Automatically groups matching or related application instances in the dock.")
                }
            }
        }
    }
}
