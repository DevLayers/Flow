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
                text: Translation.tr("Blur style")
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer0
            }
        }

        ContentSection {
            title: Translation.tr("Blur style")
            icon: "blur_on"

            ConfigSlider {
                buttonIcon: "lens_blur"
                text: Translation.tr("Blur intensity")
                usePercentTooltip: true
                from: 0
                to: 100
                stepSize: 1
                value: Config.options.lock.effects.blurRadius ?? 80
                onValueChanged: {
                    Config.options.lock.effects.blurRadius = value;
                }
            }

            ConfigSlider {
                buttonIcon: "tonality"
                text: Translation.tr("Desaturation amount")
                usePercentTooltip: true
                from: 0
                to: 100
                stepSize: 1
                value: Config.options.lock.effects.desaturate ?? 30
                onValueChanged: {
                    Config.options.lock.effects.desaturate = value;
                }
            }

            ConfigSlider {
                buttonIcon: "format_color_fill"
                text: Translation.tr("Color wash tint opacity")
                usePercentTooltip: true
                from: 0
                to: 100
                stepSize: 1
                value: Config.options.lock.effects.tintOpacity ?? 40
                onValueChanged: {
                    Config.options.lock.effects.tintOpacity = value;
                }
            }

            ConfigSlider {
                buttonIcon: "vignette"
                text: Translation.tr("Vignette intensity")
                usePercentTooltip: true
                from: 0
                to: 100
                stepSize: 1
                value: Config.options.lock.effects.vignetteRadius ?? 50
                onValueChanged: {
                    Config.options.lock.effects.vignetteRadius = value;
                }
            }
        }
    }
}
