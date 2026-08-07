pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

RippleButton {
    id: root

    required property var aa
    required property real hueOffset
    required property real shade
    property bool selected: false

    readonly property color tint: ColorUtils.categoryAccent(root.hueOffset, root.shade, Appearance.m3colors.m3primary)
    readonly property color onTint: ColorUtils.categoryOnColor(root.tint)

    implicitWidth: 280
    implicitHeight: 170
    buttonRadius: Appearance.rounding.normal

    colBackground: Appearance.colors.colLayer2
    colBackgroundHover: Appearance.colors.colLayer2Hover
    colRipple: Appearance.colors.colLayer2Active

    // No per-card entrance animation: the grid fades in as one group instead.

    Rectangle {
        anchors.fill: parent
        radius: root.buttonRadius
        color: "transparent"
        border.width: root.selected ? 2 : 1
        border.color: root.selected ? root.tint : Appearance.colors.colLayer0Border
    }

    // Class colour stripe
    Rectangle {
        id: stripe
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            leftMargin: 8
            topMargin: 10
            bottomMargin: 10
        }
        width: 4
        radius: Appearance.rounding.full
        color: root.tint
    }

    MoleculeStructure {
        id: molecule
        anchors {
            top: parent.top
            left: stripe.right
            right: parent.right
            topMargin: 10
            leftMargin: 10
            rightMargin: 10
        }
        height: parent.height - footer.height - 22
        structure: root.aa.structure
        bondLength: 26
        colMain: Appearance.colors.colOnLayer2
        colAccent: root.tint
    }

    Item {
        id: footer
        anchors {
            left: stripe.right
            right: parent.right
            bottom: parent.bottom
            leftMargin: 10
            rightMargin: 10
            bottomMargin: 9
        }
        implicitHeight: Math.max(nameColumn.implicitHeight, badge.height)
        height: implicitHeight

        Column {
            id: nameColumn
            anchors {
                left: parent.left
                right: badge.left
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            spacing: 0

            StyledText {
                width: parent.width
                text: root.aa.name
                elide: Text.ElideRight
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
            }

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: `${root.aa.three} · ${root.aa.mw.toFixed(2)} g·mol⁻¹`
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }

        Rectangle {
            id: badge
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            width: 34
            height: 34
            radius: Appearance.rounding.full
            color: root.tint

            StyledText {
                anchors.centerIn: parent
                text: root.aa.one
                color: root.onTint
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.DemiBold
            }
        }
    }
}
