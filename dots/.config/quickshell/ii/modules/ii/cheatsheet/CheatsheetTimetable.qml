import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import "timetable"

/**
 * Host for the two calendar shapes.
 *
 * Owns the plate both views sit on, and nothing else: the week grid and the
 * month grid are independent trees, and only the selected one exists. The
 * selector itself lives in the cheatsheet header, so this file never has to
 * know how the choice is made — it just follows the persisted state.
 */
Item {
    id: root

    property real maxContentWidth: 1600
    property real maxHeight: 700

    implicitWidth: root.maxContentWidth
    implicitHeight: root.maxHeight

    readonly property string requestedMode: Persistent.states.cheatsheet.timetableView === "month" ? "month" : "week"
    property string activeMode: root.requestedMode

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colSurfaceContainer
        radius: Appearance.rounding.large
    }

    // Fade out, swap, fade in. Keeping both trees alive for a cross-fade would
    // mean paying for a month grid while the week grid is on screen, and the
    // cheatsheet already releases its whole tab tree on close for that reason.
    onRequestedModeChanged: {
        if (root.requestedMode === root.activeMode)
            return;
        switchAnim.stop();
        switchAnim.start();
    }

    SequentialAnimation {
        id: switchAnim

        NumberAnimation {
            target: viewHost
            property: "switchProgress"
            to: 0
            duration: Appearance.animation.elementMoveExit.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
        }

        ScriptAction {
            script: root.activeMode = root.requestedMode
        }

        NumberAnimation {
            target: viewHost
            property: "switchProgress"
            to: 1
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
        }
    }

    Item {
        id: viewHost
        anchors.fill: parent
        anchors.margins: root.activeMode === "month" ? 16 : 0

        property real switchProgress: 1

        opacity: viewHost.switchProgress
        transform: Translate {
            // Month sits "further in" than week, so the swap reads as depth
            // rather than a sideways page flip.
            y: (1 - viewHost.switchProgress) * (root.activeMode === "month" ? 18 : -18)
        }

        Loader {
            anchors.fill: parent
            active: root.activeMode === "week"
            sourceComponent: WeekView {
                maxHeight: root.maxHeight
                maxContentWidth: root.maxContentWidth
            }
        }

        Loader {
            anchors.fill: parent
            active: root.activeMode === "month"
            sourceComponent: MonthView {
                showUpcoming: Persistent.states.cheatsheet.timetableShowUpcoming
            }
        }
    }
}
