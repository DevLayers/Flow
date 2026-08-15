import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

PanelWindow {
    id: popupWindow
    required property ShellScreen screen
    color: "transparent"
    visible: true

    WlrLayershell.namespace: "quickshell:displayCast"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: GlobalStates.displayCastOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    // Position: anchored to top+right for horizontal bar, adapting to bar config
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
            if (Config.options.bar.vertical)
                return topFrameThickness + 8;
            return (Config.options.bar.bottom ? 0 : Appearance.sizes.barHeight) + topFrameThickness + 8;
        }
        bottom: {
            if (Config.options.bar.vertical)
                return bottomFrameThickness + 8;
            return (Config.options.bar.bottom ? Appearance.sizes.barHeight : 0) + bottomFrameThickness + 8;
        }
        left: {
            if (Config.options.bar.vertical)
                return (Config.options.bar.bottom ? leftFrameThickness : Appearance.sizes.verticalBarWindowWidth + leftFrameThickness) + 8;
            return leftFrameThickness + 8;
        }
        right: {
            if (Config.options.bar.vertical)
                return (Config.options.bar.bottom ? Appearance.sizes.verticalBarWindowWidth + rightFrameThickness : rightFrameThickness) + 8;
            return barGaps + 8 + rightFrameThickness;
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

    Item {
        focus: true
        Keys.onEscapePressed: GlobalStates.closeDisplayCast()
    }

    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked)
                GlobalStates.closeDisplayCast();
        }
        function onSettingsOpenChanged() {
            if (GlobalStates.settingsOpen)
                GlobalStates.closeDisplayCast();
        }
    }
}
