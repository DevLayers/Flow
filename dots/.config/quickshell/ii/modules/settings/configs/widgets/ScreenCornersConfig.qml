import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    forceWidth: false
    property bool showBackButton: false
    signal goBack()

    RowLayout {
        visible: root.showBackButton
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

            MaterialSymbol {
                anchors.centerIn: parent
                text: "arrow_back"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSecondaryContainer
            }

            onClicked: root.goBack()
        }

        StyledText {
            text: Translation.tr("Screen Corners Configuration")
            font.pixelSize: Appearance.font.pixelSize.large
            font.family: Appearance.font.family.title
            color: Appearance.colors.colOnLayer0
        }
    }

    ContentSection {
        title: Translation.tr("Corner Activation & Actions")
        icon: "mouse"

        ConfigSwitch {
            buttonIcon: "pan_tool_alt"
            text: Translation.tr("Hover to trigger")
            checked: Config.options.sidebar.cornerOpen.clickless
            onCheckedChanged: {
                Config.options.sidebar.cornerOpen.clickless = checked;
            }
        }

        ConfigSwitch {
            enabled: Config.options.sidebar.cornerOpen.clickless
            buttonIcon: "format_align_justify"
            text: Translation.tr("Force hover open at absolute corner")
            checked: Config.options.sidebar.cornerOpen.clicklessCornerEnd
            onCheckedChanged: {
                Config.options.sidebar.cornerOpen.clicklessCornerEnd = checked;
            }
        }

        ConfigSpinBox {
            icon: "vertical_align_top"
            text: Translation.tr("Vertical offset")
            value: Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset
            from: 0
            to: 500
            stepSize: 10
            onValueChanged: {
                Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset = value;
            }
        }

        ConfigSwitch {
            buttonIcon: "vertical_align_bottom"
            text: Translation.tr("Place at bottom")
            checked: Config.options.sidebar.cornerOpen.bottom
            onCheckedChanged: {
                Config.options.sidebar.cornerOpen.bottom = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "swap_vert"
            text: Translation.tr("Value scroll (Volume/Brightness)")
            checked: Config.options.sidebar.cornerOpen.valueScroll
            onCheckedChanged: {
                Config.options.sidebar.cornerOpen.valueScroll = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "visibility"
            text: Translation.tr("Visualize corner region")
            checked: Config.options.sidebar.cornerOpen.visualize
            onCheckedChanged: {
                Config.options.sidebar.cornerOpen.visualize = checked;
            }
        }

        ConfigSpinBox {
            icon: "straighten"
            text: Translation.tr("Region width")
            value: Config.options.sidebar.cornerOpen.cornerRegionWidth
            from: 1
            to: 100
            stepSize: 1
            onValueChanged: {
                Config.options.sidebar.cornerOpen.cornerRegionWidth = value;
            }
        }

        ConfigSpinBox {
            icon: "height"
            text: Translation.tr("Region height")
            value: Config.options.sidebar.cornerOpen.cornerRegionHeight
            from: 1
            to: 500
            stepSize: 5
            onValueChanged: {
                Config.options.sidebar.cornerOpen.cornerRegionHeight = value;
            }
        }
    }
}
