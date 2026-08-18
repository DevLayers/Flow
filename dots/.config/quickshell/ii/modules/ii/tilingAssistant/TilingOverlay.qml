pragma ComponentBehavior: Bound

/**
 * Zone overlay shown while a window is being dragged, and for a moment after a
 * keyboard quick-tile, which has no drag to appear during.
 *
 * One click-through layer surface per monitor, each drawing the zones that
 * monitor is configured for, so a drag that crosses screens keeps showing the
 * right targets. Only the monitor under the cursor highlights a zone.
 *
 * The surface is created when a drag starts and torn down once the fade-out
 * finishes - there is no reason to hold a layer surface open the rest of the
 * time. Nothing is moved on drop yet; that comes with the apply phase.
 */

import qs
import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    readonly property var overlayOptions: Config.options?.tiling?.overlay ?? null
    readonly property int fadeDuration: root.overlayOptions?.fadeDuration ?? 150

    Variants {
        model: Quickshell.screens

        Scope {
            id: monitorScope

            required property var modelData
            readonly property string screenName: monitorScope.modelData?.name ?? ""
            readonly property bool shown: TilingAssistant.overlayVisible

            // Outlives `shown` so the surface is still there to fade out on.
            property bool surfaceAlive: false

            onShownChanged: {
                if (monitorScope.shown) {
                    fadeOutTimer.stop();
                    monitorScope.surfaceAlive = true;
                } else {
                    fadeOutTimer.restart();
                }
            }

            Timer {
                id: fadeOutTimer
                interval: root.fadeDuration + 50
                onTriggered: monitorScope.surfaceAlive = false
            }

            Loader {
                active: monitorScope.surfaceAlive

                sourceComponent: PanelWindow {
                    id: overlayWindow

                    screen: monitorScope.modelData
                    WlrLayershell.namespace: "quickshell:tiling_assistant"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                    // Ignoring exclusive zones keeps the surface aligned with the
                    // monitor origin, which is what the zone rects are relative to.
                    exclusionMode: ExclusionMode.Ignore
                    // Empty mask: every click goes through to the window being dragged.
                    mask: Region {}
                    color: "transparent"
                    visible: true

                    anchors {
                        top: true
                        bottom: true
                        left: true
                        right: true
                    }

                    Item {
                        id: content
                        anchors.fill: parent
                        opacity: 0

                        Component.onCompleted: content.opacity = Qt.binding(() => monitorScope.shown ? 1 : 0)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.fadeDuration
                                easing.type: Easing.OutCubic
                            }
                        }

                        Repeater {
                            model: TilingAssistant.overlayZonesFor(monitorScope.screenName)

                            ZoneIndicator {
                                id: indicator

                                required property var modelData
                                required property int index

                                x: indicator.modelData.x
                                y: indicator.modelData.y
                                width: indicator.modelData.width
                                height: indicator.modelData.height
                                radius: root.overlayOptions?.cornerRadius ?? 12

                                label: indicator.modelData.label
                                showLabel: root.overlayOptions?.showLabels ?? true
                                baseOpacity: root.overlayOptions?.zoneOpacity ?? 0.28
                                hoveredOpacity: root.overlayOptions?.hoveredOpacity ?? 0.55
                                animationDuration: root.fadeDuration
                                occupants: indicator.modelData.occupants
                                hovered: monitorScope.screenName === TilingAssistant.highlightMonitor && TilingAssistant.highlightZone === indicator.index
                            }
                        }
                    }
                }
            }
        }
    }
}
