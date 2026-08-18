import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

import "../"

PopupWindow {
    id: previewPopup

    property var dockRoot: null
    property var appTopLevel: null
    property var dockWindow: null
    property Item anchorItem: null
    property bool compactMode: false

    readonly property bool isVertical: dockRoot?.isVertical ?? false
    readonly property string dockPos: dockRoot?.dockPos ?? dock.dockEffectivePosition
    
    readonly property int maxPreviews: {
        if (compactMode)
            return 1
        if (!dockWindow || !dockRoot) return 1

        const spacing = 6
        const previewSize = isVertical ? dockRoot.maxWindowPreviewHeight + dockRoot.windowControlsHeight : dockRoot.maxWindowPreviewWidth

        const availableSpace = isVertical ? (dockWindow.height ?? 1080) - popupBackground.margins * 2 - popupBackground.padding * 2 : (dockWindow.width ?? 1920) - popupBackground.margins * 2 - popupBackground.padding * 2
        return Math.max(1, Math.floor((availableSpace + spacing) / (previewSize + spacing)))
    }

    property bool show: false
    readonly property bool shouldShow:
        !dockRoot.dragging &&
        !dockRoot.anyContextMenuOpen &&
        (backgroundHover.hovered || dockRoot.buttonHovered || dockRoot.popupIsResizing) &&
        (appTopLevel?.toplevels?.length > 0)

    onShouldShowChanged: {
        if (shouldShow)
            show = true
        else if (dockRoot.anyContextMenuOpen)
            show = false
        else
            hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 150
        onTriggered: previewPopup.show = previewPopup.shouldShow
    }

    visible: show || popupBackground.opacity > 0
    color: "transparent"

    readonly property Item hoveredBtn: dockRoot?.lastHoveredButton ?? null
    readonly property real hoveredMagScale: (hoveredBtn && dockRoot) ? dockRoot._getSlotMagScale(hoveredBtn) : 1.0
    readonly property real hoveredScaleExtra: hoveredBtn ? (hoveredMagScale - 1.0) * (isVertical ? hoveredBtn.width : hoveredBtn.height) : 0
    // Keep the same small gap used by DockTooltip so both surfaces share the
    // exact same visual anchor above an app in the group popup.
    readonly property real compactAnchorGap: Appearance.sizes.elevationMargin

    function updateCompactAnchor() {
        if (!compactMode || !anchorItem || !dockWindow)
            return

        // PopupAnchor coordinate mapping is not reactive. Re-anchor after the
        // group popup has laid out the hovered delegate and after each hover
        // transition so the preview follows that delegate's real position.
        anchor.updateAnchor()
    }

    function requestCompactAnchor() {
        if (compactMode)
            compactAnchorTimer.restart()
    }

    Timer {
        id: compactAnchorTimer
        interval: 0
        repeat: false
        onTriggered: previewPopup.updateCompactAnchor()
    }

    onAnchorItemChanged: {
        if (compactMode)
            requestCompactAnchor()
    }

    onShowChanged: {
        if (show && compactMode)
            requestCompactAnchor()
    }

    anchor {
        // Group previews live inside DockGroupPopup's PopupWindow. The app
        // tile itself is not guaranteed to expose a QsWindow attached
        // property, so anchor to the host window supplied by the group.
        window: compactMode && anchorItem
            ? (anchorItem.QsWindow?.window ?? dockWindow)
            : dockWindow
        adjustment: PopupAdjustment.None
        edges: Edges.Top | Edges.Left

        onAnchoring: {
            if (!compactMode || !anchorItem)
                return

            const gap = compactAnchorGap
            // PopupWindow's implicit size also contains the compact preview's
            // transparent control/margin budget. Anchor the visible surface
            // instead; otherwise that unused height moves the preview much
            // farther away from the hovered app than the tooltip.
            const surfaceX = popupBackground.x
            const surfaceY = popupBackground.y
            const surfaceWidth = popupBackground.width || popupBackground.implicitWidth
            const surfaceHeight = popupBackground.height || popupBackground.implicitHeight
            const top = anchorItem.mapToItem(null, anchorItem.width / 2, 0)
            const bottom = anchorItem.mapToItem(null, anchorItem.width / 2, anchorItem.height)

            if (dockPos === "bottom") {
                anchor.rect.x = Math.round(top.x - surfaceX - surfaceWidth / 2)
                anchor.rect.y = Math.round(top.y - surfaceY - surfaceHeight - gap)
            } else if (dockPos === "top") {
                anchor.rect.x = Math.round(bottom.x - surfaceX - surfaceWidth / 2)
                anchor.rect.y = Math.round(bottom.y + gap - surfaceY)
            } else if (dockPos === "left") {
                const right = anchorItem.mapToItem(null, anchorItem.width, anchorItem.height / 2)
                anchor.rect.x = Math.round(right.x + gap - surfaceX)
                anchor.rect.y = Math.round(right.y - surfaceY - surfaceHeight / 2)
            } else {
                const left = anchorItem.mapToItem(null, 0, anchorItem.height / 2)
                anchor.rect.x = Math.round(left.x - surfaceX - surfaceWidth - gap)
                anchor.rect.y = Math.round(left.y - surfaceY - surfaceHeight / 2)
            }
        }

        rect {
            // Compact positions are assigned by onAnchoring. Keeping these
            // bindings at zero provides a safe initial value before the host
            // window is mapped for the first time.
            x: compactMode ? 0 : dockPos === "left" ? ((dockWindow?.width ?? 0) - (dockWindow?.magCrossExtra ?? 0) + hoveredScaleExtra) : (dockPos === "right" ? Math.max(0, (dockWindow?.magCrossExtra ?? 0) - hoveredScaleExtra) : 0)
            y: compactMode ? 0 : dockPos === "bottom" ? Math.max(0, (dockWindow?.magCrossExtra ?? 0) - hoveredScaleExtra) : dockPos === "top" ? ((dockWindow?.height ?? 0) - (dockWindow?.magCrossExtra ?? 0) + hoveredScaleExtra) : 0
        }

        gravity: {
            if (compactMode)
                return Edges.Bottom | Edges.Right
            if (dockPos === "left") return Edges.Right | Edges.Bottom
            if (dockPos === "right") return Edges.Left | Edges.Bottom
            if (dockPos === "top") return Edges.Bottom | Edges.Right
            return Edges.Top | Edges.Right
        }
    }

    // The group popup can move when the dock loses magnification after
    // the pointer leaves the dock tile. Recalculate the preview against
    // the host window instead of leaving it at the old screen position.
    Connections {
        target: previewPopup.anchorItem
        function onScaleChanged() { previewPopup.requestCompactAnchor() }
        function onXChanged() { previewPopup.requestCompactAnchor() }
        function onYChanged() { previewPopup.requestCompactAnchor() }
        function onWidthChanged() { previewPopup.requestCompactAnchor() }
        function onHeightChanged() { previewPopup.requestCompactAnchor() }
    }

    // dockRoot is either a DockContent (no hoveredAppButton) or a DockGroupPopup,
    // so one of these handlers is always unknown on the current target.
    Connections {
        target: previewPopup.dockRoot
        ignoreUnknownSignals: true
        function onLastHoveredButtonChanged() { previewPopup.requestCompactAnchor() }
        function onHoveredAppButtonChanged() { previewPopup.requestCompactAnchor() }
    }

    // Only non-null when dockRoot is a DockGroupPopup: follow the parent dock's hover state.
    Connections {
        target: previewPopup.dockRoot?.dockContent ?? null
        function onButtonHoveredChanged() { previewPopup.requestCompactAnchor() }
        function onHoveredSlotChanged() { previewPopup.requestCompactAnchor() }
        function onLastHoveredButtonChanged() { previewPopup.requestCompactAnchor() }
    }

    readonly property int _extra: popupBackground.padding * 2 + popupBackground.margins * 2

    implicitWidth: compactMode
        ? dockRoot.maxWindowPreviewWidth + (isVertical ? dockRoot.windowControlsHeight : 0) + _extra
        : isVertical ? dockRoot.maxWindowPreviewWidth + dockRoot.windowControlsHeight + _extra - 25 : dockWindow?.width ?? 0
    implicitHeight: compactMode
        ? dockRoot.maxWindowPreviewHeight + (isVertical ? 0 : dockRoot.windowControlsHeight) + _extra + 5
        : isVertical ? dockWindow?.height ?? 0 : dockRoot.maxWindowPreviewHeight + dockRoot.windowControlsHeight + _extra + 5

    StyledRectangularShadow {
        target: popupBackground
        opacity: popupBackground.opacity
        visible: popupBackground.visible
    }

    Rectangle {
        id: popupBackground

        property real margins: 5
        property real padding: 6

        onImplicitWidthChanged: {
            dockRoot.popupIsResizing = true
            resizeTimer.restart()
            previewPopup.requestCompactAnchor()
        }
        onImplicitHeightChanged: {
            dockRoot.popupIsResizing = true
            resizeTimer.restart()
            previewPopup.requestCompactAnchor()
        }

        Timer {
            id: resizeTimer
            interval: 500
            onTriggered: dockRoot.popupIsResizing = false
        }

        readonly property real _clampedX: Math.max(margins, Math.min(dockRoot.hoveredButtonCenter.x - implicitWidth  / 2, parent.width  - implicitWidth  - margins))
        readonly property real _clampedY: Math.max(margins, Math.min(dockRoot.hoveredButtonCenter.y - implicitHeight / 2, parent.height - implicitHeight - margins))
        x: compactMode ? margins : isVertical ? (dockPos === "left" ? margins : parent.width - implicitWidth - margins) : _clampedX
        y: compactMode ? margins : isVertical ? _clampedY : (dockPos === "top" ? margins : parent.height - implicitHeight - margins)

        opacity: previewPopup.show ? 1 : 0
        scale: previewPopup.show ? 1.0 : 0.90
        transformOrigin: {
            if (dockPos === "top") return Item.Top
            if (dockPos === "left") return Item.Left
            if (dockPos === "right") return Item.Right
            return Item.Bottom
        }

        visible: (appTopLevel?.toplevels?.length ?? 0) > 0
        clip: true
        color: Config.options.appearance.transparency.popups ? Appearance.colors.colLayer0 : Appearance.m3colors.m3surfaceContainer
        radius: (Config.options?.dock?.widgetRadius ?? -1) >= 0 ? Config.options.dock.widgetRadius : Appearance.rounding.normal
        implicitHeight: previewRowLayout.implicitHeight + padding * 2
        implicitWidth: previewRowLayout.implicitWidth + padding * 2

        layer.enabled: true
        layer.effect: FastBlur {
            radius: previewPopup.show ? 0 : 16
            Behavior on radius {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
        Behavior on implicitWidth {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on implicitHeight {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(previewPopup)
        }

        HoverHandler {
            id: backgroundHover
        }

        GridLayout {
            id: previewRowLayout
            anchors {
                top: parent.top
                left: parent.left
                topMargin: popupBackground.padding
                leftMargin: popupBackground.padding
            }
            flow: isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            columnSpacing: 6
            rowSpacing: 6

            Repeater {
                model: ScriptModel { values: (appTopLevel?.toplevels ?? []).slice(0, previewPopup.maxPreviews) }

                delegate: RippleButton {
                    id: windowButton
                    required property var modelData
                    padding: 0

                    onClicked: {
                        modelData?.activate()
                        dockRoot.buttonHovered = false
                        dockRoot.lastHoveredButton = null
                    }
                    middleClickAction: () => modelData?.close()

                    contentItem: ColumnLayout {
                        implicitWidth: screencopyView.implicitWidth
                        implicitHeight: screencopyView.implicitHeight

                        ButtonGroup {
                            contentWidth: parent.width - anchors.margins * 2

                            WrapperRectangle {
                                Layout.fillWidth: true
                                color: ColorUtils.transparentize(Appearance.colors.colSurfaceContainer)
                                radius: Appearance.rounding.small
                                margin: 5

                                StyledText {
                                    Layout.fillWidth: true
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    text: windowButton.modelData?.title ?? ""
                                    elide: Text.ElideRight
                                    color: Appearance.m3colors.m3onSurface
                                }
                            }

                            RippleButton {
                                id: closeButton
                                colBackground: ColorUtils.transparentize(Appearance.colors.colSurfaceContainer)
                                implicitWidth: dockRoot.windowControlsHeight
                                implicitHeight: dockRoot.windowControlsHeight
                                buttonRadius: Appearance.rounding.full

                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.m3colors.m3onSurface
                                }
                                onClicked: windowButton.modelData?.close()
                            }
                        }

                        ScreencopyView {
                            id: screencopyView
                            captureSource: previewPopup.visible ? windowButton.modelData : null
                            live: true
                            paintCursor: true
                            constraintSize: Qt.size(
                                dockRoot.maxWindowPreviewWidth,
                                dockRoot.maxWindowPreviewHeight
                            )
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: screencopyView.width
                                    height: screencopyView.height
                                    radius: Appearance.rounding.small
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
