import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls

/**
 * A ListView with animations.
 */
ListView {
    id: root
    spacing: 5
    property real removeOvershoot: 20 // Account for gaps and bouncy animations
    property int dragIndex: -1
    property real dragDistance: 0
    property bool popin: true
    property bool animateAppearance: true
    property bool animateMovement: false
    property bool dismissToLeft: false
    property bool useSlideInAnimation: false

    // Accumulated scroll destination so wheel deltas stack while animating
    property real scrollTargetY: 0

    property real touchpadScrollFactor: Config?.options.interactions.scrolling.touchpadScrollFactor ?? 100
    property real mouseScrollFactor: Config?.options.interactions.scrolling.mouseScrollFactor ?? 50
    property real mouseScrollDeltaThreshold: Config?.options.interactions.scrolling.mouseScrollDeltaThreshold ?? 120

    function resetDrag() {
        root.dragIndex = -1;
        root.dragDistance = 0;
    }

    // Suppress animated contentY during external resize (e.g. sidebar bottom group collapsing).
    // When the ListView height changes, Qt auto-adjusts contentY to preserve scroll position.
    // If Behavior on contentY is active during resize, items appear to overlap/jump.
    property bool _suppressScrollAnim: false

    onHeightChanged: {
        root._suppressScrollAnim = true;
        resizeDebounce.restart();
    }

    Timer {
        id: resizeDebounce
        interval: 80
        repeat: false
        onTriggered: root._suppressScrollAnim = false
    }

    maximumFlickVelocity: 3500
    boundsBehavior: Flickable.DragOverBounds
    ScrollBar.vertical: StyledScrollBar {}

    MouseArea {
        visible: Config?.options.interactions.scrolling.fasterTouchpadScroll
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function (wheelEvent) {
            const delta = wheelEvent.angleDelta.y / root.mouseScrollDeltaThreshold;
            // The angleDelta.y of a touchpad is usually small and continuous,
            // while that of a mouse wheel is typically in multiples of ±120.
            var scrollFactor = Math.abs(wheelEvent.angleDelta.y) >= root.mouseScrollDeltaThreshold ? root.mouseScrollFactor : root.touchpadScrollFactor;

            const maxY = Math.max(0, root.contentHeight - root.height);
            const base = scrollAnim.running ? root.scrollTargetY : root.contentY;
            var targetY = Math.max(0, Math.min(base - delta * scrollFactor, maxY));

            root.scrollTargetY = targetY;
            root.contentY = targetY;
            wheelEvent.accepted = true;
        }
    }

    Behavior on contentY {
        enabled: !root._suppressScrollAnim
        NumberAnimation {
            id: scrollAnim
            alwaysRunToEnd: true
            duration: Appearance.animation.scroll.duration
            easing.type: Appearance.animation.scroll.type
            easing.bezierCurve: Appearance.animation.scroll.bezierCurve
        }
    }

    // Keep target synced when not animating (e.g., drag/flick or programmatic changes)
    onContentYChanged: {
        if (!scrollAnim.running) {
            root.scrollTargetY = root.contentY;
        }
    }

    add: Transition {
        enabled: root.animateAppearance
        ParallelAnimation {
            // Slide Animation
            NumberAnimation {
                property: "x"
                from: root.dismissToLeft ? -((root.width < 100 ? Appearance.sizes.notificationPopupWidth : root.width) + root.removeOvershoot) : ((root.width < 100 ? Appearance.sizes.notificationPopupWidth : root.width) + root.removeOvershoot)
                to: 0
                duration: root.useSlideInAnimation ? Appearance.animation.elementMoveEnter.duration : 0
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
            // Fade Animation
            NumberAnimation {
                properties: root.popin ? "opacity,scale" : "opacity"
                from: !root.useSlideInAnimation ? 0 : 1
                to: 1
                duration: !root.useSlideInAnimation ? Appearance.animation.elementMoveEnter.duration : 0
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }
    }

    populate: Transition {
        enabled: root.animateAppearance
        ParallelAnimation {
            // Slide Animation
            NumberAnimation {
                property: "x"
                from: root.dismissToLeft ? -((root.width < 100 ? Appearance.sizes.notificationPopupWidth : root.width) + root.removeOvershoot) : ((root.width < 100 ? Appearance.sizes.notificationPopupWidth : root.width) + root.removeOvershoot)
                to: 0
                duration: root.useSlideInAnimation ? Appearance.animation.elementMoveEnter.duration : 0
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
            // Fade Animation
            NumberAnimation {
                properties: root.popin ? "opacity,scale" : "opacity"
                from: !root.useSlideInAnimation ? 0 : 1
                to: 1
                duration: !root.useSlideInAnimation ? Appearance.animation.elementMoveEnter.duration : 0
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }
    }

    addDisplaced: Transition {
        enabled: root.animateAppearance
        ParallelAnimation {
            NumberAnimation {
                property: "y"
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
            NumberAnimation {
                properties: root.popin ? "opacity,scale" : "opacity"
                to: 1
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
    }

    displaced: Transition {
        enabled: root.animateMovement
        ParallelAnimation {
            NumberAnimation {
                property: "y"
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
            NumberAnimation {
                properties: "opacity,scale"
                to: 1
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
    }

    move: Transition {
        enabled: root.animateMovement
        ParallelAnimation {
            NumberAnimation {
                property: "y"
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
            NumberAnimation {
                properties: "opacity,scale"
                to: 1
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
    }

    moveDisplaced: Transition {
        enabled: root.animateMovement
        ParallelAnimation {
            NumberAnimation {
                property: "y"
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
            NumberAnimation {
                properties: "opacity,scale"
                to: 1
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
    }

    remove: Transition {
        enabled: root.animateAppearance
        ParallelAnimation {
            // Slide Animation
            NumberAnimation {
                property: "x"
                to: root.dismissToLeft ? -((root.width < 100 ? Appearance.sizes.notificationPopupWidth : root.width) + root.removeOvershoot) : ((root.width < 100 ? Appearance.sizes.notificationPopupWidth : root.width) + root.removeOvershoot)
                duration: root.useSlideInAnimation ? Appearance.animation.elementMoveExit.duration : 0
                easing.type: Appearance.animation.elementMoveExit.type
                easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
            }
            // Fade Animation
            NumberAnimation {
                property: "opacity"
                to: !root.useSlideInAnimation ? 0.0 : 1.0
                duration: !root.useSlideInAnimation ? Appearance.animation.elementMoveExit.duration : 0
                easing.type: Appearance.animation.elementMoveExit.type
                easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
            }
        }
    }

    // This is movement when something is removed, not removing animation!
    removeDisplaced: Transition {
        enabled: root.animateAppearance
        ParallelAnimation {
            NumberAnimation {
                property: "y"
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
            NumberAnimation {
                properties: "opacity,scale"
                to: 1
                duration: Appearance.animation.elementMove.duration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
    }
}
