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

    // overviewOpen also flips true for the plain search bar (searchOnlyMode, or when the
    // window-thumbnail grid is disabled/replaced by config); only suppress the blur when
    // the grid of window thumbnails is actually what's covering the background.
    readonly property bool overviewGridVisible: overviewOpen && Config.options.overview.enable
        && !GlobalStates.searchOnlyMode && !Config.options.search.alwaysListApps
    readonly property bool shouldBlur: Config.options.background.blurWhenWindowsOpen
        && hasWindowsInActiveWorkspace && !GlobalStates.screenLocked && !overviewGridVisible

    // The Loader below activates the instant shouldBlur flips true, which can be before
    // sourceItem's layout has settled (e.g. right as a window opens). MultiEffect's implicit
    // ShaderEffectSource grabs sourceItem at whatever size it has *at that moment*, then
    // stretches that texture to fill the final geometry once layout catches up — producing a
    // squashed/stretched wallpaper. Force a rebuild shortly after activation so it re-grabs
    // once layout has settled, instead of only reacting to workspace switches.
    onShouldBlurChanged: if (shouldBlur) blurRefreshTimer.restart();

    // GPU: fade-out animation on the Item level so the Loader stays active
    // during the transition, then destroys the MultiEffect after fade completes.
    visible: windowBlurRoot.shouldBlur || opacity > 0.01
    opacity: windowBlurRoot.shouldBlur ? 1.0 : 0.0
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
        active: windowBlurRoot.shouldBlur || windowBlurRoot.opacity > 0.01
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
            if (!blurEffectLoader.active)
                return;
            blurEffectLoader.active = false;
            blurEffectLoader.active = true;
        }
    }
}
