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
    implicitHeight: 74
    buttonRadius: Appearance.rounding.large
    buttonRadiusPressed: Appearance.rounding.normal
    colBackground: Appearance.colors.colLayer1
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colBackgroundActive: Appearance.colors.colLayer1Active
    colBackgroundToggled: root.selectedBackground
    colBackgroundToggledHover: Appearance.colors.colPrimaryContainerHover
    colBackgroundToggledActive: Appearance.colors.colPrimaryContainerActive
    colRipple: Appearance.colors.colLayer1Active
    colRippleToggled: Appearance.colors.colPrimaryContainerActive

    contentItem: RowLayout {
        spacing: 12

        MaterialShapeWrappedMaterialSymbol {
            Layout.leftMargin: 12
            Layout.alignment: Qt.AlignVCenter
            text: root.materialIcon
            shape: root.hovered
                ? MaterialShape.Shape.SoftBurst
                : root.iconShape
            iconSize: Appearance.font.pixelSize.large - 2
            padding: 9
            fill: root.selected ? 1 : 0
            color: root.selected ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer
            colSymbol: root.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
            rotation: root.hovered ? 8 : 0

            Behavior on rotation {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.title
                color: root.selected ? root.selectedForeground : Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.description.length > 0
                text: root.description
                color: root.selected ? root.selectedForeground : Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
                maximumLineCount: 1
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

    }
}
