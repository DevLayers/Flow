import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.services
import qs.modules.common
import qs.modules.common.functions

/**
 * The full-screen surface the tablet notification shade is pulled down onto.
 *
 * A layer-shell namespace is fixed the moment the surface is created and it is what decides
 * whether Hyprland blurs behind the shade, so it can never be a live binding: the owner
 * instantiates one of two Components, each carrying a constant namespace, and throws the
 * window away when the transparency setting flips.
 */
PanelWindow {
    id: root

    required property string shellNamespace
    required property bool blurBacked

    readonly property real progress: TabletDashboardGestureController.progress
    readonly property string screenName: root.screen?.name ?? ""

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: root.shellNamespace
    WlrLayershell.layer: WlrLayer.Overlay

    // Keyboard focus: only after the shade has completely settled open
    WlrLayershell.keyboardFocus: TabletDashboardGestureController.isSettledOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // When open or dragging the entire window is interactive; when closed only the top edge
    // is, so everything else passes through to the desktop.
    mask: Region {
        item: (root.progress > 0.001 || topMouseDragArea.pressed || TabletDashboardGestureController.tracking) ? contentWrapper : topEdgeCaptureStrip
    }

    // Always mapped so the top edge is ready to be pulled down at any time
    visible: true

    Connections {
        target: TabletDashboardGestureController
        function onIsSettledOpenChanged() {
            if (TabletDashboardGestureController.isSettledOpen && root.visible) {
                GlobalFocusGrab.addDismissable(root);
            } else {
                GlobalFocusGrab.removeDismissable(root);
            }
        }
    }

    Component.onDestruction: GlobalFocusGrab.removeDismissable(root)

    Connections {
        target: GlobalFocusGrab
        function onDismissed() {
            TabletDashboardGestureController.close();
        }
    }

    Item {
        id: contentWrapper
        anchors.fill: parent
        focus: TabletDashboardGestureController.isSettledOpen

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                TabletDashboardGestureController.close();
            }
        }

        // ── SCRIM / FROSTED SHEET ────────────────────────────────────────────
        // Hyprland's layer blur is a *region*, masked by this surface's own alpha (the
        // `ignore_alpha` layer rule) — not an intensity it can ramp. A scrim covering the
        // whole screen would therefore snap the entire desktop to blurred the instant the
        // shade is touched. Instead the sheet is only painted down to where the shade
        // currently ends, so the frosted area is revealed together with the panel, with
        // rounded corners on its leading edge that square off as it locks fully open.
        // Without transparency there is no blur to reveal, so the overlay colour just fades
        // in across the screen as before.
        Rectangle {
            id: scrim
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: root.blurBacked ? Math.round(parent.height * root.progress) : parent.height
            visible: root.progress > 0.001

            // Layer 0: the shade drops the card that used to sit behind the quick toggles, so the
            // tiles (layer 2) and the notification card (layer 1) now stack straight onto this.
            // A surfaceContainer background would be the exact colour of an untoggled tile.
            color: root.blurBacked ? ColorUtils.transparentize(Appearance.colors.colScrim, 1.0 - root.progress) : Appearance.colors.colLayer0
            opacity: root.blurBacked ? 1.0 : root.progress

            readonly property real leadingEdgeRadius: root.blurBacked ? Appearance.rounding.verylarge * Math.max(0, Math.min(1, (1.0 - root.progress) * 4)) : 0
            bottomLeftRadius: leadingEdgeRadius
            bottomRightRadius: leadingEdgeRadius

            MouseArea {
                anchors.fill: parent
                enabled: TabletDashboardGestureController.isSettledOpen
                onClicked: TabletDashboardGestureController.close()
            }
        }

        // Sliding surface (follows finger/progress directly 1:1)
        Item {
            id: slidingSurface
            anchors.fill: parent
            visible: root.progress > 0.001
            transform: Translate {
                y: -root.height * (1.0 - root.progress)
            }

            TabletDashboardContent {
                anchors.fill: parent
                onDismissRequested: TabletDashboardGestureController.close()
            }
        }

        // ── TOP EDGE CAPTURE STRIP (independent from the bar) ────────────────
        // The top edge captures click-and-drag down from mouse, touch or tablet stylus
        Item {
            id: topEdgeCaptureStrip
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: 32
            z: 9999

            MouseArea {
                id: topMouseDragArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: TabletDashboardGestureController.isSettledOpen ? Qt.ArrowCursor : Qt.PointingHandCursor
                preventStealing: true

                property real startY: 0
                property real lastY: 0
                property real lastTime: 0
                property real calculatedVelocity: 0
                property bool isTracking: false

                onPressed: mouse => {
                    if (TabletDashboardGestureController.isSettledOpen) return;
                    startY = mouse.y;
                    lastY = mouse.y;
                    lastTime = Date.now();
                    calculatedVelocity = 0;
                    isTracking = true;
                    TabletDashboardGestureController.startTracking(root.screenName);
                }

                onPositionChanged: mouse => {
                    if (!isTracking) return;
                    const now = Date.now();
                    const dt = Math.max(1, now - lastTime);
                    calculatedVelocity = ((mouse.y - lastY) / dt) * 1000.0;
                    lastY = mouse.y;
                    lastTime = now;

                    const deltaY = mouse.y - startY;
                    const targetDist = root.height * 0.55;
                    const p = Math.max(0.0, Math.min(1.0, deltaY / Math.max(1, targetDist)));
                    TabletDashboardGestureController.updateProgress(p, calculatedVelocity);
                }

                onReleased: mouse => {
                    if (!isTracking) return;
                    isTracking = false;
                    TabletDashboardGestureController.endTracking(calculatedVelocity);
                }

                onCanceled: {
                    if (isTracking) {
                        isTracking = false;
                        TabletDashboardGestureController.cancelTracking();
                    }
                }
            }
        }
    }
}
