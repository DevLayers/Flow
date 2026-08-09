import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

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

    // Raw (pre-grid, pre-snap) drag position — tracks the drag system's raw output each frame.
    // Proximity/threshold checks use these so snap decisions are based on where the mouse IS,
    // not the already-transformed rendered position (prevents oscillation).
    property real _rawDragX: 0
    property real _rawDragY: 0
    property bool _applyingGridSnap: false  // re-entrancy guard for onXChanged/onYChanged

    // ── Snap hysteresis state ─────────────────────────────────────────────────
    // Enter: snap when raw is within _snapEnter px of an alignment edge.
    // Exit:  unsnap only when raw has moved > _snapExit px FROM THE ENTRY POINT
    //        (not from the target). This prevents the re-entry loop that happens
    //        when exit is measured from the target and the entry zone overlaps
    //        with the exit zone.
    readonly property int _snapEnter: 18
    readonly property int _snapExit:  55
    property bool _snapLockX: false
    property real _snapLockXTarget: 0  // rendered x when snapped
    property real _snapEntryX: 0      // rawX at the moment snap was established
    property bool _snapLockY: false
    property real _snapLockYTarget: 0  // rendered y when snapped
    property real _snapEntryY: 0      // rawY at the moment snap was established

    // ── Grid anchor state ─────────────────────────────────────────────────────
    // Grid cells are 20px wide. The anchor stores the raw mouse position at the
    // time of the last cell commit. A new cell is committed only when raw has
    // moved >= _gridStep from the anchor. The anchor then updates to rawX so the
    // NEXT jump again requires a full _gridStep of mouse movement.
    //
    // Why this beats distance-from-cell-centre hysteresis:
    //   After each cell jump the "current cell" changes. If mouse jitters ±6px
    //   around the jump boundary, the cell alternates because the new cell's
    //   hysteresis zone is immediately triggered. With anchor tracking the
    //   required movement is ALWAYS relative to the raw position — stable.
    readonly property int _gridStep: 20
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
            root.animateXPos = !root.drag.active;
            root.animateYPos = !root.drag.active;
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

    readonly property bool isDragging: drag.active
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

    onPressedChanged: {
        if (pressed) {
            isDraggingOrSettling = true;
            _rawDragX = root.x;
            _rawDragY = root.y;
            // Reset ALL hysteresis state at drag start
            _snapLockX = false;
            _snapLockY = false;
            // Grid: anchor starts at current raw position; cell starts at current grid-aligned position
            _gridAnchorX = root.x;
            _gridAnchorY = root.y;
            _lastGridX   = Math.round(root.x / _gridStep) * _gridStep;
            _lastGridY   = Math.round(root.y / _gridStep) * _gridStep;
        }
    }

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

    function applyGridAndSnapX(rawX, rawY) {
        let targetXVal = rawX;
        let canvas = findCanvas(root.parent);
        let snapped = false;

        if (Config.options.background.widgets.enableSnap ?? false) {
            // ── Snap with entry-point hysteresis ────────────────────────────
            // Exit is measured from _snapEntryX (raw position when snap fired),
            // NOT from _snapLockXTarget (the rendered alignment position).
            // This prevents the tight enter/exit loop: because the entry zone
            // is near the alignment edge, measuring exit from the target means
            // a tiny backward mouse movement can unsnap, then the forward movement
            // re-snaps — continuous oscillation. Measuring from the entry point
            // means the user must move _snapExit px from where they physically
            // were when snap engaged.
            if (_snapLockX) {
                if (Math.abs(rawX - _snapEntryX) < _snapExit) {
                    targetXVal = _snapLockXTarget;
                    if (isDragging && canvas) canvas.snapLineX = _snapLockXTarget;
                    snapped = true;
                } else {
                    _snapLockX = false;
                }
            }

            if (!snapped && widgetListModel) {
                for (let i = 0; i < widgetListModel.count; i++) {
                    let w = widgetListModel.get(i);
                    if (widgetInstance && w.instanceId === widgetInstance.id) continue;

                    let verticallyClose = Math.abs(rawY - w.widgetY) < 600;
                    if (!verticallyClose) continue;

                    let wId = w.instanceId || w.id;
                    let wWidth = (widgetSizes && widgetSizes[wId] && widgetSizes[wId].width > 0) ? widgetSizes[wId].width : root.width;

                    let hasCandidate = false;
                    let candidate = 0;
                    let lineX    = 0;
                    if (Math.abs(rawX - w.widgetX) < _snapEnter) {
                        candidate = w.widgetX; lineX = w.widgetX; hasCandidate = true;
                    } else if (Math.abs((rawX + root.width) - (w.widgetX + wWidth)) < _snapEnter) {
                        candidate = w.widgetX + wWidth - root.width; lineX = w.widgetX + wWidth; hasCandidate = true;
                    } else if (Math.abs(rawX - (w.widgetX + wWidth)) < _snapEnter) {
                        candidate = w.widgetX + wWidth; lineX = w.widgetX + wWidth; hasCandidate = true;
                    } else if (Math.abs((rawX + root.width) - w.widgetX) < _snapEnter) {
                        candidate = w.widgetX - root.width; lineX = w.widgetX; hasCandidate = true;
                    }

                    if (hasCandidate) {
                        targetXVal = candidate;
                        if (isDragging && canvas) canvas.snapLineX = lineX;
                        _snapLockX = true;
                        _snapLockXTarget = candidate;
                        _snapEntryX = rawX;  // record WHERE mouse was, not the snap target
                        snapped = true;
                        break;
                    }
                }
            }
        }

        if (!snapped && canvas) canvas.snapLineX = -1;

        // ── Grid with anchor-based tracking ──────────────────────────────────
        // A cell commit happens only when rawX has moved >= _gridStep from
        // _gridAnchorX (the raw position at the last commit). After committing,
        // _gridAnchorX = rawX so the NEXT jump again needs a full step of travel.
        // This is stable regardless of how the cell boundaries shift: the required
        // movement is always _gridStep of physical cursor distance.
        if (!snapped && (Config.options.background.widgets.enableGrid ?? false)) {
            let delta = rawX - _gridAnchorX;
            if (delta >= _gridStep) {
                // Moved right by at least one step
                let steps = Math.floor(delta / _gridStep);
                _gridAnchorX += steps * _gridStep;
                _lastGridX = Math.round(_gridAnchorX / _gridStep) * _gridStep;
            } else if (delta <= -_gridStep) {
                // Moved left by at least one step
                let steps = Math.ceil(delta / _gridStep);   // negative
                _gridAnchorX += steps * _gridStep;
                _lastGridX = Math.round(_gridAnchorX / _gridStep) * _gridStep;
            }
            targetXVal = _lastGridX;
        }

        return targetXVal;
    }

    function applyGridAndSnapY(rawY, rawX) {
        let targetYVal = rawY;
        let canvas = findCanvas(root.parent);
        let snapped = false;

        if (Config.options.background.widgets.enableSnap ?? false) {
            if (_snapLockY) {
                if (Math.abs(rawY - _snapEntryY) < _snapExit) {
                    targetYVal = _snapLockYTarget;
                    if (isDragging && canvas) canvas.snapLineY = _snapLockYTarget;
                    snapped = true;
                } else {
                    _snapLockY = false;
                }
            }

            if (!snapped && widgetListModel) {
                for (let i = 0; i < widgetListModel.count; i++) {
                    let w = widgetListModel.get(i);
                    if (widgetInstance && w.instanceId === widgetInstance.id) continue;

                    let horizontallyClose = Math.abs(rawX - w.widgetX) < 600;
                    if (!horizontallyClose) continue;

                    let wId = w.instanceId || w.id;
                    let wHeight = (widgetSizes && widgetSizes[wId] && widgetSizes[wId].height > 0) ? widgetSizes[wId].height : root.height;

                    let hasCandidate = false;
                    let candidate = 0;
                    let lineY    = 0;
                    if (Math.abs(rawY - w.widgetY) < _snapEnter) {
                        candidate = w.widgetY; lineY = w.widgetY; hasCandidate = true;
                    } else if (Math.abs((rawY + root.height) - (w.widgetY + wHeight)) < _snapEnter) {
                        candidate = w.widgetY + wHeight - root.height; lineY = w.widgetY + wHeight; hasCandidate = true;
                    } else if (Math.abs(rawY - (w.widgetY + wHeight)) < _snapEnter) {
                        candidate = w.widgetY + wHeight; lineY = w.widgetY + wHeight; hasCandidate = true;
                    } else if (Math.abs((rawY + root.height) - w.widgetY) < _snapEnter) {
                        candidate = w.widgetY - root.height; lineY = w.widgetY; hasCandidate = true;
                    }

                    if (hasCandidate) {
                        targetYVal = candidate;
                        if (isDragging && canvas) canvas.snapLineY = lineY;
                        _snapLockY = true;
                        _snapLockYTarget = candidate;
                        _snapEntryY = rawY;
                        snapped = true;
                        break;
                    }
                }
            }
        }

        if (!snapped && canvas) canvas.snapLineY = -1;

        if (!snapped && (Config.options.background.widgets.enableGrid ?? false)) {
            let delta = rawY - _gridAnchorY;
            if (delta >= _gridStep) {
                let steps = Math.floor(delta / _gridStep);
                _gridAnchorY += steps * _gridStep;
                _lastGridY = Math.round(_gridAnchorY / _gridStep) * _gridStep;
            } else if (delta <= -_gridStep) {
                let steps = Math.ceil(delta / _gridStep);
                _gridAnchorY += steps * _gridStep;
                _lastGridY = Math.round(_gridAnchorY / _gridStep) * _gridStep;
            }
            targetYVal = _lastGridY;
        }

        return targetYVal;
    }

    draggable: !isPreview && !(Config.options.background.widgets.lockWidgetPositions ?? false) && (placementStrategy === "free" || placementStrategy === "draggable")
    // Use root directly as drag target — no proxy needed.
    // This eliminates the one-evaluation-pass lag of the proxy+Binding approach.
    drag.target: draggable ? root : undefined
    drag.minimumX: 0
    drag.maximumX: scaledScreenWidth - width
    drag.minimumY: 0
    drag.maximumY: scaledScreenHeight - height
    // Disable animation while dragging/settling so position is immediate
    animateXPos: !isDragging && !isDraggingOrSettling && (visibleWhenLocked || !GlobalStates.screenLocked)
    animateYPos: !isDragging && !isDraggingOrSettling && (visibleWhenLocked || !GlobalStates.screenLocked)
    onXChanged: {
        if (!isDragging || _applyingGridSnap) return;
        // Capture the drag-system's raw position before any transform
        _rawDragX = x;
        // Apply grid/snap using raw coordinates to prevent oscillation
        let snappedX = applyGridAndSnapX(_rawDragX, _rawDragY);
        if (snappedX !== x) {
            _applyingGridSnap = true;
            root.x = snappedX;
            _applyingGridSnap = false;
        }
    }
    onYChanged: {
        if (!isDragging || _applyingGridSnap) return;
        // Capture the drag-system's raw position before any transform
        _rawDragY = y;
        // Apply grid/snap using raw coordinates to prevent oscillation
        let snappedY = applyGridAndSnapY(_rawDragY, _rawDragX);
        if (snappedY !== y) {
            _applyingGridSnap = true;
            root.y = snappedY;
            _applyingGridSnap = false;
        }
    }
    onReleased: {
        if (isPreview) return;
        // Final snap/grid on release using the last known raw position
        let finalX = applyGridAndSnapX(_rawDragX, _rawDragY);
        let finalY = applyGridAndSnapY(_rawDragY, _rawDragX);
        root.x = finalX;
        root.y = finalY;

        let canvas = findCanvas(root.parent);
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
        settleTimer.restart();
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

