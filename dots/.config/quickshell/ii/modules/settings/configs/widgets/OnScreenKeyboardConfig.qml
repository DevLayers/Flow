import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: subPageRoot
    anchors.fill: parent

    property bool showBackButton: false
    signal goBack()

    ContentPage {
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
                text: Translation.tr("On-Screen Keyboard")
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer0
            }
        }

        ContentSection {
            title: Translation.tr("Automatic keyboard")
            icon: "keyboard"

            ConfigSwitch {
                buttonIcon: "pan_tool"
                text: Translation.tr("Trigger with finger")
                enabled: Config.options.osk.autoShow.enable
                checked: Config.options.osk.autoShow.allowTouch
                onCheckedChanged: Config.options.osk.autoShow.allowTouch = checked
            }

            ConfigSwitch {
                buttonIcon: "stylus"
                text: Translation.tr("Trigger with pen")
                enabled: Config.options.osk.autoShow.enable
                checked: Config.options.osk.autoShow.allowPen
                onCheckedChanged: Config.options.osk.autoShow.allowPen = checked
            }

            ConfigSwitch {
                buttonIcon: "keyboard_hide"
                text: Translation.tr("Hide when typing on a real keyboard")
                enabled: Config.options.osk.autoShow.enable
                checked: Config.options.osk.autoShow.hideOnPhysicalKey
                onCheckedChanged: Config.options.osk.autoShow.hideOnPhysicalKey = checked
            }

            ConfigSwitch {
                buttonIcon: "gesture"
                text: Translation.tr("Hide when tapping outside")
                enabled: Config.options.osk.autoShow.enable
                checked: Config.options.osk.autoShow.hideOnTouchOutside
                onCheckedChanged: Config.options.osk.autoShow.hideOnTouchOutside = checked
            }

            ConfigSpinBox {
                icon: "timer"
                text: Translation.tr("Touch window (ms)")
                enabled: Config.options.osk.autoShow.enable
                value: Config.options.osk.autoShow.touchWindowMs
                from: 200
                to: 5000
                stepSize: 100
                onValueChanged: Config.options.osk.autoShow.touchWindowMs = value
            }
        }
    }
}
