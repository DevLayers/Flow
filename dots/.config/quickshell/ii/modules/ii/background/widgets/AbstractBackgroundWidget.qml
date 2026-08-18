import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets
import "WidgetDragMath.js" as WidgetDragMath

AbstractWidget {
    id: root

    antialiasing: true
    smooth: true

    property string configEntryName: ""
    property var widgetInstance: null
    property bool isPreview: false
    property string styleOverride: widgetInstance ? (WidgetsRegistry.getStyleOverride(widgetInstance.widgetId) || "") : ""

    property int screenWidth: 1920
    property int screenHeight: 1080
    property int scaledScreenWidth: 1920
    property int scaledScreenHeight: 1080
    property real wallpaperScale: 1.0
    property var widgetListModel: null
    property var widgetSizes: ({})
    property int widgetSizesVersion: 0
    property var configEntry: widgetInstance !== null ? widgetInstance : (Config.options.background.widgets[configEntryName] || null)
    property string placementStrategy: isPreview ? "free" : (widgetInstance !== null ? (widgetInstance.placementStrategy || "free") : (configEntry ? configEntry.placementStrategy : "free"))
    property string lockBehavior: widgetInstance ? (widgetInstance.lockBehavior || "hide") : "hide"
    property bool visibleWhenLocked: lockBehavior === "keep" || lockBehavior === "center" || lockBehavior === "lockOnly"
    property bool forceCenter: (GlobalStates.lockScreenCentered || GlobalStates.workspaceRestoreInProgress) && lockBehavior === "center"

    function getCenteredWidgetsList() {
        if (!widgetListModel) return [];
        let result = [];
        for (let i = 0; i < widgetListModel.count; i++) {
            let w = widgetListModel.get(i);
            let lb = w.lockBehavior || "hide";
            let isCentered = lb === "center";
            if (isCentered) {
                result.push(w);
            }
        }
        return result;
    }

    readonly property var centeredWidgetsList: {
        if (backgroundScope && backgroundScope.widgetSyncVersion !== undefined) {
            backgroundScope.widgetSyncVersion; // dependency to force re-evaluation
        }
        return getCenteredWidgetsList() ?? [];
    }
    readonly property int centeredWidgetCount: (centeredWidgetsList ?? []).length
    readonly property int centeredWidgetIndex: {
        if (!widgetInstance) return 0;
        for (let i = 0; i < centeredWidgetsList.length; i++) {
            if (centeredWidgetsList[i].instanceId === widgetInstance.id) return i;
        }
        return 0;
    }

    readonly property real centeredOffsetX: {
        if (centeredWidgetCount <= 1) return 0;
        let alignment = Config.options.lock.centerAlignment;
        if (alignment === "horizontal" || alignment === undefined || alignment === "") {
            let spacing = Config.options.lock.centerSpacing || 20;
            // Depend on widgetSizesVersion so binding re-evaluates after in-place mutations
            root.widgetSizesVersion;
            let sizes = root.widgetSizes || {};
            // Accumulate actual widths of all centered widgets
            let totalWidth = 0;
            let widths = [];
            for (let i = 0; i < centeredWidgetCount; i++) {
                let wInstanceId = centeredWidgetsList[i].instanceId || centeredWidgetsList[i].id;
                let wSize = sizes[wInstanceId];
                let w = (wSize && wSize.width > 0) ? wSize.width : root.width;
                widths.push(w);
                totalWidth += w;
            }
            totalWidth += (centeredWidgetCount - 1) * spacing;
            // Position of this widget within the group
            let myX = 0;
            for (let i = 0; i < centeredWidgetIndex; i++) {
                myX += widths[i] + spacing;
            }
            let result = myX - (totalWidth - root.width) / 2;
            return result;
        }
        return 0;
    }

    readonly property real centeredOffsetY: {
        if (centeredWidgetCount <= 1) return 0;
        let alignment = Config.options.lock.centerAlignment;
        if (alignment === "vertical") {
            let spacing = Config.options.lock.centerSpacing || 20;
            root.widgetSizesVersion;
            let sizes = root.widgetSizes || {};
            // Accumulate actual heights of all centered widgets
            let totalHeight = 0;
            let heights = [];
            for (let i = 0; i < centeredWidgetCount; i++) {
                let wInstanceId = centeredWidgetsList[i].instanceId || centeredWidgetsList[i].id;
                let wSize = sizes[wInstanceId];
                let h = (wSize && wSize.height > 0) ? wSize.height : root.height;
                heights.push(h);
                totalHeight += h;
            }
            totalHeight += (centeredWidgetCount - 1) * spacing;
            // Position of this widget within the group
            let myY = 0;
            for (let i = 0; i < centeredWidgetIndex; i++) {
                myY += heights[i] + spacing;
            }
            return myY - (totalHeight - root.height) / 2;
        }
        return 0;
    }

    readonly property real centeringX: (screenWidth - width) / 2 + centeredOffsetX
    readonly property real centeringY: (screenHeight - height) / 2 + centeredOffsetY

    // Register own size in the shared map whenever width/height changes
    function _registerOwnSize() {
        if (!widgetInstance) return;
        let id = widgetInstance.id;
        if (!id || width <= 0 || height <= 0) return;
        // Mutate in-place to preserve the shared reference across all widget instances
        root.widgetSizes[id] = { "width": width, "height": height };
        // Bump the version counter on widgetStateManager to trigger binding re-evaluation
        if (typeof backgroundScope !== 'undefined' && backgroundScope.widgetStateManager) {
            backgroundScope.widgetStateManager.widgetSizesVersion++;
        }
    }
    onWidthChanged: _registerOwnSize()
    onHeightChanged: _registerOwnSize()
    onWidgetInstanceChanged: _registerOwnSize()

    onForceCenterChanged: {
        root.animDuration = Math.round(450 * Appearance.animMultiplier);
        if (forceCenter) {
            lockAnimResetTimer.restart();
        } else {
            unlockAnimResetTimer.restart();
        }
    }
    Timer {
        id: lockAnimResetTimer
        interval: Math.round(450 * Appearance.animMultiplier)
        repeat: false
        onTriggered: { root.animDuration = Appearance.animation.elementMove.duration; }
    }
    Timer {
        id: unlockAnimResetTimer
        interval: Math.round(450 * Appearance.animMultiplier)
        repeat: false
        onTriggered: { root.animDuration = Appearance.animation.elementMove.duration; }
    }

    property real calculatedX: 0
    property real calculatedY: 0
    property real staggerDelay: 0
    property bool _pendingPosition: false
    property real targetX: isPreview ? 0 : (forceCenter ? centeringX : ((placementStrategy === "free" || placementStrategy === "draggable") ? Math.max(0, Math.min(widgetInstance !== null ? widgetInstance.x : (configEntry ? configEntry.x : 0), scaledScreenWidth - width)) : calculatedX))
    property real targetY: isPreview ? 0 : (forceCenter ? centeringY : ((placementStrategy === "free" || placementStrategy === "draggable") ? Math.max(0, Math.min(widgetInstance !== null ? widgetInstance.y : (configEntry ? configEntry.y : 0), scaledScreenHeight - height)) : calculatedY))
    property bool isDraggingOrSettling: false

    // Pointer coordinates and rendered coordinates are intentionally separate.
    // MouseArea.drag must not write root.x/y because snap/grid also write them.
    property bool _pointerGestureReady: false
    property bool _dragMovementActive: false
    property real _pressCanvasX: 0
    property real _pressCanvasY: 0
    property real _dragOriginX: 0
    property real _dragOriginY: 0
    property real _rawDragX: 0
    property real _rawDragY: 0

    // ── Snap hysteresis state ─────────────────────────────────────────────────
    // This is a Schmitt trigger: acquire close to a guide, release farther away.
    readonly property int _snapEnter: 18
    readonly property int _snapExit: 32
    readonly property int _snapOrthogonalRange: 600
    property bool _snapLockX: false
    property real _snapLockXTarget: 0
    property real _snapGuideX: -1
    property bool _snapLockY: false
    property real _snapLockYTarget: 0
    property real _snapGuideY: -1

    // ── Grid anchor state ─────────────────────────────────────────────────────
    // Grid cells are 10px wide. The anchor stores the raw pointer position at the
    // time of the last cell commit. A new cell is committed only when raw has
    // moved >= _gridStep from the anchor. The anchor then updates to rawX so the
    // NEXT jump again requires a full _gridStep of mouse movement.
    //
    // Why this beats distance-from-cell-centre hysteresis:
    //   After each cell jump the "current cell" changes. If mouse jitters ±6px
    //   around the jump boundary, the cell alternates because the new cell's
    //   hysteresis zone is immediately triggered. With anchor tracking the
    //   required movement is ALWAYS relative to the raw position — stable.
    readonly property int _gridStep: {
        const canvas = findCanvas(root.parent);
        return Math.max(1, canvas ? canvas.alignmentGridStep : 10);
    }
    property real _gridAnchorX: 0   // raw x at last grid commit
    property real _gridAnchorY: 0   // raw y at last grid commit
    property real _lastGridX: 0     // last committed grid cell x
    property real _lastGridY: 0     // last committed grid cell y

    onIsPreviewChanged: {
        if (isPreview) {
            root.x = 0;
            root.y = 0;
        }
    }

    Component.onCompleted: {
        root.animateXPos = false;
        root.animateYPos = false;
        if (root.isPreview) {
            root.x = 0;
            root.y = 0;
        } else {
            root.x = root.targetX;
            root.y = root.targetY;
        }
        Qt.callLater(() => {
            root.animateXPos = !root.isDragging;
            root.animateYPos = !root.isDragging;
        });
    }

    Timer {
        id: staggerTimer
        repeat: false
        onTriggered: {
            root._pendingPosition = false;
            if (!root.isDragging && !root.isDraggingOrSettling && !root.isPreview) {
                if (root.x !== root.targetX) root.x = root.targetX;
                if (root.y !== root.targetY) root.y = root.targetY;
            }
        }
    }

    Timer {
        id: settleTimer
        interval: 350
        repeat: false
        onTriggered: {
            root.isDraggingOrSettling = false;
            if (!root.isPreview) {
                if (root.x !== root.targetX) root.x = root.targetX;
                if (root.y !== root.targetY) root.y = root.targetY;
            }
        }
    }

    readonly property bool isDragging: _dragMovementActive
    onIsDraggingChanged: {
        let canvas = findCanvas(root.parent);
        if (canvas) {
            canvas.draggingActive = isDragging;
        }
        if (!isDragging) {
            if (canvas) {
                canvas.snapLineX = -1;
                canvas.snapLineY = -1;
            }
        }
    }

    function beginPointerGesture(mouse) {
        if (!draggable)
            return;

        const canvas = findCanvas(root.parent);
        if (!canvas)
            return;

        settleTimer.stop();
        staggerTimer.stop();
        _pendingPosition = false;

        const pointer = root.mapToItem(canvas, mouse.x, mouse.y);
        _pointerGestureReady = true;
        _dragMovementActive = false;
        isDraggingOrSettling = true;
        _pressCanvasX = pointer.x;
        _pressCanvasY = pointer.y;
        _dragOriginX = root.x;
        _dragOriginY = root.y;
        _rawDragX = root.x;
        _rawDragY = root.y;

        _snapLockX = false;
        _snapLockY = false;
        _snapGuideX = -1;
        _snapGuideY = -1;

        _gridAnchorX = root.x;
        _gridAnchorY = root.y;
        _lastGridX = Math.max(0, Math.min(Math.round(root.x / _gridStep) * _gridStep, gridMaximumX()));
        _lastGridY = Math.max(0, Math.min(Math.round(root.y / _gridStep) * _gridStep, gridMaximumY()));
    }

    function updatePointerGesture(mouse) {
        if (!_pointerGestureReady || !pressed || !draggable)
            return;

        const canvas = findCanvas(root.parent);
        if (!canvas)
            return;

        const pointer = root.mapToItem(canvas, mouse.x, mouse.y);
        const deltaX = pointer.x - _pressCanvasX;
        const deltaY = pointer.y - _pressCanvasY;

        if (!_dragMovementActive) {
            const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);
            if (distance < root.drag.threshold)
                return;
            _dragMovementActive = true;
        }

        _rawDragX = WidgetDragMath.clamp(_dragOriginX + deltaX, 0, dragMaximumX());
        _rawDragY = WidgetDragMath.clamp(_dragOriginY + deltaY, 0, dragMaximumY());
        root.x = applyGridAndSnapX(_rawDragX, _rawDragY);
        root.y = applyGridAndSnapY(_rawDragY, _rawDragX);
    }

    onPressed: mouse => beginPointerGesture(mouse)
    onPositionChanged: mouse => updatePointerGesture(mouse)

    onTargetXChanged: {
        if (!isDragging && !root.isDraggingOrSettling && !root.isPreview) {
            if (root.staggerDelay > 0) {
                root._pendingPosition = true;
                staggerTimer.interval = root.staggerDelay;
                staggerTimer.restart();
            } else {
                root.x = targetX;
            }
        }
    }
    onTargetYChanged: {
        if (!isDragging && !root.isDraggingOrSettling && !root.isPreview) {
            if (root.staggerDelay > 0) {
                root._pendingPosition = true;
                staggerTimer.interval = root.staggerDelay;
                staggerTimer.restart();
            } else {
                root.y = targetY;
            }
        }
    }



    visible: opacity > 0
    opacity: {
        if (lockBehavior === "lockOnly") return GlobalStates.lockScreenCentered ? 1 : 0;
        if (GlobalStates.lockScreenCentered && !visibleWhenLocked) return 0;
        return 1;
    }
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }
    readonly property real lockScaleFactor: lockBehavior === "center" ? 1.0 : (GlobalStates.lockAnimationActive ? 0.85 : 1.0)
    scale: ((draggable && containsPress) ? 1.05 : 1.0) * (Config.options.background.widgets.widgetsScale ?? 1.0) * lockScaleFactor
    Behavior on scale {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    function findCanvas(item) {
        var p = item
        while (p) {
            if (p.isWidgetCanvas === true) return p
            p = p.parent
        }
        return null
    }

    function dragMaximumX() {
        return Math.max(0, scaledScreenWidth - width);
    }

    function dragMaximumY() {
        return Math.max(0, scaledScreenHeight - height);
    }

    function gridMaximumX() {
        return Math.floor(dragMaximumX() / _gridStep) * _gridStep;
    }

    function gridMaximumY() {
        return Math.floor(dragMaximumY() / _gridStep) * _gridStep;
    }

    function advanceGridX(rawX) {
        const state = WidgetDragMath.advanceGrid(rawX, _gridAnchorX, _lastGridX, _gridStep, 0, gridMaximumX());
        _gridAnchorX = state.anchor;
        _lastGridX = state.value;
        return _lastGridX;
    }

    function advanceGridY(rawY) {
        const state = WidgetDragMath.advanceGrid(rawY, _gridAnchorY, _lastGridY, _gridStep, 0, gridMaximumY());
        _gridAnchorY = state.anchor;
        _lastGridY = state.value;
        return _lastGridY;
    }

    function snapCandidateX(rawX, rawY) {
        if (!widgetListModel)
            return null;

        const candidates = [];
        for (let i = 0; i < widgetListModel.count; i++) {
            const widget = widgetListModel.get(i);
            if (widgetInstance && widget.instanceId === widgetInstance.id)
                continue;
            if (Math.abs(rawY - widget.widgetY) >= _snapOrthogonalRange)
                continue;

            const widgetId = widget.instanceId || widget.id;
            const widgetWidth = (widgetSizes && widgetSizes[widgetId] && widgetSizes[widgetId].width > 0)
                ? widgetSizes[widgetId].width
                : root.width;
            const otherLeft = widget.widgetX;
            const otherRight = widget.widgetX + widgetWidth;

            candidates.push({ "target": otherLeft, "guide": otherLeft, "distance": Math.abs(rawX - otherLeft) });
            candidates.push({ "target": otherRight - root.width, "guide": otherRight, "distance": Math.abs(rawX + root.width - otherRight) });
            candidates.push({ "target": otherRight, "guide": otherRight, "distance": Math.abs(rawX - otherRight) });
            candidates.push({ "target": otherLeft - root.width, "guide": otherLeft, "distance": Math.abs(rawX + root.width - otherLeft) });
        }

        return WidgetDragMath.nearestValidCandidate(candidates, 0, dragMaximumX(), _snapEnter);
    }

    function snapCandidateY(rawY, rawX) {
        if (!widgetListModel)
            return null;

        const candidates = [];
        for (let i = 0; i < widgetListModel.count; i++) {
            const widget = widgetListModel.get(i);
            if (widgetInstance && widget.instanceId === widgetInstance.id)
                continue;
            if (Math.abs(rawX - widget.widgetX) >= _snapOrthogonalRange)
                continue;

            const widgetId = widget.instanceId || widget.id;
            const widgetHeight = (widgetSizes && widgetSizes[widgetId] && widgetSizes[widgetId].height > 0)
                ? widgetSizes[widgetId].height
                : root.height;
            const otherTop = widget.widgetY;
            const otherBottom = widget.widgetY + widgetHeight;

            candidates.push({ "target": otherTop, "guide": otherTop, "distance": Math.abs(rawY - otherTop) });
            candidates.push({ "target": otherBottom - root.height, "guide": otherBottom, "distance": Math.abs(rawY + root.height - otherBottom) });
            candidates.push({ "target": otherBottom, "guide": otherBottom, "distance": Math.abs(rawY - otherBottom) });
            candidates.push({ "target": otherTop - root.height, "guide": otherTop, "distance": Math.abs(rawY + root.height - otherTop) });
        }

        return WidgetDragMath.nearestValidCandidate(candidates, 0, dragMaximumY(), _snapEnter);
    }

    function applyGridAndSnapX(rawX, rawY) {
        const canvas = findCanvas(root.parent);
        let targetXVal = (Config.options.background.widgets.enableGrid ?? false) ? advanceGridX(rawX) : rawX;
        let snapped = false;

        if (Config.options.background.widgets.enableSnap ?? false) {
            if (_snapLockX && WidgetDragMath.shouldHoldSnap(rawX, _snapLockXTarget, _snapExit)) {
                targetXVal = _snapLockXTarget;
                snapped = true;
            } else {
                _snapLockX = false;
                const candidate = snapCandidateX(rawX, rawY);
                if (candidate) {
                    _snapLockX = true;
                    _snapLockXTarget = candidate.target;
                    _snapGuideX = candidate.guide;
                    targetXVal = candidate.target;
                    snapped = true;
                }
            }
        } else {
            _snapLockX = false;
        }

        if (canvas)
            canvas.snapLineX = snapped && isDragging ? _snapGuideX : -1;
        return targetXVal;
    }

    function applyGridAndSnapY(rawY, rawX) {
        const canvas = findCanvas(root.parent);
        let targetYVal = (Config.options.background.widgets.enableGrid ?? false) ? advanceGridY(rawY) : rawY;
        let snapped = false;

        if (Config.options.background.widgets.enableSnap ?? false) {
            if (_snapLockY && WidgetDragMath.shouldHoldSnap(rawY, _snapLockYTarget, _snapExit)) {
                targetYVal = _snapLockYTarget;
                snapped = true;
            } else {
                _snapLockY = false;
                const candidate = snapCandidateY(rawY, rawX);
                if (candidate) {
                    _snapLockY = true;
                    _snapLockYTarget = candidate.target;
                    _snapGuideY = candidate.guide;
                    targetYVal = candidate.target;
                    snapped = true;
                }
            }
        } else {
            _snapLockY = false;
        }

        if (canvas)
            canvas.snapLineY = snapped && isDragging ? _snapGuideY : -1;
        return targetYVal;
    }

    draggable: !isPreview && !(Config.options.background.widgets.lockWidgetPositions ?? false) && (placementStrategy === "free" || placementStrategy === "draggable")
    drag.target: undefined
    drag.threshold: 4
    preventStealing: true
    animateXPos: !isDragging && !isDraggingOrSettling && (visibleWhenLocked || !GlobalStates.screenLocked)
    animateYPos: !isDragging && !isDraggingOrSettling && (visibleWhenLocked || !GlobalStates.screenLocked)

    onReleased: {
        if (!_pointerGestureReady) {
            isDraggingOrSettling = false;
            return;
        }
        if (isPreview || !_dragMovementActive) {
            _pointerGestureReady = false;
            _dragMovementActive = false;
            isDraggingOrSettling = false;
            return;
        }

        const finalX = applyGridAndSnapX(_rawDragX, _rawDragY);
        const finalY = applyGridAndSnapY(_rawDragY, _rawDragX);
        root.x = finalX;
        root.y = finalY;

        const canvas = findCanvas(root.parent);
        if (canvas) {
            canvas.snapLineX = -1;
            canvas.snapLineY = -1;
        }

        if (widgetInstance !== null) {
            Config.updateWidgetPosition(widgetInstance.id, finalX, finalY);
        } else if (configEntry) {
            configEntry.x = finalX;
            configEntry.y = finalY;
        }

        _pointerGestureReady = false;
        _dragMovementActive = false;
        settleTimer.restart();
    }

    onCanceled: {
        if (_pointerGestureReady && _dragMovementActive) {
            root.x = _dragOriginX;
            root.y = _dragOriginY;
        }
        _pointerGestureReady = false;
        _dragMovementActive = false;
        isDraggingOrSettling = false;
    }

    property bool needsColText: false
    property color dominantColor: Appearance.colors.colPrimary
    property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
    property color colText: {
        const onNormalBackground = (GlobalStates.lockScreenCentered && Config.options.lock.blur.enable)
        const adaptiveColor = ColorUtils.colorWithLightness(Appearance.colors.colPrimary, (dominantColorIsDark ? 0.8 : 0.12))
        return onNormalBackground ? Appearance.colors.colOnLayer0 : adaptiveColor;
    }
    property color colTextSecondary: {
        const onNormalBackground = (GlobalStates.lockScreenCentered && Config.options.lock.blur.enable)
        const adaptiveColor = ColorUtils.colorWithLightness(Appearance.colors.colSecondary, (dominantColorIsDark ? 0.8 : 0.12))
        return onNormalBackground ? Appearance.colors.colOnLayer0 : adaptiveColor;
    }
    property color colTextTertiary: {
        const onNormalBackground = (GlobalStates.lockScreenCentered && Config.options.lock.blur.enable)
        const adaptiveColor = ColorUtils.colorWithLightness(Appearance.colors.colTertiary, (dominantColorIsDark ? 0.8 : 0.12))
        return onNormalBackground ? Appearance.colors.colOnLayer0 : adaptiveColor;
    }

    property bool wallpaperIsVideo: Config.options.background.wallpaperPath.endsWith(".mp4") || Config.options.background.wallpaperPath.endsWith(".webm") || Config.options.background.wallpaperPath.endsWith(".mkv") || Config.options.background.wallpaperPath.endsWith(".avi") || Config.options.background.wallpaperPath.endsWith(".mov")
    property string wallpaperPath: wallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath
    
    onWallpaperPathChanged: refreshPlacementIfNeeded()
    onPlacementStrategyChanged: refreshPlacementIfNeeded()
    Connections {
        target: Config
        function onReadyChanged() { refreshPlacementIfNeeded() }
    }
    function refreshPlacementIfNeeded() {
        if (isPreview) return;
        if (!Config.ready) return;
        if ((root.placementStrategy === "free" || root.placementStrategy === "draggable") && !root.needsColText) return;
        leastBusyRegionProc.wallpaperPath = root.wallpaperPath;
        leastBusyRegionProc.running = false;
        leastBusyRegionProc.running = true;
    }
    Process {
        id: leastBusyRegionProc
        property string wallpaperPath: root.wallpaperPath
        // TODO: make these less arbitrary
        property int contentWidth: 300
        property int contentHeight: 300
        property int horizontalPadding: 200
        property int verticalPadding: 200
        command: [Quickshell.shellPath("scripts/images/least-busy-region-venv.sh") // Comments to force the formatter to break lines
            , "--screen-width", Math.round(root.scaledScreenWidth) //
            , "--screen-height", Math.round(root.scaledScreenHeight) //
            , "--width", contentWidth //
            , "--height", contentHeight //
            , "--horizontal-padding", horizontalPadding //
            , "--vertical-padding", verticalPadding //
            , wallpaperPath //
            , ...(root.placementStrategy === "mostBusy" || root.placementStrategy === "most_busy" ? ["--busiest"] : [])
            // "--visual-output",
        ]
        stdout: StdioCollector {
            id: leastBusyRegionOutputCollector
            onStreamFinished: {
                const output = leastBusyRegionOutputCollector.text;
                // console.log("[Background] Least busy region output:", output)
                if (output.length === 0) return;
                const parsedContent = JSON.parse(output);
                root.dominantColor = parsedContent.dominant_color || Appearance.colors.colPrimary;
                root.calculatedX = parsedContent.center_x * root.wallpaperScale - root.width / 2;
                root.calculatedY  = parsedContent.center_y * root.wallpaperScale - root.height / 2;
            }
        }
    }


}
