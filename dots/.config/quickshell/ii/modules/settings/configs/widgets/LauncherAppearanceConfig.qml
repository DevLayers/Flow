import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root
    anchors.fill: parent
    property bool showBackButton: false
    signal goBack()

    ContentPage {
        anchors.fill: parent
        forceWidth: false
        RowLayout {
            visible: root.showBackButton
            spacing: Appearance.sizes.elevationMargin
            RippleButton { implicitWidth: Appearance.sizes.elevationMargin * 4; implicitHeight: implicitWidth; buttonRadius: Appearance.rounding.full; colBackground: Appearance.colors.colSecondaryContainer; colBackgroundHover: Appearance.colors.colSecondaryContainerHover; colRipple: Appearance.colors.colSecondaryContainerActive; onClicked: root.goBack(); MaterialSymbol { anchors.centerIn: parent; text: "arrow_back"; iconSize: Appearance.font.pixelSize.large; color: Appearance.colors.colOnSecondaryContainer } }
            StyledText { text: Translation.tr("Panel appearance"); font.pixelSize: Appearance.font.pixelSize.large; font.family: Appearance.font.family.title; color: Appearance.colors.colOnLayer0 }
        }
        ContentSection {
            icon: "palette"
            title: Translation.tr("Panel appearance")
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.elevationMargin / 2
                ConfigSwitch { buttonIcon: "format_paint"; text: Translation.tr("Accent keyword panels"); checked: Config.options.search.appearance.accentPanels; onCheckedChanged: Config.options.search.appearance.accentPanels = checked }
                ConfigSwitch { buttonIcon: "keyboard"; text: Translation.tr("Show keyboard hints"); checked: Config.options.search.appearance.showKeyHints; onCheckedChanged: Config.options.search.appearance.showKeyHints = checked }
                ConfigSwitch { buttonIcon: "space_bar"; text: Translation.tr("Show hint bar"); checked: Config.options.search.appearance.showKeyHintBar; onCheckedChanged: Config.options.search.appearance.showKeyHintBar = checked }
                ConfigSlider { buttonIcon: "opacity"; text: Translation.tr("Accent strength"); value: Config.options.search.appearance.accentStrength * 100; from: 0; to: 30; stepSize: 1; usePercentTooltip: true; onValueChanged: Config.options.search.appearance.accentStrength = value / 100 }
                ConfigSlider { buttonIcon: "height"; text: Translation.tr("Search max height (px)"); value: Config.options.search.baseHeight; from: 300; to: 900; stepSize: 10; usePercentTooltip: false; onValueChanged: Config.options.search.baseHeight = value }
            }
        }
    }
}
