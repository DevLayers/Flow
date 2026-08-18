import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common

PanelWindow {
    id: blurOverlayWindow

    required property var modelData
    screen: modelData

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:workspaceBlurOverlay"
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        item: overlayDimRect
    }

    readonly property bool animEnabled: Config.options.background.zoomOutEnabled
    readonly property bool isMirroredStyle: Config.options.background.zoomOutStyle === 1
    readonly property bool isActive: animEnabled && isMirroredStyle && (GlobalStates.cheatsheetOpen || GlobalStates.overviewOpen) && ((Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "") == (Hyprland.monitorFor(modelData) ? Hyprland.monitorFor(modelData).name : ""))

    visible: isActive || overlayDimRect.opacity > 0.01

    Rectangle {
        id: overlayDimRect
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.25)
        opacity: blurOverlayWindow.isActive ? 1.0 : 0.0
        radius: 0

        Behavior on opacity {
            NumberAnimation {
                duration: blurOverlayWindow.isActive ? Appearance.animation.elementMoveEnter.duration : Appearance.animation.elementMoveExit.duration
                easing.type: blurOverlayWindow.isActive ? Appearance.animation.elementMoveEnter.type : Appearance.animation.elementMoveExit.type
                easing.bezierCurve: blurOverlayWindow.isActive ? Appearance.animation.elementMoveEnter.bezierCurve : Appearance.animation.elementMoveExit.bezierCurve
            }
        }
    }
}
