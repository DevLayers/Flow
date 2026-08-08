import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

pragma ComponentBehavior: Bound

Scope {
    id: dock

    property bool pinned: Config.options?.dock.pinnedOnStartup ?? false

    readonly property string dockEffectivePosition: {
        const pos = Config.options?.dock.position ?? "bottom"
        if (pos !== "auto") return pos
        return (Config.options?.bar.bottom && !Config.options?.bar.vertical) ? "top" : "bottom"
    }

    readonly property bool isVertical: dockEffectivePosition === "left" || dockEffectivePosition === "right"

    function computeSizes(opts) {
        const gapsOut = opts.gapsOut
        const barConflicts = opts.barActive && (opts.isVertical !== opts.barIsVertical)
        
        const barOffset = barConflicts ? (opts.isVertical ? opts.barThickness : 0) : 0
        const barOffsetH = barConflicts ? (!opts.isVertical ? opts.barThickness : 0) : 0

        const maxW = Math.max(1, opts.availableW - gapsOut * 2 - barOffsetH)
        const maxH = Math.max(1, opts.availableH - gapsOut * 2 - barOffset)

        const contentW = opts.contentVisualWidth + opts.dockPadding * 2
        const contentH = opts.contentVisualHeight + opts.dockPadding * 2

        const magExtra = opts.magExtra || 0

        const bgW = Math.max(1, opts.isVertical ? contentW : Math.min(contentW, maxW - gapsOut * 2))
        const bgH = Math.max(1, opts.isVertical ? Math.min(contentH, maxH - gapsOut * 2) : contentH)

        const baseDockW = opts.isVertical ? contentW + gapsOut * 2 : Math.min(contentW + gapsOut * 2, maxW)
        const baseDockH = opts.isVertical ? Math.min(contentH + gapsOut * 2, maxH) : contentH + gapsOut * 2

        const fullDockW = Math.min(baseDockW + magExtra, maxW)
        const fullDockH = Math.min(baseDockH + magExtra, maxH)

        return {
            maxWidth: maxW,
            maxHeight: maxH,
            dockWidth: fullDockW,
            dockHeight: fullDockH,
            dockThickness: opts.isVertical ? fullDockW : fullDockH,
            unmagnifiedThickness: opts.isVertical ? baseDockW : baseDockH,
            backgroundWidth: bgW,
            backgroundHeight: bgH
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockRoot
            required property var modelData
            screen: modelData
            
            visible: !GlobalStates.screenLocked && !positionChanging && !GlobalStates.oledSaverMonitors.includes(modelData.name) && !GlobalStates.isMediaModeActiveForScreen(modelData ? modelData.name : "")
            // using a flag for positionChanging is not really necessary, but it prevents some graphical issues caused by qml when the dock is moving

            readonly property real availableW: screen?.width ?? 1920
            readonly property real availableH: screen?.height ?? 1080
            readonly property bool barActive: GlobalStates.barOpen
            readonly property bool barIsVertical: Config.options?.bar?.vertical ?? false
            readonly property real barThickness: barActive? (barIsVertical ? (Config.options?.bar?.sizes?.width ?? Appearance.sizes.verticalBarWidth) : (Config.options?.bar?.sizes?.height ?? Appearance.sizes.barHeight)) : 0

            readonly property bool enableMagnification: Config.options?.dock?.enableMagnification ?? false
            readonly property real magnificationScale: Config.options?.dock?.magnificationScale ?? 1.5
            readonly property real magExtra: enableMagnification ? Math.ceil((magnificationScale - 1.0) * ((isVertical ? dockContent.buttonSlotSize : dockContent.buttonSlotHeight) || Appearance.sizes.dockButtonSize)) : 0

            readonly property bool isVertical: dock.isVertical
            readonly property real dockThickness: dockRoot.sizing.dockThickness
            readonly property real unmagnifiedThickness: dockRoot.sizing.unmagnifiedThickness
            readonly property bool anySidebarOpen: GlobalStates.effectiveLeftOpen || GlobalStates.effectiveRightOpen

            readonly property bool isSpecialWorkspaceOpen: {
                if (!dockRoot.screen) return false;
                const monitor = HyprlandData.monitors.find(m => m.name === dockRoot.screen.name);
                if (!monitor || !monitor.specialWorkspace) return false;
                return monitor.specialWorkspace.name !== "";
            }

            property bool reveal: dock.pinned || (!anySidebarOpen && ((Config.options?.dock.hoverToReveal && dockMouseArea.containsMouse) || (dockContent.requestDockShow) || (workspaceEmpty && !isSpecialWorkspaceOpen && (!(Config.options?.dock.showOnlyOnFocusedMonitor ?? false) || isFocusedMonitor))))
            property bool positionChanging: false

            // TODO: check for multi-monitor situations
            readonly property bool workspaceEmpty: {
                const wsId = HyprlandData.activeWorkspace?.id ?? -1
                if (wsId === -1) return true
                return HyprlandData.hyprlandClientsForWorkspace(wsId).length === 0
            }

            readonly property bool isFocusedMonitor: {
                return (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "") === (dockRoot.screen ? dockRoot.screen.name : "")
            }

            readonly property var sizing: dock.computeSizes({
                gapsOut: Appearance.sizes.hyprlandGapsOut,
                isVertical: dock.isVertical,
                barActive: barActive,
                barIsVertical: barIsVertical,
                barThickness: barThickness,
                availableW: availableW,
                availableH: availableH,
                contentVisualWidth: dockContent.visualWidth,
                contentVisualHeight: dockContent.visualHeight,
                dockPadding: dockContent.dockPadding,
                magExtra: dockRoot.magExtra
            })

            implicitWidth: Math.max(1, dockRoot.sizing.dockWidth)
            implicitHeight: Math.max(1, dockRoot.sizing.dockHeight)

            anchors {
                top: dock.dockEffectivePosition !== "bottom"
                bottom: dock.dockEffectivePosition !== "top"
                left: dock.dockEffectivePosition !== "right"
                right: dock.dockEffectivePosition !== "left"
            }

            exclusiveZone: (dock.pinned && reveal) ? unmagnifiedThickness : 0
            WlrLayershell.namespace: "quickshell:dock"
            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"

            mask: Region {
                item: dockMouseArea
            }

            Timer {
                id: positionChangeTimer
                interval: 200
                onTriggered: dockRoot.positionChanging = false
            }

            Connections {
                target: dock
                function onDockEffectivePositionChanged() {
                    dockRoot.positionChanging = true
                    positionChangeTimer.restart()
                }
            }

            HyprlandFocusGrab {
                id: dragFocusGrab
                active: dockContent.dragging
                windows: [dockRoot]
                onCleared: {
                    dockContent.cancelDrag()
                }
            }

            MouseArea {
                id: dockMouseArea
                hoverEnabled: true

                property real hiddenOffset: dockRoot.dockThickness - (Config.options?.dock.hoverRegionHeight ?? 10)
                property real fullyHiddenOffset: dockRoot.dockThickness + 1
                property real currentOffset: dockRoot.reveal ? 0 : (Config.options?.dock.hoverToReveal ? hiddenOffset : fullyHiddenOffset)

                width: dock.isVertical ? dockRoot.dockThickness : dockRoot.sizing.dockWidth
                height: dock.isVertical ? dockRoot.sizing.dockHeight : dockRoot.dockThickness

                state: dock.dockEffectivePosition

                states: [
                    State {
                        name: "top"
                        AnchorChanges { target: dockMouseArea; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter }
                        PropertyChanges { target: dockMouseArea; anchors.topMargin: -currentOffset }
                    },
                    State {
                        name: "bottom"
                        AnchorChanges { target: dockMouseArea; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
                        PropertyChanges { target: dockMouseArea; anchors.bottomMargin: -currentOffset }
                    },
                    State {
                        name: "left"
                        AnchorChanges { target: dockMouseArea; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        PropertyChanges { target: dockMouseArea; anchors.leftMargin: -currentOffset }
                    },
                    State {
                        name: "right"
                        AnchorChanges { target: dockMouseArea; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
                        PropertyChanges { target: dockMouseArea; anchors.rightMargin: -currentOffset }
                    }
                ]

                Behavior on anchors.topMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.bottomMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.leftMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.rightMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }

                StyledRectangularShadow { target: dockVisualBackground }

                Rectangle {
                    id: dockVisualBackground

                    width: dockRoot.sizing.backgroundWidth
                    height: dockRoot.sizing.backgroundHeight

                    color: Appearance.colors.colLayer0
                    radius: (Config.options?.dock?.dockRadius ?? -1) >= 0 ? Config.options.dock.dockRadius : (Appearance.rounding.windowRounding + 12)

                    anchors.horizontalCenter: (!dock.isVertical) ? parent.horizontalCenter : undefined
                    anchors.verticalCenter: dock.isVertical ? parent.verticalCenter : undefined

                    anchors.bottom: dock.dockEffectivePosition === "bottom" ? parent.bottom : undefined
                    anchors.bottomMargin: dock.dockEffectivePosition === "bottom" ? Appearance.sizes.hyprlandGapsOut : 0

                    anchors.top: dock.dockEffectivePosition === "top" ? parent.top : undefined
                    anchors.topMargin: dock.dockEffectivePosition === "top" ? Appearance.sizes.hyprlandGapsOut : 0

                    anchors.left: dock.dockEffectivePosition === "left" ? parent.left : undefined
                    anchors.leftMargin: dock.dockEffectivePosition === "left" ? Appearance.sizes.hyprlandGapsOut : 0

                    anchors.right: dock.dockEffectivePosition === "right" ? parent.right : undefined
                    anchors.rightMargin: dock.dockEffectivePosition === "right" ? Appearance.sizes.hyprlandGapsOut : 0

                    DropArea {
                        id: fileDropArea
                        anchors.fill: parent
                        keys: ["text/uri-list"]

                        // We delay the re-enablement slightly after an internal drag ends
                        // to prevent the "exited" event from firing for the internal drag.
                        property bool blockDueToInternal: dockContent.dragging
                        onBlockDueToInternalChanged: {
                            if (!blockDueToInternal) {
                                reEnableTimer.restart()
                            } else {
                                enabled = false
                            }
                        }

                        Timer {
                            id: reEnableTimer
                            interval: 50
                            onTriggered: fileDropArea.enabled = true
                        }

                        onEntered: (drag) => {
                            if (!drag.hasUrls) return
                            //console.log("[Dock] External drag entered")
                            const url = drag.urls[0]?.toString() ?? ""
                            dockContent.externalDragIcon = dockContent.mimeIconFromPath(url)
                            dockContent.externalDragOver = true
                        }
                        onExited: {
                            //console.log("[Dock] External drag exited")
                            dockContent.externalDragIcon = ""
                            dockContent.externalDragOver = false
                        }
                        onDropped: (drop) => {
                            if (!drop.hasUrls) return
                            //console.log("[Dock] External drag dropped")
                            for (let i = 0; i < drop.urls.length; i++)
                                TaskbarApps.addPinnedFile(drop.urls[i])
                            drop.accept(Qt.CopyAction)
                            dockContent.externalDragIcon = ""
                            dockContent.externalDragOver = false
                        }
                    }

                    DockContent {
                        id: dockContent
                        anchors.fill: parent
                        isPinned: dock.pinned
                        currentScreen: dockRoot.screen
                        onTogglePinRequested: {
                            dock.pinned = !dock.pinned
                        }
                    }
                }
            }
        }
    }
}