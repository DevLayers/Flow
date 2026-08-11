import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: subPageRoot
    anchors.fill: parent

    property bool showBackButton: false
    signal goBack()

    ContentPage {
        id: root
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
                text: Translation.tr("Parallax Engine")
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer0
            }
        }

        ContentSection {
            title: Translation.tr("Parallax Engine")
            icon: "sync_alt"

            ConfigSwitch {
                buttonIcon: "unfold_more_double"
                text: Translation.tr("Vertical movement")
                checked: Config.options.background.parallax.vertical
                onCheckedChanged: {
                    HyprlandSettings.changeAnimation("workspaces", checked ? "slidevert" : "slide");
                    Config.options.background.parallax.vertical = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "counter_1"
                text: Translation.tr("Depends on workspace")
                checked: Config.options.background.parallax.enableWorkspace
                onCheckedChanged: {
                    Config.options.background.parallax.enableWorkspace = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "loop"
                text: Translation.tr("Loop wallpaper")
                checked: Config.options.background.parallax.loop
                onCheckedChanged: {
                    Config.options.background.parallax.loop = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "swap_horiz"
                text: Translation.tr("Invert horizontal movement")
                checked: Config.options.background.parallax.invertHorizontal
                onCheckedChanged: {
                    Config.options.background.parallax.invertHorizontal = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "swap_vert"
                text: Translation.tr("Invert vertical movement")
                checked: Config.options.background.parallax.invertVertical
                onCheckedChanged: {
                    Config.options.background.parallax.invertVertical = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "side_navigation"
                text: Translation.tr("Depends on sidebars")
                checked: Config.options.background.parallax.enableSidebar
                onCheckedChanged: {
                    Config.options.background.parallax.enableSidebar = checked;
                }
            }

            ConfigSlider {
                buttonIcon: "speed"
                text: Translation.tr("Parallax movement intensity")
                visible: Config.options.background.parallax.enableWorkspace
                usePercentTooltip: false
                from: 1
                to: 100
                stepSize: 1
                value: Config.options.background.parallax.intensity ?? 20
                onValueChanged: {
                    Config.options.background.parallax.intensity = value;
                }
            }
        }
    }
}
