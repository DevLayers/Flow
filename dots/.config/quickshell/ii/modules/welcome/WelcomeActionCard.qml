import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: root

    property string materialIcon: "circle"
    property string title: ""
    property string description: ""
    property string statusText: ""
    property bool selected: false
    property bool showChevron: true
    property int iconShape: MaterialShape.Shape.Cookie7Sided
    property color selectedBackground: Appearance.colors.colPrimaryContainer
    property color selectedForeground: Appearance.colors.colOnPrimaryContainer

    toggled: selected
    implicitHeight: 116
    buttonRadius: Appearance.rounding.large
    buttonRadiusPressed: Appearance.rounding.full
    colBackground: Appearance.colors.colLayer1
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colBackgroundActive: Appearance.colors.colLayer1Active
    colBackgroundToggled: root.selectedBackground
    colBackgroundToggledHover: Appearance.colors.colPrimaryContainerHover
    colBackgroundToggledActive: Appearance.colors.colPrimaryContainerActive
    colRipple: Appearance.colors.colLayer1Active
    colRippleToggled: Appearance.colors.colPrimaryContainerActive

    contentItem: RowLayout {
        spacing: 16

        MaterialShapeWrappedMaterialSymbol {
            Layout.leftMargin: 18
            Layout.alignment: Qt.AlignVCenter
            text: root.materialIcon
            shape: root.iconShape
            iconSize: Appearance.font.pixelSize.large
            padding: 12
            fill: root.selected ? 1 : 0
            color: root.selected ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer
            colSymbol: root.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            StyledText {
                Layout.fillWidth: true
                text: root.title
                color: root.selected ? root.selectedForeground : Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.description.length > 0
                text: root.description
                color: root.selected ? root.selectedForeground : Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.statusText.length > 0
                text: root.statusText
                color: root.selected ? root.selectedForeground : Appearance.colors.colPrimary
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        MaterialSymbol {
            Layout.rightMargin: 18
            Layout.alignment: Qt.AlignVCenter
            visible: root.showChevron
            text: "arrow_forward"
            iconSize: Appearance.font.pixelSize.normal
            color: root.selected ? root.selectedForeground : Appearance.colors.colOnLayer2
        }
    }
}
