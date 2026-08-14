import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: root

    required property string label
    property string toggleIcon: ""

    signal toggleRequested(bool value)

    implicitHeight: Appearance.rounding.verylarge + Appearance.rounding.small
    buttonRadius: Appearance.rounding.full
    colBackground: root.checked
        ? Appearance.colors.colSecondaryContainer
        : Appearance.colors.colLayer2
    colBackgroundHover: root.checked
        ? Appearance.colors.colSecondaryContainerHover
        : Appearance.colors.colLayer2Hover
    colBackgroundActive: root.checked
        ? Appearance.colors.colSecondaryContainerActive
        : Appearance.colors.colLayer2Active
    colRipple: root.checked
        ? Appearance.colors.colSecondaryContainerActive
        : Appearance.colors.colLayer2Active

    contentItem: RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Appearance.rounding.normal
        anchors.rightMargin: Appearance.rounding.small
        spacing: Appearance.rounding.small

        MaterialShapeWrappedMaterialSymbol {
            visible: root.toggleIcon.length > 0
            Layout.alignment: Qt.AlignVCenter
            text: root.toggleIcon
            iconSize: Appearance.font.pixelSize.normal
            padding: Appearance.rounding.verysmall
            fill: 1
            shape: root.checked
                ? MaterialShape.Shape.Cookie7Sided
                : MaterialShape.Shape.Clover4Leaf
            color: root.checked
                ? Appearance.colors.colPrimaryContainer
                : Appearance.colors.colLayer3
            colSymbol: root.checked
                ? Appearance.colors.colOnPrimaryContainer
                : Appearance.colors.colOnLayer3
        }

        StyledText {
            Layout.fillWidth: true
            text: root.label
            color: root.checked
                ? Appearance.colors.colOnSecondaryContainer
                : Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        StyledSwitch {
            Layout.alignment: Qt.AlignVCenter
            sizeScale: 0.72
            checked: root.checked
            enabled: false
        }
    }

    onClicked: root.toggleRequested(!root.checked)
}
