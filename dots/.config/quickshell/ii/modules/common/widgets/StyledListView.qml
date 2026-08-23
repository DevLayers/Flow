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
    /**
     * The first fill of the list, separate from `animateAppearance` so a view
     * that already animates its own entrance can keep the per-row animation
     * for later additions without playing it over its own arrival.
     */
    property bool animatePopulate: true
    /**
     * Milliseconds between one row entering and the next, on the first fill
     * only. Zero — the default everywhere that has not asked for it — leaves
     * `populate` exactly as it was: every row entering at once.
     *
     * Only `populate` staggers. Delaying `add` would hold a row that arrived
     * on its own behind rows it has nothing to do with, which on a chat
     * transcript means an answer landing late for no reason.
     */
    property int staggerStep: 0
    /** Caps the wait for the last row of a long list. */
    property int staggerMaximum: 320
    property bool animateMovement: false
    property bool dismissToLeft: false
    property bool useSlideInAnimation: false

    // Accumulated scroll destination so wheel deltas stack while animating
    property real scrollTargetY: 0

    /**
     * The reader turned the wheel, and where that puts them. A list that moves
     * itself as well needs to tell the two apart, and this is the half nothing
     * else reports: a wheel scroll writes contentY directly, so it raises no
     * drag or flick of its own.
     */
    signal userScrolled(real targetY, real maxY)

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
    // Same reasoning as StyledFlickable: the scroll Behavior is for wheel
    // jumps, not for the contentY that dragging and flicking write per frame.
    property bool _wheelScrolling: false

    onHeightChanged: {
        root._suppressScrollAnim = true;
        resizeDebounce.restart();
    }

    onDraggingChanged: {
        if (root.dragging) {
            scrollAnim.stop();
            root._wheelScrolling = false;
        }
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

    // This must stay a pointer handler rather than an anchored MouseArea.
    // An item layered over the ListView wins cursor resolution from every
    // delegate below it, even with NoButton accepted.
    WheelHandler {
        enabled: root.interactive && root.contentHeight > root.height
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: wheelEvent => {
            const delta = wheelEvent.angleDelta.y / root.mouseScrollDeltaThreshold;
            // The angleDelta.y of a touchpad is usually small and continuous,
            // while that of a mouse wheel is typically in multiples of ±120.
            var scrollFactor = Math.abs(wheelEvent.angleDelta.y) >= root.mouseScrollDeltaThreshold ? root.mouseScrollFactor : root.touchpadScrollFactor;

            // Margins are part of the scrollable range: a list with a top
            // margin starts at -topMargin, not at 0. Clamping to 0 left the
            // first item permanently tucked under whatever the margin was
            // making room for.
            const minY = root.originY - root.topMargin;
            const maxY = Math.max(minY, root.originY + root.contentHeight - root.height + root.bottomMargin);
            const base = scrollAnim.running ? root.scrollTargetY : root.contentY;
            var targetY = Math.max(minY, Math.min(base - delta * scrollFactor, maxY));

            root.scrollTargetY = targetY;
            root._wheelScrolling = true;
            root.contentY = targetY;
            root.userScrolled(targetY, maxY);
            wheelEvent.accepted = true;
        }
    }

    Behavior on contentY {
        enabled: !root._suppressScrollAnim && root._wheelScrolling && !root.dragging && !root.flicking
        NumberAnimation {
            id: scrollAnim
            alwaysRunToEnd: true
            onStopped: root._wheelScrolling = false
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
        id: populateTransition
        enabled: root.animateAppearance && root.animatePopulate

        SequentialAnimation {
            // Each row waits its turn, so a page fills top-down instead of
            // appearing all at once. `ViewTransition.index` is the row's place
            // in the fill, which is the only thing a Transition knows about it.
            PauseAnimation {
                duration: root.staggerStep <= 0 ? 0
                    : Math.min(root.staggerMaximum, populateTransition.ViewTransition.index * root.staggerStep)
            }

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
                // A row that waits also rises into place: a pure fade at the
                // end of a delay reads as a dropped frame rather than as entry.
                NumberAnimation {
                    property: "y"
                    from: populateTransition.ViewTransition.destination.y
                        + (root.staggerStep > 0 ? Appearance.rounding.normal : 0)
                    to: populateTransition.ViewTransition.destination.y
                    duration: root.staggerStep > 0 ? Appearance.animation.elementMoveEnter.duration : 0
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
