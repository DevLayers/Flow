import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    // Listen for new connections
    Connections {
        target: BluetoothStatus
        function onDeviceConnected(device) {
            if (Config.options.bar.tooltips.enablePopups && Config.options.bar.tooltips.enableBluetoothConnectionPopup) {
                GlobalStates.bluetoothConnectionPopupDevice = device;
                GlobalStates.bluetoothConnectionPopupOpen = true;
            }
        }
    }

    // Listen for disconnections to close the popup if the shown device disconnects
    Connections {
        target: BluetoothStatus
        function onDeviceDisconnected(device) {
            if (GlobalStates.bluetoothConnectionPopupDevice &&
                GlobalStates.bluetoothConnectionPopupDevice.address === device.address) {
                GlobalStates.bluetoothConnectionPopupOpen = false;
            }
        }
    }

    Connections {
        target: Config.options.bar.tooltips
        function onEnablePopupsChanged() {
            if (!Config.options.bar.tooltips.enablePopups)
                GlobalStates.bluetoothConnectionPopupOpen = false;
        }
        function onEnableBluetoothConnectionPopupChanged() {
            if (!Config.options.bar.tooltips.enableBluetoothConnectionPopup)
                GlobalStates.bluetoothConnectionPopupOpen = false;
        }
    }

    // The popup anchors like the bar popups (right side for horizontal bars,
    // or the bar's own edge for vertical bars). Dismiss it only when the sidebar
    // on the SAME side as the popup opens over it — never the opposite-side
    // sidebar, never the overview (effectiveLeft/RightOpen reflect only real
    // sidebars per Config.options.sidebar.position).
    readonly property bool popupOnLeftSide: Config.options.bar.vertical && !Config.options.bar.bottom
    readonly property bool popupOnRightSide: !Config.options.bar.vertical || Config.options.bar.bottom
    readonly property bool sidebarOccludesPopup: (popupOnLeftSide && GlobalStates.effectiveLeftOpen)
            || (popupOnRightSide && GlobalStates.effectiveRightOpen)

    // Dismiss popup when the same-side sidebar opens (avoids input conflicts)
    Connections {
        target: root
        function onSidebarOccludesPopupChanged() {
            if (root.sidebarOccludesPopup) {
                GlobalStates.bluetoothConnectionPopupOpen = false;
            }
        }
    }

    LazyLoader {
        id: popupLoader
        active: GlobalStates.bluetoothConnectionPopupOpen
            && Config.options.bar.tooltips.enablePopups
            && Config.options.bar.tooltips.enableBluetoothConnectionPopup

        component: PanelWindow {
            id: popupWindow
            color: "transparent"
            visible: Config.options.bar.tooltips.enablePopups
                && Config.options.bar.tooltips.enableBluetoothConnectionPopup
            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

            readonly property real screenWidth: popupWindow.screen?.width ?? 0
            readonly property real screenHeight: popupWindow.screen?.height ?? 0

            WlrLayershell.namespace: "quickshell:bluetoothConnectionPopup"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            // Position: anchored to top+right for horizontal bar (like other bar popups)
            anchors {
                top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
                bottom: !Config.options.bar.vertical && Config.options.bar.bottom
                left: Config.options.bar.vertical && !Config.options.bar.bottom
                right: (!Config.options.bar.vertical) || (Config.options.bar.vertical && Config.options.bar.bottom)
            }

            readonly property int frameThickness: Config.options.appearance.fakeScreenRounding === 3 ? Config.options.appearance.wrappedFrameThickness : 0
            readonly property int topFrameThickness: (Config.options.bar.vertical || Config.options.bar.bottom) ? frameThickness : 0
            readonly property int bottomFrameThickness: (Config.options.bar.vertical || !Config.options.bar.bottom) ? frameThickness : 0
            readonly property int leftFrameThickness: (!Config.options.bar.vertical || Config.options.bar.bottom) ? frameThickness : 0
            readonly property int rightFrameThickness: (!Config.options.bar.vertical || !Config.options.bar.bottom) ? frameThickness : 0
            readonly property int barGaps: (Config.options.bar.cornerStyle !== 0) ? Appearance.sizes.hyprlandGapsOut : 0

            margins {
                top: {
                    if (Config.options.bar.vertical) {
                        return topFrameThickness;
                    }
                    return Config.options.bar.bottom ? 0 : Appearance.sizes.barHeight + topFrameThickness;
                }
                bottom: {
                    if (Config.options.bar.vertical) {
                        return bottomFrameThickness;
                    }
                    return Config.options.bar.bottom ? Appearance.sizes.barHeight + bottomFrameThickness : 0;
                }
                left: {
                    if (Config.options.bar.vertical) {
                        return Config.options.bar.bottom ? leftFrameThickness : Appearance.sizes.verticalBarWindowWidth + leftFrameThickness;
                    }
                    return leftFrameThickness;
                }
                right: {
                    if (Config.options.bar.vertical) {
                        return Config.options.bar.bottom ? Appearance.sizes.verticalBarWindowWidth + rightFrameThickness : rightFrameThickness;
                    }
                    return barGaps + 4 + rightFrameThickness;
                }
            }

            implicitWidth: popupContent.implicitWidth
            implicitHeight: popupContent.implicitHeight

            mask: Region {
                item: popupContent.staticMaskTarget
            }

            BluetoothConnectionPopupContent {
                id: popupContent
                device: GlobalStates.bluetoothConnectionPopupDevice

                onDismissed: {
                    GlobalStates.bluetoothConnectionPopupOpen = false;
                }
                onDisconnectRequested: {
                    if (GlobalStates.bluetoothConnectionPopupDevice) {
                        GlobalStates.bluetoothConnectionPopupDevice.connecting = false;
                        GlobalStates.bluetoothConnectionPopupDevice.connected = false;
                    }
                    GlobalStates.bluetoothConnectionPopupOpen = false;
                }
            }
        }
    }
}
