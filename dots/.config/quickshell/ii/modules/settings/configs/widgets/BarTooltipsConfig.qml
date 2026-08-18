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
                text: Translation.tr("Bar Tooltips")
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer0
            }
        }

        ContentSection {
            title: Translation.tr("Tooltip behavior")
            icon: "tooltip"

            ConfigSwitch {
                buttonIcon: "visibility"
                text: Translation.tr("Enable tooltips")
                checked: Config.options.bar.tooltips.enableTooltips
                property bool readyForToggle: false
                Component.onCompleted: readyForToggle = true
                onCheckedChanged: {
                    if (!readyForToggle || !Config.ready)
                        return;
                    Config.options.bar.tooltips.enableTooltips = checked;
                }
            }

            ConfigSwitch {
                enabled: Config.options.bar.tooltips.enableTooltips
                buttonIcon: "ads_click"
                text: Translation.tr("Click to show tooltips")
                checked: Config.options.bar.tooltips.clickToShow
                onCheckedChanged: Config.options.bar.tooltips.clickToShow = checked
            }

            ConfigSwitch {
                enabled: Config.options.bar.tooltips.enableTooltips
                buttonIcon: "compress"
                text: Translation.tr("Compact popups")
                checked: Config.options.bar.tooltips.compactPopups
                onCheckedChanged: Config.options.bar.tooltips.compactPopups = checked
            }

            ConfigSlider {
                enabled: Config.options.bar.tooltips.enableTooltips
                buttonIcon: "aspect_ratio"
                text: Translation.tr("Popup scale multiplier")
                value: Config.options.bar.tooltips.popupScaleMultiplier
                usePercentTooltip: false
                tooltipContent: `${(Config.options.bar.tooltips.popupScaleMultiplier ?? 1.0).toFixed(2)}x`
                from: 0.5
                to: 2
                stepSize: 0.05
                onValueChanged: Config.options.bar.tooltips.popupScaleMultiplier = Math.round(value * 100) / 100
            }

            ConfigSpinBox {
                enabled: Config.options.bar.tooltips.enableTooltips
                icon: "timer"
                text: Translation.tr("Popup close delay (ms)")
                value: Config.options.bar.tooltips.closeDelay ?? 0
                from: 0
                to: 2000
                stepSize: 50
                onValueChanged: Config.options.bar.tooltips.closeDelay = value
            }
        }
    }
}
