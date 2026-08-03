import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * One tiling zone drawn on the overlay. Purely visual - the window never takes
 * input, so the whole surface stays click-through while the user drags.
 */
Rectangle {
    id: root

    required property bool hovered
    required property string label
    property bool showLabel: true
    property real baseOpacity: 0.28
    property real hoveredOpacity: 0.55
    property int animationDuration: 150

    color: ColorUtils.applyAlpha(Appearance.colors.colPrimaryContainer, root.hovered ? root.hoveredOpacity : root.baseOpacity)
    border.width: root.hovered ? 3 : 1
    border.color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, root.hovered ? 0.95 : 0.4)
    // Grows a touch under the cursor so the target reads at a glance even on a
    // layout where every zone is the same size.
    scale: root.hovered ? 1 : 0.985

    Rectangle {
        anchors.centerIn: parent
        visible: root.showLabel && root.label.length > 0
        implicitWidth: zoneLabel.implicitWidth + 24
        implicitHeight: zoneLabel.implicitHeight + 12
        radius: Appearance.rounding.small
        color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, root.hovered ? 1 : 0.65)

        StyledText {
            id: zoneLabel

            anchors.centerIn: parent
            text: root.label
            color: Appearance.colors.colOnPrimary
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: root.hovered ? Font.DemiBold : Font.Normal
        }

        Behavior on color {
            ColorAnimation {
                duration: root.animationDuration
                easing.type: Easing.OutCubic
            }

        }

    }

    Behavior on color {
        ColorAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }

    }

    Behavior on border.color {
        ColorAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }

    }

    Behavior on border.width {
        NumberAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: root.animationDuration
            easing.type: Easing.OutCubic
        }

    }

}
