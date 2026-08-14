import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var screen: null

    property bool active: false
    property string origin: ""
    property string actionId: ""
    property real gestureProgress: 0
    property real travel: 0
    property real startX: 0
    property real startY: 0
    property bool isCommitted: false

    readonly property var actionObj: TouchGestureActionRegistry.actionById(actionId)

    Connections {
        target: TouchGestureService

        function onGestureStarted(screenName, orig, actId, x, y) {
            var myScreenName = root.screen ? root.screen.name : "";
            if (screenName !== myScreenName) return;
            root.origin = orig;
            root.actionId = actId;
            root.startX = x;
            root.startY = y;
            root.gestureProgress = 0;
            root.travel = 0;
            root.isCommitted = false;
            root.active = true;
            fadeTimer.stop();
        }

        function onGestureProgressChanged(screenName, orig, actId, prog, trav) {
            var myScreenName = root.screen ? root.screen.name : "";
            if (screenName !== myScreenName) return;
            root.gestureProgress = prog;
            root.travel = trav;
        }

        function onGestureCancelled(screenName, orig, actId) {
            var myScreenName = root.screen ? root.screen.name : "";
            if (screenName !== myScreenName) return;
            root.gestureProgress = 0;
            fadeTimer.restart();
        }

        function onGestureCommitted(screenName, orig, actId) {
            var myScreenName = root.screen ? root.screen.name : "";
            if (screenName !== myScreenName) return;
            root.isCommitted = true;
            root.gestureProgress = 1.0;
            fadeTimer.restart();
        }
    }

    Timer {
        id: fadeTimer
        interval: 220
        repeat: false
        onTriggered: {
            root.active = false;
            root.isCommitted = false;
        }
    }

    // ── CALIBRATION OVERLAY (Active when holding settings sliders) ───────────
    Item {
        id: calibrationOverlay
        anchors.fill: parent
        visible: TouchGestureService.calibrating
        opacity: TouchGestureService.calibrating ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        readonly property string mode: TouchGestureService.calibrationMode
        readonly property real calVal: TouchGestureService.calibrationValue

        // Edge detection bands
        Rectangle {
            visible: calibrationOverlay.mode === "edgeWidth" || calibrationOverlay.mode === "commitDistance" || calibrationOverlay.mode === "minDistance"
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: calibrationOverlay.mode === "edgeWidth" ? calibrationOverlay.calVal : 24
            color: Appearance.colors.colPrimary
            opacity: 0.28
            border.width: 1
            border.color: Appearance.colors.colPrimary
        }

        Rectangle {
            visible: calibrationOverlay.mode === "edgeWidth" || calibrationOverlay.mode === "commitDistance" || calibrationOverlay.mode === "minDistance"
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: calibrationOverlay.mode === "edgeWidth" ? calibrationOverlay.calVal : 24
            color: Appearance.colors.colPrimary
            opacity: 0.28
            border.width: 1
            border.color: Appearance.colors.colPrimary
        }

        Rectangle {
            visible: calibrationOverlay.mode === "edgeWidth" || calibrationOverlay.mode === "commitDistance" || calibrationOverlay.mode === "minDistance"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: calibrationOverlay.mode === "edgeWidth" ? calibrationOverlay.calVal : 24
            color: Appearance.colors.colPrimary
            opacity: 0.28
            border.width: 1
            border.color: Appearance.colors.colPrimary
        }

        Rectangle {
            visible: calibrationOverlay.mode === "edgeWidth" || calibrationOverlay.mode === "commitDistance" || calibrationOverlay.mode === "minDistance"
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: calibrationOverlay.mode === "edgeWidth" ? calibrationOverlay.calVal : 24
            color: Appearance.colors.colPrimary
            opacity: 0.28
            border.width: 1
            border.color: Appearance.colors.colPrimary
        }

        // Corner detection boxes
        Rectangle {
            visible: calibrationOverlay.mode === "cornerSize"
            anchors.left: parent.left
            anchors.top: parent.top
            width: calibrationOverlay.calVal
            height: calibrationOverlay.calVal
            color: Appearance.colors.colPrimary
            opacity: 0.32
            border.width: 2
            border.color: Appearance.colors.colPrimary
            radius: 8
        }

        Rectangle {
            visible: calibrationOverlay.mode === "cornerSize"
            anchors.right: parent.right
            anchors.top: parent.top
            width: calibrationOverlay.calVal
            height: calibrationOverlay.calVal
            color: Appearance.colors.colPrimary
            opacity: 0.32
            border.width: 2
            border.color: Appearance.colors.colPrimary
            radius: 8
        }

        Rectangle {
            visible: calibrationOverlay.mode === "cornerSize"
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: calibrationOverlay.calVal
            height: calibrationOverlay.calVal
            color: Appearance.colors.colPrimary
            opacity: 0.32
            border.width: 2
            border.color: Appearance.colors.colPrimary
            radius: 8
        }

        Rectangle {
            visible: calibrationOverlay.mode === "cornerSize"
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: calibrationOverlay.calVal
            height: calibrationOverlay.calVal
            color: Appearance.colors.colPrimary
            opacity: 0.32
            border.width: 2
            border.color: Appearance.colors.colPrimary
            radius: 8
        }

        // Commit Distance / Min Travel distance guidelines
        Rectangle {
            visible: calibrationOverlay.mode === "commitDistance" || calibrationOverlay.mode === "minDistance"
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: calibrationOverlay.calVal
            color: "transparent"
            border.width: 2
            border.color: Appearance.colors.colPrimary
            opacity: 0.8
        }

        // Center Measurement HUD Badge
        Rectangle {
            anchors.centerIn: parent
            width: calHudLayout.implicitWidth + 32
            height: calHudLayout.implicitHeight + 20
            radius: Appearance.rounding.full
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colPrimary

            RowLayout {
                id: calHudLayout
                anchors.centerIn: parent
                spacing: 10

                MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.large
                    text: calibrationOverlay.mode === "edgeWidth" ? "border_left"
                        : calibrationOverlay.mode === "cornerSize" ? "crop_square"
                        : calibrationOverlay.mode === "commitDistance" ? "check"
                        : calibrationOverlay.mode === "minDistance" ? "linear_scale"
                        : "tune"
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    text: {
                        var val = Math.round(calibrationOverlay.calVal);
                        if (calibrationOverlay.mode === "edgeWidth") {
                            return Translation.tr("Edge Zone") + ": " + val + " px";
                        } else if (calibrationOverlay.mode === "cornerSize") {
                            return Translation.tr("Corner Zone") + ": " + val + " px";
                        } else if (calibrationOverlay.mode === "commitDistance") {
                            return Translation.tr("Activation Travel") + ": " + val + " px";
                        } else if (calibrationOverlay.mode === "minDistance") {
                            return Translation.tr("Min Travel") + ": " + val + " px";
                        }
                        return val + " px";
                    }
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
            }
        }
    }

    // ── GESTURE INTERACTION CONTAINER ────────────────────────────────────────
    Item {
        id: indicatorContainer
        anchors.fill: parent
        opacity: root.active ? (0.35 + root.gestureProgress * 0.65) : 0.0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        // Indicator Card
        Rectangle {
            id: indicatorCard

            readonly property real maxOffset: 52
            readonly property real currentOffset: Math.min(maxOffset, root.gestureProgress * maxOffset)
            readonly property bool readyToCommit: root.gestureProgress >= 0.95 || root.isCommitted

            width: contentLayout.implicitWidth + 24
            height: contentLayout.implicitHeight + 16
            radius: Appearance.rounding.full

            color: readyToCommit
                ? Appearance.m3colors.m3primary
                : Appearance.colors.colLayer2

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            scale: 0.85 + root.gestureProgress * 0.15

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                }
            }

            // Placement logic
            x: {
                switch (root.origin) {
                case "leftEdge":
                    return currentOffset + 12;
                case "rightEdge":
                    return root.width - width - currentOffset - 12;
                case "topLeftCorner":
                case "bottomLeftCorner":
                    return currentOffset + 16;
                case "topRightCorner":
                case "bottomRightCorner":
                    return root.width - width - currentOffset - 16;
                case "topEdge":
                case "bottomEdge":
                default:
                    return Math.max(16, Math.min(root.width - width - 16, root.startX - width / 2));
                }
            }

            y: {
                switch (root.origin) {
                case "topEdge":
                    return currentOffset + 12;
                case "bottomEdge":
                    return root.height - height - currentOffset - 12;
                case "topLeftCorner":
                case "topRightCorner":
                    return currentOffset + 16;
                case "bottomLeftCorner":
                case "bottomRightCorner":
                    return root.height - height - currentOffset - 16;
                case "leftEdge":
                case "rightEdge":
                default:
                    return Math.max(16, Math.min(root.height - height - 16, root.startY - height / 2));
                }
            }

            RowLayout {
                id: contentLayout
                anchors.centerIn: parent
                spacing: 8

                MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.large
                    text: (root.actionObj && root.actionObj.icon) ? root.actionObj.icon : "touch_app"
                    color: indicatorCard.readyToCommit
                        ? Appearance.m3colors.m3onPrimary
                        : Appearance.colors.colOnLayer2
                }

                StyledText {
                    text: Translation.tr((root.actionObj && root.actionObj.name) ? root.actionObj.name : "")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: indicatorCard.readyToCommit
                        ? Appearance.m3colors.m3onPrimary
                        : Appearance.colors.colOnLayer2
                }
            }
        }
    }
}
