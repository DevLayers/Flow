import QtQuick
import QtQuick.Effects
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
}
