import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import qs.modules.ii.background.blur
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

Item {
    id: wallpaperImageRoot
    anchors.fill: parent

    // Required inputs
    required property var screen
    required property string wallpaperPath
    property string lockscreenWallpaperPath: ""
    property bool useSeparateLockscreenWallpaper: false
    required property bool wallpaperIsVideo
    required property bool wallpaperSafetyTriggered
    required property real preferredWallpaperScale
    required property real effectiveWallpaperScale
    required property real baseWallpaperScale
    required property int wallpaperWidth
    required property int wallpaperHeight
    required property real wallpaperToScreenRatio
    required property real movableXSpace
    required property real movableYSpace
    required property real minSafeScale
    readonly property bool videoEffectsDisabled: wallpaperIsVideo || Config.options.background.useWallpaperEngine

    required property real parallaxX
    required property real parallaxY
    property real effectiveValueX: 0.5
    property real effectiveValueY: 0.5
    required property real scaleValue
    required property real scaleOriginX
    required property real scaleOriginY
    required property real scaleProgress

    readonly property real effectiveParallaxX: videoEffectsDisabled ? 0 : (wallpaperZoomedOut ? wallpaperPlanes.centeredX : parallaxX)
    readonly property real effectiveParallaxY: videoEffectsDisabled ? 0 : (wallpaperZoomedOut ? wallpaperPlanes.centeredY : parallaxY)

    required property bool anyWidgetIsDragging
    required property bool mediaModeOpen
    property bool lockAnimationActive: false
    required property bool hasWindowsInActiveWorkspace
    required property var widgetStateManager

    // Output aliases
    property alias wallpaperItem: wallpaper
    property alias clipRectItem: centralWallpaperClipRect

    // Calculations
    readonly property bool isScrollingLayout: Persistent.states.hyprland.layout === "scrolling"
    readonly property bool zoomInStyle: !videoEffectsDisabled && Config.options.overview.scrollingStyle.zoomStyle === "in"
    readonly property bool showOpeningAnimation: Config.options.overview.showOpeningAnimation
    readonly property bool overviewOpen: GlobalStates.overviewOpen

    readonly property var zoomLevels: ({
            "in": {
                default: 1.04,
                zoomed: 1
            },
            "out": {
                default: 1,
                zoomed: 1.01
            }
        })

    readonly property real defaultRatio: zoomInStyle ? zoomLevels.in.default : zoomLevels.out.default
    readonly property real zoomedRatio: zoomInStyle ? zoomLevels.in.zoomed : zoomLevels.out.zoomed

    property real scaleAnimated: !videoEffectsDisabled && overviewOpen && showOpeningAnimation ? zoomedRatio : defaultRatio
    Behavior on scaleAnimated {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(wallpaperImageRoot)
    }

    scale: !videoEffectsDisabled && showOpeningAnimation && overviewOpen && isScrollingLayout ? zoomedRatio : defaultRatio
    opacity: mediaModeOpen ? 0 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: 300
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on scale {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(wallpaperImageRoot)
    }

    // --- STYLE 0/1: Blurred backing ---
    TransitionImage {
        id: bgWallpaperBlurred
        anchors.fill: parent
        imageSource: !wallpaperSafetyTriggered ? wallpaperPath : ""
        animated: Config.options.background.animateWallpaperChanges
        fillMode: Image.PreserveAspectCrop
        visible: Config.options.background.zoomOutStyle !== 2 && !wallpaperSafetyTriggered && !wallpaperIsVideo && !Config.options.background.useWallpaperEngine
        opacity: 1.0
        mipmap: false
        antialiasing: false
        // GPU: /8 instead of /4 — blurred backing needs no detail; saves ~75% VRAM for this texture in 4K
        sourceSize: Qt.size(screen.width > 0 ? Math.round(screen.width / 8) : 240, screen.height > 0 ? Math.round(screen.height / 8) : 135)
        lockAnimationActive: wallpaperImageRoot.lockAnimationActive
    }

    Loader {
        id: bgWallpaperBlurLoader
        anchors.fill: bgWallpaperBlurred
        // GPU: only instantiate MultiEffect when zoomed-out state is active.
        // Previously always-loaded (active:true) with opacity controlling visibility —
        // the shader + texture stayed resident on GPU even at idle.
        active: wallpaperImageRoot.wallpaperZoomedOut && !wallpaperImageRoot.videoEffectsDisabled
        opacity: wallpaperImageRoot.wallpaperZoomedOut && !wallpaperImageRoot.videoEffectsDisabled ? 1.0 : 0.0
        Behavior on opacity {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(wallpaperImageRoot)
        }
        sourceComponent: MultiEffect {
            anchors.fill: parent
            source: bgWallpaperBlurred
            blurEnabled: true
            blurMax: 75
            blur: 0.7

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.24
            }
        }
    }

    readonly property bool scratchpadOpen: {
        if (!HyprlandData.monitors)
            return false;
        return HyprlandData.monitors.some(function (mon) {
            return mon.specialWorkspace && mon.specialWorkspace.name !== "";
        });
    }
    readonly property bool wallpaperZoomedOut: Config.options.background.zoomOutEnabled && (GlobalStates.cheatsheetOpen || GlobalStates.overviewOpen || scratchpadOpen) && (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name == screen.name : false)

    property real wallpaperClipRadius: wallpaperZoomedOut ? Appearance.rounding.windowRounding : 0
    Behavior on wallpaperClipRadius {
        animation: Appearance.animation.elementMove.numberAnimation.createObject(wallpaperImageRoot)
    }

    // Wallpaper planes: scale zoom-out.
    Item {
        id: wallpaperPlanes
        anchors.fill: parent

        readonly property real wallpaperW: wallpaperWidth / wallpaperToScreenRatio * baseWallpaperScale
        readonly property real wallpaperH: wallpaperHeight / wallpaperToScreenRatio * baseWallpaperScale
        readonly property real centeredX: -movableXSpace
        readonly property real centeredY: -movableYSpace

        transform: Scale {
            origin.x: scaleOriginX
            origin.y: scaleOriginY
            xScale: scaleValue
            yScale: scaleValue
        }

        Rectangle {
            id: centralClipMask
            x: 0
            y: 0
            width: centralWallpaperClipRect.width
            height: centralWallpaperClipRect.height
            radius: centralWallpaperClipRect.radius
            visible: false
            layer.enabled: centralWallpaperClipRect.layer.enabled
        }

        StyledRectangularShadow {
            id: centralWallpaperShadow
            target: centralWallpaperClipRect
            blur: 32 * scaleProgress
            offset: Qt.vector2d(0, 4 * scaleProgress)
            visible: Config.options.background.zoomOutStyle === 0 && scaleProgress > 0.01
            opacity: scaleProgress
        }

        Rectangle {
            id: centralWallpaperClipRect
            x: Config.options.background.zoomOutStyle !== 1 ? 0 : parallaxX
            y: Config.options.background.zoomOutStyle !== 1 ? 0 : parallaxY
            width: Config.options.background.zoomOutStyle !== 1 ? screen.width : wallpaperPlanes.wallpaperW
            height: Config.options.background.zoomOutStyle !== 1 ? screen.height : wallpaperPlanes.wallpaperH
            color: "transparent"
            radius: Config.options.background.zoomOutStyle === 0 ? wallpaperImageRoot.wallpaperClipRadius : 0
            clip: Config.options.background.zoomOutStyle !== 1
            border.color: CF.ColorUtils.transparentize(Appearance.colors.colPrimary, 0.35)
            border.width: 1.5 * scaleProgress

            layer.enabled: radius > 0
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: centralClipMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Behavior on x {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(wallpaperImageRoot)
            }
            Behavior on y {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(wallpaperImageRoot)
            }
            Behavior on width {
                enabled: !wallpaperImageRoot.lockAnimationActive
                NumberAnimation {
                    duration: 600
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                enabled: !wallpaperImageRoot.lockAnimationActive
                NumberAnimation {
                    duration: 600
                    easing.type: Easing.OutCubic
                }
            }

            Item {
                id: wallpaperContent
                // GPU: only enable offscreen layer when effects that need it are actually active.
                // Disabling this offscreen layer when idle saves ~70% GPU usage on 4K monitors.
                layer.enabled: wallpaperImageRoot.lockAnimationActive || GlobalStates.screenLocked || wallpaperImageRoot.wallpaperClipRadius > 0
                width: Config.options.background.zoomOutStyle !== 1 ? wallpaperPlanes.wallpaperW : parent.width
                height: Config.options.background.zoomOutStyle !== 1 ? wallpaperPlanes.wallpaperH : parent.height

                transform: [
                    Scale {
                        origin.x: wallpaperContent.width / 2
                        origin.y: wallpaperContent.height / 2
                        xScale: baseWallpaperScale > 0 ? (effectiveWallpaperScale / baseWallpaperScale) : 1.0
                        yScale: baseWallpaperScale > 0 ? (effectiveWallpaperScale / baseWallpaperScale) : 1.0
                    },
                    Translate {
                        id: parallaxTranslate
                        x: Config.options.background.zoomOutStyle === 1 ? 0 : wallpaperImageRoot.effectiveParallaxX
                        y: Config.options.background.zoomOutStyle === 1 ? 0 : wallpaperImageRoot.effectiveParallaxY
                        Behavior on x {
                            NumberAnimation {
                                duration: Math.round(450 * Appearance.animMultiplier)
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on y {
                            NumberAnimation {
                                duration: Math.round(450 * Appearance.animMultiplier)
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                ]

                Item {
                    id: wallpaperVisualContainer
                    anchors.fill: parent

                    TransitionImage {
                        id: wallpaper
                        anchors.fill: parent

                        visible: opacity > 0
                        opacity: (wallpaper.status === Image.Ready && !Config.options.background.useWallpaperEngine && (!wallpaperIsVideo || (windowBlur && windowBlur.shouldBlur))) ? 1 : 0
                        // GPU: cap sourceSize to screen resolution — loading > native res wastes VRAM with no visual gain.
                        // Clamp to max 110% of screen (enough for parallax headroom).
                        sourceSize: Config.options.background.scaleLargeWallpapers ? Qt.size(screen.width > 0 ? Math.min(Math.round(screen.width * preferredWallpaperScale), Math.round(screen.width * 1.1)) : 1920, screen.height > 0 ? Math.min(Math.round(screen.height * preferredWallpaperScale), Math.round(screen.height * 1.1)) : 1080) : Qt.size(-1, -1)

                        imageSource: wallpaperSafetyTriggered ? "" : wallpaperPath
                        animated: Config.options.background.animateWallpaperChanges
                        transitionShader: Config.options.background.wallpaperAnimation
                        shadersPath: Qt.resolvedUrl("../shaders")
                        fillMode: Image.PreserveAspectCrop
                        // GPU: mipmap:false — mip-chain generation on GPU is wasteful for a full-screen image.
                        // The image is displayed at near-native size; mipmaps provide no quality benefit here.
                        mipmap: false
                        antialiasing: false
                        lockAnimationActive: wallpaperImageRoot.lockAnimationActive
                    }

                    TransitionImage {
                        id: lockscreenWallpaper
                        anchors.fill: parent

                        readonly property bool isActive: wallpaperImageRoot.useSeparateLockscreenWallpaper && wallpaperImageRoot.lockscreenWallpaperPath !== "" && wallpaperImageRoot.lockscreenWallpaperPath !== wallpaperImageRoot.wallpaperPath
                        visible: isActive && opacity > 0
                        opacity: (isActive && GlobalStates.screenLocked) ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Math.round(750 * Appearance.animMultiplier)
                                easing.type: Easing.InOutCubic
                            }
                        }

                        // GPU: same sourceSize cap as main wallpaper
                        sourceSize: Config.options.background.scaleLargeWallpapers ? Qt.size(screen.width > 0 ? Math.min(Math.round(screen.width * preferredWallpaperScale), Math.round(screen.width * 1.1)) : 1920, screen.height > 0 ? Math.min(Math.round(screen.height * preferredWallpaperScale), Math.round(screen.height * 1.1)) : 1080) : Qt.size(-1, -1)
                        imageSource: (isActive && !wallpaperSafetyTriggered) ? wallpaperImageRoot.lockscreenWallpaperPath : ""
                        animated: Config.options.background.animateWallpaperChanges
                        transitionShader: Config.options.background.wallpaperAnimation
                        shadersPath: Qt.resolvedUrl("../shaders")
                        fillMode: Image.PreserveAspectCrop
                        mipmap: false
                        antialiasing: false
                        lockAnimationActive: wallpaperImageRoot.lockAnimationActive
                    }
                }

                Rectangle {
                    id: wallpaperDimLayer
                    anchors.fill: parent
                    color: "black"
                    opacity: anyWidgetIsDragging ? 0.45 : 0.0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 350
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                LockBlur {
                    id: lockBlur
                    anchors.fill: parent
                    sourceItem: wallpaperVisualContainer
                    baseScale: wallpaperImageRoot.baseWallpaperScale
                    lockAnimationActive: wallpaperImageRoot.lockAnimationActive
                    wallpaperIsVideo: wallpaperImageRoot.wallpaperIsVideo || Config.options.background.useWallpaperEngine
                }

                LockDesaturate {
                    anchors.fill: parent
                    sourceItem: Config.options.lock.blur.enable ? lockBlur : wallpaperVisualContainer
                    baseScale: wallpaperImageRoot.baseWallpaperScale
                    lockAnimationActive: wallpaperImageRoot.lockAnimationActive
                }

                LockColorWash {
                    anchors.fill: parent
                    sourceItem: wallpaperVisualContainer
                    baseScale: wallpaperImageRoot.baseWallpaperScale
                    lockAnimationActive: wallpaperImageRoot.lockAnimationActive
                }

                LockVignette {
                    anchors.fill: parent
                    sourceItem: wallpaperVisualContainer
                    baseScale: wallpaperImageRoot.baseWallpaperScale
                    lockAnimationActive: wallpaperImageRoot.lockAnimationActive
                }

                WindowBlur {
                    id: windowBlur
                    anchors.fill: parent
                    sourceItem: wallpaperVisualContainer
                    hasWindowsInActiveWorkspace: wallpaperImageRoot.hasWindowsInActiveWorkspace
                    overviewOpen: wallpaperImageRoot.overviewOpen
                }
            }
        }

        BarGradientOverlay {
            sourceItem: wallpaperVisualContainer
            parallaxX: wallpaperImageRoot.effectiveParallaxX
            parallaxY: wallpaperImageRoot.effectiveParallaxY
            screenWidth: wallpaperImageRoot.screen.width
            screenHeight: wallpaperImageRoot.screen.height
        }
    }
}
