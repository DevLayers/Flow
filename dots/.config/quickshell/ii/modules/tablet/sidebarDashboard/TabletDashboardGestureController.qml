pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common

Singleton {
    id: controller

    // ── Transient Runtime State ─────────────────────────────────────────────
    property real progress: 0.0          // 0.0 (closed) -> 1.0 (fully open)
    property bool tracking: false        // True while pointer/finger is actively dragging
    property real velocity: 0.0          // Vertical velocity in px/s
    property string activeScreenName: "" // Screen where the drag started

    // Velocity threshold for fling detection (px/s)
    readonly property real flingVelocityThreshold: 450.0
    // Position threshold when velocity is below fling threshold
    readonly property real positionThreshold: 0.40

    readonly property bool isSettledOpen: progress >= 0.999 && !tracking
    readonly property bool isSettledClosed: progress <= 0.001 && !tracking

    // Settle animation (only runs on release or programmatic open/close)
    NumberAnimation {
        id: settleAnimation
        target: controller
        property: "progress"
        easing.type: Easing.OutCubic
        duration: Math.round(280 * Appearance.animMultiplier)

        onFinished: {
            if (controller.progress >= 0.999) {
                controller.progress = 1.0;
                if (!GlobalStates.dashboardPanelOpen) {
                    GlobalStates.dashboardPanelOpen = true;
                }
            } else if (controller.progress <= 0.001) {
                controller.progress = 0.0;
                if (GlobalStates.dashboardPanelOpen) {
                    GlobalStates.dashboardPanelOpen = false;
                }
                controller.activeScreenName = "";
            }
        }
    }

    function startTracking(screenName) {
        settleAnimation.stop();
        controller.tracking = true;
        controller.activeScreenName = screenName || Hyprland.focusedMonitor?.name || "";
    }

    function updateProgress(newProgress, currentVelocity) {
        if (!controller.tracking) return;
        controller.progress = Math.max(0.0, Math.min(1.0, newProgress));
        if (currentVelocity !== undefined) {
            controller.velocity = currentVelocity;
        }
    }

    function endTracking(releaseVelocity) {
        if (!controller.tracking) return;
        controller.tracking = false;

        const v = (releaseVelocity !== undefined) ? releaseVelocity : controller.velocity;
        let shouldOpen = false;

        if (Math.abs(v) > flingVelocityThreshold) {
            // High velocity: fling direction decides
            shouldOpen = (v > 0);
        } else {
            // Low velocity: position threshold decides
            shouldOpen = (controller.progress > positionThreshold);
        }

        animateTo(shouldOpen ? 1.0 : 0.0);
    }

    function cancelTracking() {
        if (!controller.tracking) return;
        controller.tracking = false;
        animateTo(GlobalStates.dashboardPanelOpen ? 1.0 : 0.0);
    }

    function animateTo(targetProgress) {
        settleAnimation.stop();
        const dist = Math.abs(controller.progress - targetProgress);
        if (dist < 0.001) {
            controller.progress = targetProgress;
            if (targetProgress >= 0.999) {
                GlobalStates.dashboardPanelOpen = true;
            } else {
                GlobalStates.dashboardPanelOpen = false;
                controller.activeScreenName = "";
            }
            return;
        }
        settleAnimation.to = targetProgress;
        settleAnimation.duration = Math.max(140, Math.round(300 * dist * Appearance.animMultiplier));
        settleAnimation.start();
    }

    function toggle(screenName) {
        if (controller.progress > 0.5 || GlobalStates.dashboardPanelOpen) {
            close();
        } else {
            open(screenName);
        }
    }

    function open(screenName) {
        controller.activeScreenName = screenName || Hyprland.focusedMonitor?.name || "";
        animateTo(1.0);
    }

    function close() {
        animateTo(0.0);
    }

    // Bidirectional sync with GlobalStates.dashboardPanelOpen (for external IPC / Hotkeys / Bar button)
    Connections {
        target: GlobalStates
        function onDashboardPanelOpenChanged() {
            if (controller.tracking) return;
            if (GlobalStates.dashboardPanelOpen && controller.progress < 0.99) {
                controller.open();
            } else if (!GlobalStates.dashboardPanelOpen && controller.progress > 0.01) {
                controller.close();
            }
        }
    }
}
