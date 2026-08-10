import QtQuick
import qs.modules.common

MouseArea {
    id: root

    readonly property bool isWidgetCanvas: true
    property real snapLineX: -1
    property real snapLineY: -1
    property bool draggingActive: false
    property bool gridOverlayEnabled: false
    property int alignmentGridStep: 10
    onAlignmentGridStepChanged: dotGrid.requestPaint()

    Canvas {
        id: dotGrid
        anchors.fill: parent
        z: -1
        visible: root.draggingActive && root.gridOverlayEnabled && opacity > 0.001
        opacity: root.draggingActive && root.gridOverlayEnabled ? 0.55 : 0

        readonly property real dotSize: 1.5
        readonly property color dotColor: Appearance.colors.colPrimary

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = dotGrid.dotColor;

            const offset = dotGrid.dotSize / 2;
            const step = Math.max(1, root.alignmentGridStep);
            for (let y = 0; y <= height; y += step) {
                for (let x = 0; x <= width; x += step) {
                    ctx.fillRect(x - offset, y - offset, dotGrid.dotSize, dotGrid.dotSize);
                }
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onDotColorChanged: requestPaint()
        onVisibleChanged: {
            if (visible)
                requestPaint();
        }

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    Rectangle {
        id: snapLineV
        visible: root.snapLineX >= 0
        x: root.snapLineX
        width: 1.5
        height: root.height
        color: Appearance.colors.colPrimary
        z: 999
    }
    Rectangle {
        id: snapLineH
        visible: root.snapLineY >= 0
        y: root.snapLineY
        width: root.width
        height: 1.5
        color: Appearance.colors.colPrimary
        z: 999
    }
}
