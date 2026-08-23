import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import "timetable"

/**
 * Host for the timetable calendar shapes.
 *
 * Owns the plate both views sit on, and nothing else: the week grid and the
 * month grid are independent trees, and only the selected one exists. The
 * selector itself lives in the cheatsheet header, so this file never has to
 * know how the choice is made — it just follows the persisted state.
 */
Item {
    id: root

    focus: true

    property real maxContentWidth: 1600
    property real maxHeight: 700

    implicitWidth: root.maxContentWidth
    implicitHeight: root.maxHeight

    readonly property var supportedModes: ["day", "threeDay", "week", "month"]
    readonly property string requestedMode: root.supportedModes.includes(Persistent.states.cheatsheet.timetableView)
        ? Persistent.states.cheatsheet.timetableView
        : "week"
    property string activeMode: root.requestedMode
    property bool sportsSubscriberAcquired: false
    property bool sportsReady: false
    readonly property var activeViewItem: root.activeMode === "month" ? monthViewLoader.item : weekViewLoader.item
    readonly property bool activeViewReady: root.activeViewItem?.initialLoadComplete ?? false

    Keys.priority: Keys.AfterItem
    Keys.onPressed: event => {
        if (!root.activeViewItem || typeof root.activeViewItem.handleNavigationKey !== "function")
            return;
        event.accepted = root.activeViewItem.handleNavigationKey(event);
    }

    function openRequestedDate() {
        if (GlobalStates.timetableNavigationRequest <= 0)
            return;
        // Opening a concrete date uses the month grid, where the selected day
        // and its event rail are visible together. This is an explicit action,
        // so persisting the mode also keeps the header selector truthful.
        if (Persistent.states.cheatsheet.timetableView !== "month")
            Persistent.states.cheatsheet.timetableView = "month";
    }

    Component.onCompleted: root.openRequestedDate()

    Connections {
        target: GlobalStates
        function onTimetableNavigationRequestChanged() {
            root.openRequestedDate();
        }
    }

    onActiveViewReadyChanged: {
        if (root.activeViewReady && !root.sportsSubscriberAcquired)
            sportsActivationTimer.restart();
    }

    Timer {
        id: sportsActivationTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (!root.activeViewReady || root.sportsSubscriberAcquired)
                return;
            SportsService.acquireTimetableSubscriber();
            root.sportsSubscriberAcquired = true;
            root.sportsReady = true;
        }
    }

    Component.onDestruction: {
        sportsActivationTimer.stop();
        if (root.sportsSubscriberAcquired)
            SportsService.releaseTimetableSubscriber();
    }

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
            id: weekViewLoader
            anchors.fill: parent
            active: root.activeMode !== "month"
            asynchronous: true
            sourceComponent: WeekView {
                maxHeight: root.maxHeight
                maxContentWidth: root.maxContentWidth
                sportsEnabled: root.sportsReady
                viewMode: root.activeMode
            }
        }

        Loader {
            id: monthViewLoader
            anchors.fill: parent
            active: root.activeMode === "month"
            asynchronous: true
            sourceComponent: MonthView {
                showUpcoming: Persistent.states.cheatsheet.timetableShowUpcoming
                sportsEnabled: root.sportsReady
            }
        }
    }
}
