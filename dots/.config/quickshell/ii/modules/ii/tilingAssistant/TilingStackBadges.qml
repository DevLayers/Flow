pragma ComponentBehavior: Bound

/**
 * Marker for zones holding more than one window, shown while nothing is being
 * dragged.
 *
 * Two windows in one zone is a perfectly legal thing to ask for, but the second
 * one covers the first and the zone then looks exactly like a zone with one
 * window in it. The overlay says so during a drag; this says so the rest of the
 * time, drawing nothing at all for the zones that hold zero or one window.
 *
 * Click-through, one layer surface per monitor, and only alive while that
 * monitor actually has a crowded zone - there is no reason to hold a surface
 * open for a screen with nothing to report.
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
            readonly property var crowded: TilingAssistant.crowdedZonesFor(monitorScope.screenName)
            // Nothing of ours goes over a fullscreen window, and a zone marker
            // is the last thing that should.
            readonly property bool shown: monitorScope.crowded.length > 0 && !TilingAssistant.monitorHasFullscreen(monitorScope.screenName)

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
                    screen: monitorScope.modelData
                    WlrLayershell.namespace: "quickshell:tiling_stack_badges"
                    // Above the windows it is describing, below the overlay the
                    // drag puts up - and below the bar, which owns that strip.
                    WlrLayershell.layer: WlrLayer.Top
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                    // Ignoring exclusive zones keeps the surface aligned with the
                    // monitor origin, which is what the zone rects are relative to.
                    exclusionMode: ExclusionMode.Ignore
                    // Empty mask: the marker never takes a click meant for the
                    // window underneath it.
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
                            model: monitorScope.crowded

                            ZoneIndicator {
                                id: badge

                                required property var modelData

                                x: badge.modelData.x
                                y: badge.modelData.y
                                width: badge.modelData.width
                                height: badge.modelData.height
                                radius: root.overlayOptions?.cornerRadius ?? 12

                                // Outline and count only: filling the zone would
                                // wash out the windows it is drawn over, and it
                                // stays there as long as they are stacked.
                                label: ""
                                showLabel: false
                                baseOpacity: 0
                                hoveredOpacity: 0
                                hovered: false
                                animationDuration: root.fadeDuration
                                occupants: badge.modelData.occupants
                            }
                        }
                    }
                }
            }
        }
    }

}
