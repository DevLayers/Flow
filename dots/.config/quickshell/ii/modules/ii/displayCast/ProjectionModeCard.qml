import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

RippleButton {
    id: root

    required property string modeIcon
    required property string title
    property string description: ""
    property bool active: false

    signal triggered()

    implicitHeight: 74
    buttonRadius: Appearance.rounding.large
    buttonRadiusPressed: Appearance.rounding.normal
    opacity: root.enabled ? 1.0 : 0.45

    colBackground: root.active
        ? ColorUtils.mix(Appearance.colors.colLayer1, Appearance.colors.colPrimaryContainer, 0.24)
        : Appearance.colors.colLayer1
    colBackgroundHover: root.active
        ? ColorUtils.mix(Appearance.colors.colLayer1, Appearance.colors.colPrimaryContainerHover, 0.32)
        : Appearance.colors.colLayer1Hover
    colBackgroundActive: root.active
        ? ColorUtils.mix(Appearance.colors.colLayer1Active, Appearance.colors.colPrimaryContainerActive, 0.38)
        : Appearance.colors.colLayer1Active
    colRipple: root.active
        ? Appearance.colors.colPrimaryContainerActive
        : Appearance.colors.colLayer1Active

    onClicked: {
        if (root.enabled) {
            root.triggered();
        }
    }

    contentItem: RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 8

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: root.modeIcon
            shape: root.active
                ? MaterialShape.Shape.Cookie9Sided
                : (root.hovered ? MaterialShape.Shape.SoftBurst : MaterialShape.Shape.Clover4Leaf)
            iconSize: 18
            padding: 7
            fill: root.active ? 1 : 0
            color: root.active
                ? Appearance.colors.colPrimaryContainer
                : Appearance.colors.colSecondaryContainer
            colSymbol: root.active
                ? Appearance.colors.colOnPrimaryContainer
                : Appearance.colors.colOnSecondaryContainer
            rotation: root.hovered ? 6 : 0

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
                color: Appearance.colors.colOnLayer1
                font.family: Appearance.font.family.title
                font.pixelSize: Appearance.font.pixelSize.body
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.description
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.active ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                elide: Text.ElideRight
                visible: root.description.length > 0
            }
        }

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: "check_circle"
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colPrimary
            opacity: root.active ? 1 : 0
            fill: 1

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
    }
}
