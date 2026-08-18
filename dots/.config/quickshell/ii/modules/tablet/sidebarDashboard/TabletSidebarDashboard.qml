import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: root

    Variants {
        id: screenVariants
        model: Quickshell.screens

        delegate: LazyLoader {
            id: dashboardLoader
            required property ShellScreen modelData
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
            property int monitorIndex: Quickshell.screens.indexOf(modelData)
            property bool monitorIsFocused: (Hyprland.focusedMonitor?.name === monitor?.name) || (Hyprland.focusedMonitor?.id === monitorIndex)

            // Keep the PanelWindow always active so the top capture strip is mapped and ready to receive gestures
            active: true

            component: PanelWindow {
                id: panelWindow

                screen: dashboardLoader.modelData
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                readonly property bool transparencyEnabled: Config.options?.appearance?.transparency?.enable ?? false

                WlrLayershell.namespace: panelWindow.transparencyEnabled ? "quickshell:tabletDashboard" : "quickshell:tabletDashboardNoBlur"
                WlrLayershell.layer: WlrLayer.Overlay

                // Keyboard focus: only active after the dashboard has completely settled open
                WlrLayershell.keyboardFocus: TabletDashboardGestureController.isSettledOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

                // Mask:
                // When open or dragging: entire window is interactive
                // When closed (progress == 0): ONLY the top 32px edge is interactive, everything else passes through!
                mask: Region {
                    item: (TabletDashboardGestureController.progress > 0.001 || topMouseDragArea.pressed || TabletDashboardGestureController.tracking) ? contentWrapper : topEdgeCaptureStrip
                }

                // Window is always visible so the top edge is ready to be pulled down anytime
                visible: true

                Connections {
                    target: TabletDashboardGestureController
                    function onIsSettledOpenChanged() {
                        if (TabletDashboardGestureController.isSettledOpen && panelWindow.visible) {
                            GlobalFocusGrab.addDismissable(panelWindow);
                        } else {
                            GlobalFocusGrab.removeDismissable(panelWindow);
                        }
                    }
                }

                Component.onDestruction: GlobalFocusGrab.removeDismissable(panelWindow)

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

                    // Scrim / Background
                    // If transparency is enabled in Config: Progressive Hyprland-blurred dimmed background
                    // If transparency is disabled: Progressive solid neutral background (colBackgroundSurfaceContainer)
                    Rectangle {
                        id: scrim
                        anchors.fill: parent
                        visible: TabletDashboardGestureController.progress > 0.001

                        readonly property bool transparencyEnabled: Config.options?.appearance?.transparency?.enable ?? false

                        color: transparencyEnabled
                            ? Qt.rgba(0, 0, 0, 0.50 * TabletDashboardGestureController.progress)
                            : Appearance.colors.colBackgroundSurfaceContainer

                        opacity: transparencyEnabled
                            ? 1.0
                            : TabletDashboardGestureController.progress

                        MouseArea {
                            anchors.fill: parent
                            enabled: TabletDashboardGestureController.isSettledOpen
                            onClicked: TabletDashboardGestureController.close()
                        }
                    }

                    // Sliding Surface (follows finger/progress directly 1:1)
                    Item {
                        id: slidingSurface
                        anchors.fill: parent
                        visible: TabletDashboardGestureController.progress > 0.001
                        transform: Translate {
                            y: -panelWindow.height * (1.0 - TabletDashboardGestureController.progress)
                        }

                        TabletDashboardContent {
                            anchors.fill: parent
                            onDismissRequested: TabletDashboardGestureController.close()
                        }
                    }

                    // ── TOP EDGE CAPTURE STRIP (Independent from the bar) ────────
                    // Top 32px of the screen captures click-and-drag down from mouse, touch, or tablet stylus
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
                                TabletDashboardGestureController.startTracking(dashboardLoader.modelData?.name ?? "");
                            }

                            onPositionChanged: mouse => {
                                if (!isTracking) return;
                                const now = Date.now();
                                const dt = Math.max(1, now - lastTime);
                                calculatedVelocity = ((mouse.y - lastY) / dt) * 1000.0;
                                lastY = mouse.y;
                                lastTime = now;

                                const deltaY = mouse.y - startY;
                                const targetDist = panelWindow.height * 0.55;
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
        }
    }
}
