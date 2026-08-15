import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Scope {
    id: root

    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked) {
                GlobalStates.closeDisplayCast();
            }
        }
        function onSettingsOpenChanged() {
            if (GlobalStates.settingsOpen) {
                GlobalStates.closeDisplayCast();
            }
        }
    }

    LazyLoader {
        id: popupLoader
        active: GlobalStates.displayCastOpen

        component: PanelWindow {
            id: popupWindow
            color: "transparent"
            visible: Quickshell.screens.length > 0
            screen: Quickshell.screens.find(s => (Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name)) || Quickshell.screens[0] || null

            WlrLayershell.namespace: "quickshell:displayCast"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.displayCastOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            Component.onCompleted: {
                Qt.callLater(() => {
                    GlobalFocusGrab.addDismissable(popupWindow);
                });
            }

            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(popupWindow);
            }

            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    GlobalStates.closeDisplayCast();
                }
            }

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

            DisplayCastContent {
                id: popupContent
                onDismissRequested: GlobalStates.closeDisplayCast()
            }

            Shortcut {
                sequence: "Escape"
                onActivated: GlobalStates.closeDisplayCast()
            }
        }
    }
}
