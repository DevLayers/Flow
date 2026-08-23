import QtQuick
import QtQuick.Controls
import qs.modules.common

Flickable {
    id: root
    maximumFlickVelocity: 3500
    boundsBehavior: Flickable.DragOverBounds

    property real touchpadScrollFactor: Config?.options.interactions.scrolling.touchpadScrollFactor ?? 100
    property real mouseScrollFactor: Config?.options.interactions.scrolling.mouseScrollFactor ?? 50
    property real mouseScrollDeltaThreshold: Config?.options.interactions.scrolling.mouseScrollDeltaThreshold ?? 120
    // Accumulated scroll destination so wheel deltas stack while animating
    property real scrollTargetY: 0

    // The Behavior below must smooth wheel jumps only. Left unguarded it also
    // intercepts the contentY that Flickable writes on every drag and flick
    // frame, which fights its own physics and makes long pages feel like they
    // stutter under the cursor.
    property bool _wheelScrolling: false

    ScrollBar.vertical: StyledScrollBar {}

    // Do not overlay the content with a MouseArea: that would replace every
    // delegate's pointer cursor with the default arrow while scrolling is on.
    WheelHandler {
        enabled: Config?.options.interactions.scrolling.fasterTouchpadScroll
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: wheelEvent => {
            const delta = wheelEvent.angleDelta.y / root.mouseScrollDeltaThreshold;
            // The angleDelta.y of a touchpad is usually small and continuous,
            // while that of a mouse wheel is typically in multiples of ±120.
            var scrollFactor = Math.abs(wheelEvent.angleDelta.y) >= root.mouseScrollDeltaThreshold ? root.mouseScrollFactor : root.touchpadScrollFactor;

            const maxY = Math.max(0, root.contentHeight - root.height);
            const base = scrollAnim.running ? root.scrollTargetY : root.contentY;
            var targetY = Math.max(0, Math.min(base - delta * scrollFactor, maxY));

            root.scrollTargetY = targetY;
            root._wheelScrolling = true;
            root.contentY = targetY;
            wheelEvent.accepted = true;
        }
    }

    Behavior on contentY {
        enabled: root._wheelScrolling && !root.dragging && !root.flicking
        NumberAnimation {
            id: scrollAnim
            duration: Appearance.animation.scroll.duration
            easing.type: Appearance.animation.scroll.type
            easing.bezierCurve: Appearance.animation.scroll.bezierCurve
            onStopped: root._wheelScrolling = false
        }
    }

    onDraggingChanged: {
        if (root.dragging) {
            scrollAnim.stop();
            root._wheelScrolling = false;
        }
    }

    // Keep target synced when not animating (e.g., drag/flick or programmatic changes)
    onContentYChanged: {
        if (!scrollAnim.running) {
            root.scrollTargetY = root.contentY;
        }
    }

}
