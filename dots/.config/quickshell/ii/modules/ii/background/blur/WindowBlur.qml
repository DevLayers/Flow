import QtQuick
import QtQuick.Effects
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions as CF

Item {
    id: windowBlurRoot

    required property var sourceItem
    required property bool hasWindowsInActiveWorkspace
    required property bool overviewOpen
    required property real overviewProgress

    // Keep the window blur disabled for the whole Overview transition. The
    // controller continues animating after overviewOpen becomes false, so
    // recreating the blur before progress reaches zero captures a stale frame
    // with the Overview's dim/saturation still applied.
    readonly property bool overviewTransitionActive: overviewOpen || overviewProgress > 0.001
    readonly property bool shouldBlur: Config.options.background.blurWhenWindowsOpen
        && hasWindowsInActiveWorkspace && !GlobalStates.screenLocked && !overviewTransitionActive

    // Keep the Loader binding intact while still allowing a fresh grab after
    // Overview changes the wallpaper composition underneath the blur.
    property bool reloadRequested: false
    readonly property bool desiredBlurActive: shouldBlur && !reloadRequested

    function refreshBlur() {
        if (!desiredBlurActive)
            return;
        reloadRequested = true;
        Qt.callLater(function() {
            windowBlurRoot.reloadRequested = false;
        });
    }

    // The Loader below activates the instant shouldBlur flips true, which can be before
    // sourceItem's layout has settled (e.g. right as a window opens). MultiEffect's implicit
    // ShaderEffectSource grabs sourceItem at whatever size it has *at that moment*, then
    // stretches that texture to fill the final geometry once layout catches up — producing a
    // squashed/stretched wallpaper. Force a rebuild shortly after activation so it re-grabs
    // once layout has settled, instead of only reacting to workspace switches.
    onShouldBlurChanged: if (shouldBlur) refreshBlur();
    onOverviewOpenChanged: if (!overviewOpen) refreshBlur();
    onOverviewProgressChanged: if (!overviewOpen && overviewProgress <= 0.001) refreshBlur();

    // Unmap the effect immediately while Overview is open or closing. Waiting
    // for the shared progress clock avoids exposing a stale blurred frame.
    visible: windowBlurRoot.desiredBlurActive
    opacity: windowBlurRoot.desiredBlurActive ? 1.0 : 0.0
    Behavior on opacity {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    // GPU: Loader only instantiates the expensive MultiEffect when blur is actually needed.
    // Previously the MultiEffect (blurMax:64 shader + texture allocation) was always resident
    // in the scene graph even when source was null at idle.
    Loader {
        id: blurEffectLoader
        anchors.fill: parent
        active: windowBlurRoot.desiredBlurActive
        sourceComponent: MultiEffect {
            anchors.fill: parent
            source: windowBlurRoot.sourceItem
            blurEnabled: true
            blurMax: 64
            blur: Config.options.background.blurWhenWindowsOpenRadius / 100.0

            Rectangle {
                anchors.fill: parent
                color: CF.ColorUtils.transparentize(Appearance.colors.colLayer0, 0.4)
            }
        }
    }

    // Also rebuild on workspace switches: layout can shift again later (monitor/workspace
    // changes), and the live grab stops requesting new frames once things settle, so it can
    // still end up stuck on a stale frame well after the initial activation.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "workspace" || event.name === "workspacev2" || event.name === "focusedmon")
                blurRefreshTimer.restart();
        }
    }

    Timer {
        id: blurRefreshTimer
        interval: 100
        repeat: false
        onTriggered: {
            windowBlurRoot.refreshBlur();
        }
    }
}
