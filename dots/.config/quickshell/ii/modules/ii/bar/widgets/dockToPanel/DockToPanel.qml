import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland

Item {
    id: root

    property real iconSize:      Config.options.dockToPanel.iconSize
    property real btnSize:       iconSize + 5
    property real btnSpacing:    Config.options.dockToPanel.buttonSpacing
    property bool vertical:    Config.options.bar.vertical
    property bool isMaterial:  Config.options.bar.cornerStyle === 3
    property var pinnedApps: Config.options?.dock.pinnedApps ?? []

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
    readonly property int activeWsId: monitor?.activeWorkspace?.id ?? 1
    readonly property bool alignToWorkspace: Config.options?.dockToPanel?.alignToWorkspace ?? false
    readonly property bool enableWorkspaceScroll: Config.options?.dockToPanel?.enableWorkspaceScroll ?? true

    // Scratchpad detection (matching Workspaces.qml pattern)
    readonly property var currentHyprlandMonitorData: HyprlandData.monitors.find(mon => mon.name === root.monitor?.name)
    readonly property bool scratchpadOpen: !!(currentHyprlandMonitorData && currentHyprlandMonitorData.specialWorkspace && currentHyprlandMonitorData.specialWorkspace.name !== "")
    readonly property var scratchpadWin: scratchpadOpen ? HyprlandData.windowList.find(w => w.workspace && w.workspace.id === currentHyprlandMonitorData.specialWorkspace.id) : null
    readonly property string scratchpadAppId: scratchpadWin ? TaskbarApps.normalizeAppId(scratchpadWin.class) : ""

    property var activeUnpinned: TaskbarApps.apps.filter(a => {
        if (a.pinned || a.appId === "SEPARATOR" || a.toplevels.length === 0) return false;
        if (!root.alignToWorkspace) return true;
        return a.toplevels.some(t => {
            let win = HyprlandData.windowList.find(w => w.address === t.address || w.title === t.title);
            return win && win.workspace && win.workspace.id === root.activeWsId;
        });
    })
    property bool showSeparator: _workOrder.length > 0 && activeUnpinned.length > 0
    property var  _workOrder:            pinnedApps.slice()
    property bool _dragging:             false

    // ── Drag animation state ──────────────────────────────────────────────
    property bool dragging: false
    property bool _suppressTranslateAnim: false
    property int dragSourceIndex: -1
    property int _dragTargetIndex: -1
    property real dragCursorX: 0
    property real dragStartCursorX: 0
    property real slotWidth: root.btnSize + root.btnSpacing

    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical

    function _getPinnedItemWrapper(index) {
        return pinnedRepeater.itemAt(index)
    }

    function _getPinnedItemWidth(index) {
        var wrapper = _getPinnedItemWrapper(index)
        return wrapper ? (root.vertical ? wrapper.height : wrapper.width) : root.btnSize
    }

    function _getMaxDragOffset(index) {
        var count = _workOrder.length
        if (count <= 1) return { left: 0, right: 0 }
        var left = 0, right = 0
        for (var i = 0; i < count; i++) {
            var w = _getPinnedItemWidth(i) + root.btnSpacing
            if (i < index) left += w
            else if (i > index) right += w
        }
        return { left: -left, right: right }
    }

    function _recomputeDragTarget() {
        if (!dragging) {
            _dragTargetIndex = dragSourceIndex
            return
        }

        var count = _workOrder.length
        if (count <= 1) {
            _dragTargetIndex = dragSourceIndex
            return
        }

        var delta = dragCursorX - dragStartCursorX

        // dragged item center
        var draggedCenter = delta

        var target = dragSourceIndex

        if (delta > 0) {
            // moving right/down
            var pos = 0
            for (var i = dragSourceIndex + 1; i < count; ++i) {
                pos += (_getPinnedItemWidth(i - 1) + root.btnSpacing) / 2
                pos += (_getPinnedItemWidth(i) + root.btnSpacing) / 2

                if (draggedCenter >= pos)
                    target = i
                else
                    break
            }
        } else if (delta < 0) {
            var pos = 0
            for (var i = dragSourceIndex - 1; i >= 0; --i) {
                pos -= (_getPinnedItemWidth(i + 1) + root.btnSpacing) / 2
                pos -= (_getPinnedItemWidth(i) + root.btnSpacing) / 2

                if (draggedCenter <= pos)
                    target = i
                else
                    break
            }
        }

        _dragTargetIndex = target
    }

    function _startPinnedItemDrag(index) {
        _suppressTranslateAnim = true
        dragSourceIndex = index
        _dragTargetIndex = index
        slotWidth = root.btnSize + root.btnSpacing
        dragStartCursorX = 0
        dragCursorX = 0
        dragging = true
        Qt.callLater(function() { _suppressTranslateAnim = false })
    }

    // ── FIXED: move instead of swap ──────────────────────────────────────
    function _endPinnedItemDrag() {
        _suppressTranslateAnim = true

        var src = dragSourceIndex
        var tgt = _dragTargetIndex

        if (dragging &&
            src >= 0 &&
            tgt >= 0 &&
            src < _workOrder.length &&
            tgt < _workOrder.length &&
            src !== tgt) {

            var arr = _workOrder.slice()

            var item = arr[src]
            arr.splice(src, 1)
            arr.splice(tgt, 0, item)

            _workOrder = arr
            Config.options.dock.pinnedApps = arr
        }

        dragging = false
        dragSourceIndex = -1
        _dragTargetIndex = -1
        dragCursorX = 0
        dragStartCursorX = 0

        Qt.callLater(function() {
            _suppressTranslateAnim = false
        })
    }

    function _cancelPinnedDrag() {
        _suppressTranslateAnim = true
        dragging = false
        dragSourceIndex = -1
        _dragTargetIndex = -1
        Qt.callLater(function() { _suppressTranslateAnim = false })
    }

    onPinnedAppsChanged: {
        if (!_dragging)
            _workOrder = pinnedApps.slice()
    }

    implicitWidth:  vertical
        ? (isMaterial ? Appearance.sizes.verticalBarWidth : Appearance.sizes.verticalBarWidth - 10)
        : pill.implicitWidth
    implicitHeight: vertical
        ? pill.implicitHeight
        : Appearance.sizes.barHeight


    Rectangle {
        id: pill
        anchors.centerIn: parent
        color: "transparent"
        radius: Appearance.rounding.full

        implicitWidth: root.isMaterial && !root.vertical
            ? flow.implicitWidth + 10
            : root.vertical
                ? (root.isMaterial ? 32 : Appearance.sizes.verticalBarWidth - 10)
                : flow.implicitWidth + 4

        implicitHeight: root.isMaterial && root.vertical
            ? flow.implicitHeight + 10
            : root.isMaterial
                ? 32
                : root.vertical
                    ? flow.implicitHeight + 4
                    : Appearance.sizes.barHeight

        Behavior on implicitWidth {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
        Behavior on implicitHeight {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            enabled: root.enableWorkspaceScroll
            acceptedButtons: Qt.NoButton
            onWheel: event => {
                let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                if (delta > 0)
                    Hyprland.dispatch("workspace", "e-1");
                else if (delta < 0)
                    Hyprland.dispatch("workspace", "e+1");
            }
        }

        Flow {
            id: flow
            anchors.centerIn: parent
            flow:    root.vertical ? Flow.TopToBottom : Flow.LeftToRight
            spacing: root.btnSpacing

            // ── 1. PINNED APPS ───────────────────────────────────────────
            Repeater {
                id: pinnedRepeater
                model: root._workOrder.length

                delegate: Item {
                    id: slotItem
                    required property int index

                    property string appId:        root._workOrder[index] ?? ""
                    property var    appEntry:     TaskbarApps.apps.find(a => a.appId === appId) ?? null
                    property var    appToplevels: {
                        let list = appEntry?.toplevels ?? [];
                        if (!root.alignToWorkspace) return list;
                        return list.filter(t => {
                            let win = HyprlandData.windowList.find(w => w.address === t.address || w.title === t.title);
                            return win && win.workspace && win.workspace.id === root.activeWsId;
                        });
                    }
                    property var    deskEntry:    DesktopEntries.heuristicLookup(appId)
                    property bool   appActive:    appToplevels.find(t => t.activated) !== undefined
                    readonly property bool isScratchpadApp: root.scratchpadOpen && TaskbarApps.normalizeAppId(appId) === root.scratchpadAppId
                    property int    _lastFocused: -1

                    // ── Animation properties (with clamping) ──────────────
                    readonly property bool isDragged: root.dragging && index === root.dragSourceIndex
                    readonly property real dragTranslate: {
                        if (!root.dragging) return 0
                        if (isDragged) {
                            var raw = root.dragCursorX - root.dragStartCursorX
                            var maxOff = root._getMaxDragOffset(index)
                            var clamped = Math.max(maxOff.left, Math.min(maxOff.right, raw))
                            return clamped
                        }
                        var src = root.dragSourceIndex
                        var tgt = root._dragTargetIndex
                        var idx = index
                        var sw = root.slotWidth
                        if (src < tgt && idx > src && idx <= tgt) return -sw
                        if (src > tgt && idx >= tgt && idx < src) return sw
                        return 0
                    }

                    z: isDragged ? 100 : 0
                    opacity: root.scratchpadOpen ? (isScratchpadApp ? 1.0 : 0.35) : (isDragged ? 0.85 : 1.0)
                    scale: root.scratchpadOpen ? (isScratchpadApp ? 1.0 : 0.85) : (isDragged ? 1.05 : 1.0)

                    Behavior on opacity {
                        enabled: !root._suppressTranslateAnim
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                    Behavior on scale {
                        enabled: !root._suppressTranslateAnim
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    transform: Translate {
                        x: root.vertical ? 0 : slotItem.dragTranslate
                        y: root.vertical ? slotItem.dragTranslate : 0
                        Behavior on x {
                            enabled: !slotItem.isDragged && !root._suppressTranslateAnim
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }
                        Behavior on y {
                            enabled: !slotItem.isDragged && !root._suppressTranslateAnim
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }
                    }

                    width:  root.btnSize
                    height: root.btnSize


                    // ── DragHandler ──────────────────────────────────────────
                    DragHandler {
                        id: dragHandler
                        target: null
                        grabPermissions: PointerHandler.CanTakeOverFromAnything

                        onActiveChanged: {
                            if (active) {
                                root._startPinnedItemDrag(index)
                                var pos = root.vertical ? centroid.scenePosition.y : centroid.scenePosition.x
                                root.dragStartCursorX = pos
                                root.dragCursorX = pos
                            } else {
                                if (root.dragging) {
                                    root._endPinnedItemDrag()
                                }
                            }
                        }

                        onCentroidChanged: {
                            if (!active || !root.dragging) return
                            var pos = root.vertical ? centroid.scenePosition.y : centroid.scenePosition.x
                            root.dragCursorX = pos
                            root._recomputeDragTarget()
                        }
                    }

                    // ── Main button ──────────────────────────────────────────
                    RippleButton {
                        anchors.fill: parent
                        buttonRadius: Appearance.rounding.small
                        hoverEnabled: true

                        onClicked: {
                            if (root.dragging) return
                            const entry = slotItem.appEntry
                            if (!entry || entry.toplevels.length === 0) {
                                slotItem.deskEntry?.execute()
                                return
                            }
                            const next = (slotItem._lastFocused + 1) % entry.toplevels.length
                            slotItem._lastFocused = next
                            entry.toplevels[next].activate()
                        }
                        middleClickAction: () => { slotItem.deskEntry?.execute() }
                        altAction:         () => { TaskbarApps.togglePin(slotItem.appId) }
                        backClickAction:   () => { Hyprland.dispatch("togglespecialworkspace", "scratchpad") }

                        contentItem: Item {
                            anchors.centerIn: parent

                            IconImage {
                                id: pinnedIcon
                                anchors.centerIn: parent
                                source: Quickshell.iconPath(
                                    AppSearch.guessIcon(slotItem.appId), "image-missing")
                                implicitSize: root.iconSize
                            }

                            Loader {
                                active: Config.options?.dock?.monochromeIcons ?? false
                                anchors.fill: pinnedIcon
                                sourceComponent: Item {
                                    Desaturate {
                                        id: desat; visible: false
                                        anchors.fill: parent
                                        source: pinnedIcon; desaturation: 0.8
                                    }
                                    ColorOverlay {
                                        anchors.fill: desat; source: desat
                                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, Config.options.appearance.iconTintPercentage)
                                    }
                                }
                            }

                            Flow {
                                flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
                                spacing: 2
                                anchors {
                                    left:   root.vertical ? pinnedIcon.right    : undefined
                                    top:    root.vertical ? undefined            : pinnedIcon.bottom
                                    leftMargin:  root.vertical ? 1 : 0
                                    topMargin:   root.vertical ? 0 : 1
                                    horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
                                    verticalCenter:   root.vertical ? parent.verticalCenter : undefined
                                }
                                Repeater {
                                    model: Math.min(slotItem.appToplevels.length, 3)
                                    delegate: Rectangle {
                                        required property int index
                                        readonly property int topCount: slotItem.appToplevels.length
                                        readonly property bool isSingleActive: slotItem.appActive && topCount === 1

                                        radius: Appearance.rounding.full
                                        implicitWidth: root.vertical
                                            ? 3
                                            : (isSingleActive ? 14 : (topCount <= 3 ? 4 : 3))
                                        implicitHeight: root.vertical
                                            ? (isSingleActive ? 14 : (topCount <= 3 ? 4 : 3))
                                            : 3
                                        color: slotItem.appActive
                                            ? Appearance.colors.colPrimary
                                            : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.75)

                                        Behavior on implicitWidth {
                                            NumberAnimation {
                                                duration: Appearance.animation.elementMoveFast.duration
                                                easing.type: Appearance.animation.elementMoveFast.type
                                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                            }
                                        }
                                        Behavior on implicitHeight {
                                            NumberAnimation {
                                                duration: Appearance.animation.elementMoveFast.duration
                                                easing.type: Appearance.animation.elementMoveFast.type
                                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                            }
                                        }
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: Appearance.animation.elementMoveFast.duration
                                                easing.type: Appearance.animation.elementMoveFast.type
                                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── 2. SEPARATOR ─────────────────────────────────────────────
            Item {
                width:   root.vertical ? root.btnSize          : (root.showSeparator ? (1 + root.btnSpacing * 3) : 0)
                height:  root.vertical ? (root.showSeparator ? (1 + root.btnSpacing * 3) : 0) : root.btnSize
                visible: root.showSeparator

                Rectangle {
                    anchors.centerIn: parent
                    width:  root.vertical ? Math.round(root.btnSize * 0.6) : 1
                    height: root.vertical ? 1 : Math.round(root.btnSize * 0.6)
                    color:  root.isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                }
            }

            // ── 3. ACTIVE UNPINNED APPS ───────────────────────────────────
            Repeater {
                id: activeRepeater
                model: root.activeUnpinned

                delegate: Item {
                    id: activeSlot
                    required property var modelData

                    property var activeToplevels: {
                        let list = modelData.toplevels ?? [];
                        if (!root.alignToWorkspace) return list;
                        return list.filter(t => {
                            let win = HyprlandData.windowList.find(w => w.address === t.address || w.title === t.title);
                            return win && win.workspace && win.workspace.id === root.activeWsId;
                        });
                    }
                    property bool appIsActive: activeToplevels.find(t => t.activated) !== undefined
                    readonly property bool isScratchpadApp: root.scratchpadOpen && TaskbarApps.normalizeAppId(modelData.appId) === root.scratchpadAppId
                    property int  _lastFocused: -1

                    width:  root.btnSize
                    height: root.btnSize
                    opacity: root.scratchpadOpen ? (isScratchpadApp ? 1.0 : 0.35) : 1.0
                    scale: root.scratchpadOpen ? (isScratchpadApp ? 1.0 : 0.85) : 1.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    RippleButton {
                        anchors.fill: parent
                        buttonRadius: Appearance.rounding.small
                        hoverEnabled: true

                        onClicked: {
                            if (activeSlot.modelData.toplevels.length === 0) return
                            const next = (activeSlot._lastFocused + 1) % activeSlot.modelData.toplevels.length
                            activeSlot._lastFocused = next
                            activeSlot.modelData.toplevels[next].activate()
                        }
                        middleClickAction: () => {
                            DesktopEntries.heuristicLookup(activeSlot.modelData.appId)?.execute()
                        }
                        altAction: () => {
                            TaskbarApps.togglePin(activeSlot.modelData.appId)
                        }
                        backClickAction: () => {
                            Hyprland.dispatch("togglespecialworkspace", "scratchpad")
                        }

                        contentItem: Item {
                            anchors.centerIn: parent

                            IconImage {
                                id: activeIcon
                                anchors.centerIn: parent
                                source: Quickshell.iconPath(
                                    AppSearch.guessIcon(activeSlot.modelData.appId), "image-missing")
                                implicitSize: root.iconSize
                            }

                            Loader {
                                active: Config.options?.dock?.monochromeIcons ?? false
                                anchors.fill: activeIcon
                                sourceComponent: Item {
                                    Desaturate {
                                        id: desat2; visible: false
                                        anchors.fill: parent
                                        source: activeIcon; desaturation: 0.8
                                    }
                                    ColorOverlay {
                                        anchors.fill: desat2; source: desat2
                                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, Config.options.appearance.iconTintPercentage)
                                    }
                                }
                            }

                            Flow {
                                flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
                                spacing: 2
                                anchors {
                                    left:   root.vertical ? activeIcon.right    : undefined
                                    top:    root.vertical ? undefined            : activeIcon.bottom
                                    leftMargin:  root.vertical ? 1 : 0
                                    topMargin:   root.vertical ? 0 : 1
                                    horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
                                    verticalCenter:   root.vertical ? parent.verticalCenter : undefined
                                }
                                Repeater {
                                    model: Math.min(activeSlot.activeToplevels.length, 3)
                                    delegate: Rectangle {
                                        required property int index
                                        readonly property int topCount: activeSlot.activeToplevels.length
                                        readonly property bool isSingleActive: activeSlot.appIsActive && topCount === 1

                                        radius: Appearance.rounding.full
                                        implicitWidth: root.vertical
                                            ? 3
                                            : (isSingleActive ? 14 : (topCount <= 3 ? 4 : 3))
                                        implicitHeight: root.vertical
                                            ? (isSingleActive ? 14 : (topCount <= 3 ? 4 : 3))
                                            : 3
                                        color: activeSlot.appIsActive
                                            ? Appearance.colors.colPrimary
                                            : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.45)

                                        Behavior on implicitWidth {
                                            NumberAnimation {
                                                duration: Appearance.animation.elementMoveFast.duration
                                                easing.type: Appearance.animation.elementMoveFast.type
                                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                            }
                                        }
                                        Behavior on implicitHeight {
                                            NumberAnimation {
                                                duration: Appearance.animation.elementMoveFast.duration
                                                easing.type: Appearance.animation.elementMoveFast.type
                                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                            }
                                        }
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: Appearance.animation.elementMoveFast.duration
                                                easing.type: Appearance.animation.elementMoveFast.type
                                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}