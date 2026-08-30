import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.ii.editMode

/**
 * One screen's worth of Edit Mode's chrome: a full-screen layer surface that is
 * transparent everywhere except the toolbar on it.
 *
 * Why not on the background surface: the desktop stays where it is - the
 * wallpaper and the widget canvas are already there - but those surfaces are
 * on the Background and Bottom layers, under the bar and the dock, which stay
 * in place at full size. Chrome drawn there would sit under the bar. So the
 * chrome takes a surface of its own on Overlay, and the desktop does not move.
 *
 * Three things a surface this size has to get right:
 *
 * Input. A screen-sized surface that accepts input everywhere makes the
 * desktop underneath unclickable - and the desktop underneath is the thing
 * being edited. The mask is the toolbar and nothing else.
 *
 * Blur. rules.lua's catch-all blurs every `quickshell:*` surface with a low
 * alpha threshold, under which a screen of transparent pixels asks the
 * compositor to blur the whole screen. The namespace is minted AND listed there
 * at `ignore_alpha = 1`, so only the toolbar's opaque body is blurred.
 *
 * Keyboard. None, deliberately: Escape and the arrows are answered by the
 * WidgetCanvas on the widgets surface, and a chrome surface taking OnDemand
 * focus would sit in front of it and swallow the keys.
 */
PanelWindow {
    id: root

    // Whether something is summoned over the desktop this chrome frames - a
    // special workspace, today. Under it the chrome drops to the desktop's own
    // layer, so the compositor blurs and dims both halves of the mode together
    // instead of painting the toolbar over the window.
    property bool underneath: false

    color: "transparent"
    WlrLayershell.namespace: "quickshell:editMode"
    WlrLayershell.layer: root.underneath ? WlrLayer.Bottom : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    // All four edges and no margins, so this window's coordinate space is the
    // screen's. On a layer surface position IS margins, so a toolbar animating
    // into place through them would reconfigure the surface every frame; the
    // chrome moves inside the surface instead.
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    readonly property string screenName: root.screen ? root.screen.name : ""
    // The same pure function, on the same inputs, that the two desktop
    // surfaces build their transform out of - re-derived rather than published
    // across the window boundary, because every input is available here.
    readonly property var viewport: EditModeInsets.viewportFor(root.screenName, root.width, root.height)
    readonly property real progress: GlobalStates.editProgress
    readonly property var cardGeometry: EditModeLogic.cardRect(root.viewport, root.progress, root.width, root.height, 0)
    readonly property var areaGeometry: EditModeLogic.areaRect(root.viewport, root.progress, root.width, root.height)

    mask: Region {
        item: chrome.toolbarItem
    }

    EditModeChromeContent {
        id: chrome
        anchors.fill: parent
        card: Qt.rect(root.cardGeometry.x, root.cardGeometry.y, root.cardGeometry.width, root.cardGeometry.height)
        area: Qt.rect(root.areaGeometry.x, root.areaGeometry.y, root.areaGeometry.width, root.areaGeometry.height)
        bandFraction: EditModeLogic.chromeBandFraction(root.viewport)
        // The second stand-down gate, the loader that creates this window
        // being the first. Either alone hides the chrome; both are kept so a
        // lost gate is not a lost chrome.
        opacity: Math.max(0, Math.min(1, root.progress))

        onDoneRequested: GlobalStates.editMode = false
        // A preference, not a layout edit: no history entry, same as the
        // Settings toggle that writes the same key.
        onSnapToggleRequested: Config.options.background.widgets.enableSnap = !Config.options.background.widgets.enableSnap
    }
}
