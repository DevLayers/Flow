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
    required property var overviewController
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
    property bool legacyGnomeZoomedOut: false

    // Smoothly center parallax during overview opening to ensure zoom-out presets
    // never expose black screen edges at extreme workspace positions.
    readonly property real effectiveParallaxX: {
        if (videoEffectsDisabled || !overviewController.useWallpaperParallax)
            return 0;
        if (overviewController && overviewController.progress > 0.001)
            return parallaxX + (wallpaperPlanes.centeredX - parallaxX) * overviewController.progress;
        return parallaxX;
    }
    readonly property real effectiveParallaxY: {
        if (videoEffectsDisabled || !overviewController.useWallpaperParallax)
            return 0;
        if (overviewController && overviewController.progress > 0.001)
            return parallaxY + (wallpaperPlanes.centeredY - parallaxY) * overviewController.progress;
        return parallaxY;
    }

    required property bool anyWidgetIsDragging
    required property bool mediaModeOpen
    property bool lockAnimationActive: false
    required property bool hasWindowsInActiveWorkspace
    required property var widgetStateManager

    // Output aliases
    property alias wallpaperItem: wallpaper
    property alias clipRectItem: centralWallpaperClipRect

    // Calculations
    readonly property bool overviewOpen: GlobalStates.overviewOpen
    readonly property bool overviewBackgroundActive: overviewController && overviewController.active
    readonly property bool overviewAnimationVisible: overviewController && (overviewController.active || overviewController.progress > 0.001)
    readonly property real overviewCoverScale: overviewController.overviewCoverScale
    readonly property bool isGnomeLikeOverview: overviewController.isGnomeLike

    // Keep the legacy opening scale available for Gnome-like while the modern
    // presets remain driven exclusively by OverviewBackgroundController.
    readonly property bool isScrollingLayout: Persistent.states.hyprland.layout === "scrolling"
    readonly property bool zoomInStyle: !videoEffectsDisabled && Config.options.overview.scrollingStyle.zoomStyle === "in"
    readonly property bool showOpeningAnimation: Config.options.overview.showOpeningAnimation
    readonly property var zoomLevels: ({
        "in": { default: 1.04, zoomed: 1 },
        "out": { default: 1, zoomed: 1.01 }
    })
    readonly property real defaultRatio: zoomInStyle ? zoomLevels.in.default : zoomLevels.out.default
    readonly property real zoomedRatio: zoomInStyle ? zoomLevels.in.zoomed : zoomLevels.out.zoomed

    // The overview controller owns the only background scale animation. Keeping
    // this item at unit scale prevents the scrolling overview's legacy scale
    // from multiplying it a second time.
    scale: isGnomeLikeOverview
        ? (!videoEffectsDisabled && showOpeningAnimation && overviewOpen && isScrollingLayout ? zoomedRatio : defaultRatio)
        : 1.0
    opacity: mediaModeOpen ? 0 : 1

    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(wallpaperImageRoot)
    }

    // --- Overview backing (only styles that need exposed area fill) ---
    TransitionImage {
        id: overviewBackingImage
        anchors.fill: parent
        imageSource: (wallpaperImageRoot.overviewController.isGnomeLike
            ? (!wallpaperSafetyTriggered ? wallpaperPath : "")
            : (wallpaperImageRoot.overviewController.useBackingImage && wallpaperImageRoot.overviewAnimationVisible && !wallpaperSafetyTriggered ? wallpaperPath : ""))
        animated: Config.options.background.animateWallpaperChanges
        fillMode: Image.PreserveAspectCrop
        visible: (wallpaperImageRoot.overviewController.isGnomeLike
            ? !wallpaperSafetyTriggered
            : wallpaperImageRoot.overviewController.useBackingImage && wallpaperImageRoot.overviewAnimationVisible && !wallpaperSafetyTriggered)
            && !wallpaperIsVideo && !Config.options.background.useWallpaperEngine
        opacity: 1.0
        mipmap: false
        antialiasing: false
        // The original blurred backings use a reduced source because they do
        // not need the detail budget of the central wallpaper plane.
        sourceSize: wallpaperImageRoot.overviewController.useBackingBlur
            ? Qt.size(screen.width > 0 ? Math.round(screen.width / 8) : 240, screen.height > 0 ? Math.round(screen.height / 8) : 135)
            : (Config.options.background.scaleLargeWallpapers
                ? Qt.size(screen.width > 0 ? Math.round(screen.width * preferredWallpaperScale) : 1920, screen.height > 0 ? Math.round(screen.height * preferredWallpaperScale) : 1080)
                : Qt.size(-1, -1))
        lockAnimationActive: wallpaperImageRoot.lockAnimationActive
    }

    Loader {
        id: overviewBackingBlurLoader
        anchors.fill: overviewBackingImage
        // GPU: only instantiate MultiEffect when zoomed-out state is active.
        // Previously always-loaded (active:true) with opacity controlling visibility —
        // the shader + texture stayed resident on GPU even at idle.
        active: (wallpaperImageRoot.overviewController.isGnomeLike
            ? wallpaperImageRoot.overviewController.active
            : wallpaperImageRoot.overviewController.useBackingBlur && wallpaperImageRoot.overviewAnimationVisible)
            && !wallpaperImageRoot.videoEffectsDisabled
        opacity: ((wallpaperImageRoot.overviewController.isGnomeLike
            ? wallpaperImageRoot.overviewController.active
            : wallpaperImageRoot.overviewController.useBackingBlur && wallpaperImageRoot.overviewAnimationVisible)
            && !wallpaperImageRoot.videoEffectsDisabled) ? 1.0 : 0.0
        Behavior on opacity {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(wallpaperImageRoot)
        }
        sourceComponent: MultiEffect {
            anchors.fill: parent
            source: overviewBackingImage
            blurEnabled: true
            blurMax: 75
            blur: wallpaperImageRoot.overviewController.isGnomeLike ? 0.7 : wallpaperImageRoot.overviewController.blurAmount

            Rectangle {
                anchors.fill: parent
                color: wallpaperImageRoot.overviewController.isGnomeLike ? "#000000" : Appearance.colors.colLayer0
                opacity: wallpaperImageRoot.overviewController.isGnomeLike ? 0.24 : wallpaperImageRoot.overviewController.dimAmount
            }
        }
    }

    Rectangle {
        id: overviewBackingDim
        anchors.fill: overviewBackingImage
        color: Appearance.colors.colLayer0
        visible: wallpaperImageRoot.overviewController.useBackingImage
            && !wallpaperImageRoot.overviewController.useBackingBlur
            && wallpaperImageRoot.overviewAnimationVisible
        opacity: wallpaperImageRoot.overviewController.dimAmount
    }

    Rectangle {
        id: materialShapeSolidBackdrop
        anchors.fill: parent
        color: Appearance.colors.colPrimaryContainer
        visible: wallpaperImageRoot.overviewController.isMaterialShape && wallpaperImageRoot.overviewAnimationVisible
        opacity: wallpaperImageRoot.overviewController.progress
    }

    property real wallpaperClipRadius: isGnomeLikeOverview
        ? (legacyGnomeZoomedOut ? Appearance.rounding.windowRounding : 0)
        : overviewController.cornerRadius
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

        Item {
            id: materialShapeMaskContainer
            x: 0
            y: 0
            width: screen.width
            height: screen.height
            visible: false
            layer.enabled: wallpaperImageRoot.overviewController.isMaterialShape && wallpaperImageRoot.overviewAnimationVisible

            MaterialShape {
                id: materialShapeMask
                anchors.centerIn: parent
                width: wallpaperImageRoot.overviewController.maskTargetDiameter
                height: wallpaperImageRoot.overviewController.maskTargetDiameter
                shapeString: wallpaperImageRoot.overviewController.currentMaterialShape
                color: "#ffffff"

                transform: [
                    Scale {
                        origin.x: materialShapeMask.width / 2
                        origin.y: materialShapeMask.height / 2
                        xScale: wallpaperImageRoot.overviewController.maskScale
                        yScale: wallpaperImageRoot.overviewController.maskScale
                    },
                    Rotation {
                        origin.x: materialShapeMask.width / 2
                        origin.y: materialShapeMask.height / 2
                        angle: wallpaperImageRoot.overviewController.maskRotation
                    }
                ]
            }
        }

        StyledRectangularShadow {
            id: centralWallpaperShadow
            target: centralWallpaperClipRect
            blur: 32 * scaleProgress
            offset: Qt.vector2d(0, 4 * scaleProgress)
            visible: wallpaperImageRoot.isGnomeLikeOverview
                ? wallpaperImageRoot.scaleProgress > 0.01
                : wallpaperImageRoot.overviewController.shadowAmount > 0.01
            opacity: scaleProgress
        }

        Rectangle {
            id: centralWallpaperClipRect
            x: 0
            y: 0
            width: screen.width
            height: screen.height
            color: "transparent"
            radius: wallpaperImageRoot.isGnomeLikeOverview
                ? wallpaperImageRoot.wallpaperClipRadius
                : wallpaperImageRoot.overviewController.cornerRadius
            clip: wallpaperImageRoot.isGnomeLikeOverview
                ? true
                : radius > 0
            border.color: wallpaperImageRoot.overviewController.isGnomeLike
                ? CF.ColorUtils.transparentize(Appearance.colors.colPrimary, 0.35)
                : "transparent"
            border.width: wallpaperImageRoot.overviewController.isGnomeLike
                ? 1.5 * wallpaperImageRoot.scaleProgress
                : 0

            layer.enabled: (radius > 0) || (wallpaperImageRoot.overviewController.isMaterialShape && wallpaperImageRoot.overviewAnimationVisible)
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: wallpaperImageRoot.overviewController.isMaterialShape ? materialShapeMaskContainer : centralClipMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0

                shadowEnabled: wallpaperImageRoot.overviewController.isMaterialShape && (Config.options.background.materialShapeShadow === true)
                shadowColor: "#000000"
                shadowBlur: 0.35
                shadowOpacity: 0.28
                shadowVerticalOffset: 3
                shadowHorizontalOffset: 0
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
                width: wallpaperPlanes.wallpaperW
                height: wallpaperPlanes.wallpaperH

                transform: [
                    Scale {
                        origin.x: wallpaperContent.width / 2
                        origin.y: wallpaperContent.height / 2
                        xScale: (baseWallpaperScale > 0 ? (effectiveWallpaperScale / baseWallpaperScale) : 1.0) * (wallpaperImageRoot.overviewController ? wallpaperImageRoot.overviewController.wallpaperContentScale : 1.0)
                        yScale: (baseWallpaperScale > 0 ? (effectiveWallpaperScale / baseWallpaperScale) : 1.0) * (wallpaperImageRoot.overviewController ? wallpaperImageRoot.overviewController.wallpaperContentScale : 1.0)
                    },
                    Translate {
                        id: parallaxTranslate
                        x: wallpaperImageRoot.overviewController.useWallpaperParallax ? wallpaperImageRoot.effectiveParallaxX : 0
                        y: wallpaperImageRoot.overviewController.useWallpaperParallax ? wallpaperImageRoot.effectiveParallaxY : 0
                        Behavior on x {
                            enabled: !wallpaperImageRoot.overviewAnimationVisible
                            NumberAnimation {
                                duration: Math.round(450 * Appearance.animMultiplier)
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on y {
                            enabled: !wallpaperImageRoot.overviewAnimationVisible
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
                    layer.enabled: wallpaperImageRoot.overviewController.useColorAdjustments
                    layer.effect: MultiEffect {
                        saturation: wallpaperImageRoot.overviewController.saturation - 1.0
                        brightness: wallpaperImageRoot.overviewController.brightness - 1.0
                    }

                    TransitionImage {
                        id: wallpaper
                        anchors.fill: parent

                        visible: opacity > 0
                        opacity: (wallpaper.status === Image.Ready && !Config.options.background.useWallpaperEngine && (!wallpaperIsVideo || (windowBlur && windowBlur.shouldBlur))) ? 1 : 0
                        // GPU: cap sourceSize to screen resolution with dynamic zoom headroom — loading > needed res wastes VRAM with no visual gain.
                        sourceSize: Config.options.background.scaleLargeWallpapers ? Qt.size(screen.width > 0 ? Math.round(screen.width * preferredWallpaperScale) : 1920, screen.height > 0 ? Math.round(screen.height * preferredWallpaperScale) : 1080) : Qt.size(-1, -1)

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

                        // GPU: same dynamic sourceSize cap as main wallpaper
                        sourceSize: Config.options.background.scaleLargeWallpapers ? Qt.size(screen.width > 0 ? Math.round(screen.width * preferredWallpaperScale) : 1920, screen.height > 0 ? Math.round(screen.height * preferredWallpaperScale) : 1080) : Qt.size(-1, -1)
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
                    id: overviewDimLayer
                    anchors.fill: parent
                    color: Appearance.colors.colLayer0
                    // Soft Focus owns the scene-wide dim through
                    // BlurOverlayWindow; applying it here as well made that
                    // preset darker and visually converge with the others.
                    opacity: wallpaperImageRoot.overviewController.isGnomeLike || wallpaperImageRoot.overviewController.useCompositorBlur
                        ? 0.0
                        : wallpaperImageRoot.overviewController.dimAmount
                    visible: opacity > 0.001
                }

                Rectangle {
                    id: wallpaperDimLayer
                    anchors.fill: parent
                    color: Appearance.colors.colLayer0
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
                    overviewProgress: wallpaperImageRoot.isGnomeLikeOverview
                        ? 0.0
                        : (wallpaperImageRoot.overviewController ? wallpaperImageRoot.overviewController.progress : 0.0)
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
