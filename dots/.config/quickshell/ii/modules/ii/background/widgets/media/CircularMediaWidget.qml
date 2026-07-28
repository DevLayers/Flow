import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes as Shapes
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "circular_media"

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "center" || root.lockBehavior === "lockOnly" || (Config.options.lock.centerWidget === "media")

    // Default size is 240x240 base scaled by widgetSize
    readonly property real contentScale: (Config.options.background.widgets.circular_media.widgetSize ?? 100) / 100.0
    implicitWidth: 240 * contentScale
    implicitHeight: 240 * contentScale

    // ── Config visibility toggles ──
    readonly property bool cfgShowPrevBtn: Config.ready ? (Config.options.background.widgets.circular_media.showPrevButton ?? true) : true
    readonly property bool cfgShowNextBtn: Config.ready ? (Config.options.background.widgets.circular_media.showNextButton ?? true) : true
    readonly property bool cfgShowDevicePill: Config.ready ? (Config.options.background.widgets.circular_media.showDevicePill ?? true) : true

    readonly property bool useAlbumColors: Config.ready ? (Config.options.background.widgets.circular_media.useAlbumColors ?? true) : true
    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool playing: player ? player.playbackState === MprisPlaybackState.Playing : false
    readonly property string artUrl: MprisController.artUrl
    readonly property string trackTitle: StringUtils.cleanMusicTitle(player?.trackTitle) || Translation.tr("No media")
    readonly property string trackArtist: player?.trackArtist || Translation.tr("Unknown Artist")

    property bool isLocalArt: artUrl.startsWith("file://")
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property bool artDownloaded: false

    readonly property string artSource: {
        if (!artUrl)
            return "";
        if (isLocalArt)
            return artUrl;
        return artDownloaded ? Qt.resolvedUrl(artFilePath) : "";
    }

    onArtFilePathChanged: {
        if (!artUrl || artUrl.length === 0) {
            artDownloaded = false;
            return;
        }
        if (isLocalArt) {
            artDownloaded = true;
            return;
        }
        artDownloader.targetFile = artUrl;
        artDownloader.artFilePath = artFilePath;
        artDownloader.artTempPath = artFilePath + ".tmp";
        artDownloaded = false;
        artDownloader.running = true;
    }

    Process {
        id: artDownloader
        property string targetFile: root.artUrl
        property string artFilePath: root.artFilePath
        property string artTempPath: root.artFilePath + ".tmp"
        command: ["bash", "-c", `[ -f ${artFilePath} ] || (curl -4 -sSL '${targetFile}' -o '${artTempPath}' && mv '${artTempPath}' '${artFilePath}')`]
        onExited: {
            artDownloaded = true;
        }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.artSource
        depth: 0
        rescaleSize: 1
    }

    readonly property color artDominantColor: {
        if (!root.useDynamicColors) return Appearance.colors.colPrimary;
        let raw = colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary;
        let mixed = ColorUtils.mix(raw, Appearance.colors.colPrimaryContainer, 0.8);
        return mixed || Appearance.m3colors.m3secondaryContainer;
    }

    property QtObject blendedColors: AdaptedMaterialScheme {
        color: root.artDominantColor
    }

    readonly property bool useDynamicColors: root.useAlbumColors && root.artSource !== ""

    // Vibrant button coloring using only colPrimary, colOnPrimary, and colPrimaryContainer
    readonly property color activeAccentColor: root.useDynamicColors ? blendedColors.colPrimary : Appearance.colors.colPrimary
    readonly property color activeAccentContainer: root.useDynamicColors ? blendedColors.colPrimaryContainer : Appearance.colors.colPrimaryContainer
    readonly property color activeOnPrimary: root.useDynamicColors ? blendedColors.colOnPrimary : Appearance.colors.colOnPrimary

    // Text colors are blended with white (neutral tinting) to prevent extremely vibrant/hard-to-read text, matching reference watch displays
    readonly property color activeTextColor: root.useDynamicColors ? ColorUtils.mix("#FFFFFF", root.artDominantColor, 0.90) : Appearance.colors.colOnSurface
    readonly property color activeSubtextColor: root.useDynamicColors ? ColorUtils.mix("#FFFFFF", root.artDominantColor, 0.80) : Appearance.colors.colOnSurfaceVariant

    // Trigger position updates for the progress bar
    Timer {
        running: root.playing
        interval: Config.options.resources.updateInterval ?? 1000
        repeat: true
        onTriggered: {
            if (root.player) {
                root.player.positionChanged();
            }
        }
    }

    readonly property real progressValue: {
        if (!root.player || root.player.length <= 0)
            return 0.0;
        return Math.max(0.0, Math.min(1.0, root.player.position / root.player.length));
    }

    // Outer bezel shadow support
    StyledDropShadow {
        target: bezelRing
        visible: Config.options.background.widgets.circular_media.enableShadows ?? true
    }

    // Outer Bezel Ring (Moldura) using opaque solid colBackgroundSurfaceContainer base
    Rectangle {
        id: bezelRing
        anchors.fill: parent
        radius: width / 2
        color: Appearance.m3colors.m3shadow // Opaque base to prevent transparency leaks

        // Inner Screen Container
        Rectangle {
            id: innerScreen
            anchors.fill: parent
            anchors.margins: parent.width * 0.08 // 8% bezel thickness
            radius: width / 2
            color: Appearance.m3colors.m3shadow

                // Album Art with a light GPU blur + circular mask
                Image {
                    id: albumArtImage
                    anchors.fill: parent
                    source: root.artSource
                    fillMode: Image.PreserveAspectCrop
                    visible: root.artSource !== ""
                    asynchronous: true

                    layer.enabled: albumArtImage.visible
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 32
                        blur: 0.12 // light blur (4px equiv)
                        maskEnabled: true
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                        maskSource: Rectangle {
                            width: albumArtImage.width
                            height: albumArtImage.height
                            radius: albumArtImage.width / 2
                        }
                    }
                }

                // Radial Gradient: smooth/wide fade region, starts closer to the center
                Shapes.Shape {
                    id: radialGrad
                    anchors.fill: parent
                    Shapes.ShapePath {
                        strokeColor: "transparent"
                        fillGradient: Shapes.RadialGradient {
                            centerX: radialGrad.width / 2
                            centerY: radialGrad.height / 2
                            centerRadius: radialGrad.width / 2
                            focalX: centerX
                            focalY: centerY
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.25; color: "transparent" }
                            GradientStop { position: 0.62; color: ColorUtils.transparentize(Appearance.m3colors.m3shadow, 0.4) }
                            GradientStop { position: 0.75; color: ColorUtils.transparentize(Appearance.m3colors.m3shadow, 0.2) }
                            GradientStop { position: 1.0; color: Appearance.m3colors.m3shadow }
                        }
                        PathRectangle { x: 0; y: 0; width: radialGrad.width; height: radialGrad.height }
                    }
                }
            }

            // Main Content Layout (Completely outside the art layer, sitting on top of the gradient)
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: parent.width * 0.02 // minimized margins
                spacing: 1 // minimized spacing
                z: 2

                // Spacer top
                Item {
                    Layout.fillHeight: true
                }

                // Row with App Icon and Song Title (Centered RowLayout)
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: root.width * 0.08
                    spacing: 6

                    MaterialShape {
                        id: sourceIconBadge
                        Layout.preferredWidth: root.width * 0.075
                        Layout.preferredHeight: Layout.preferredWidth
                        shapeString: "Circle"
                        color: "transparent"

                        Loader {
                            id: appIconLoader
                            anchors.fill: parent
                            active: root.player && root.player.desktopEntry !== ""
                            sourceComponent: IconImage {
                                implicitSize: parent.width
                                anchors.centerIn: parent
                                source: Quickshell.iconPath(root.player ? root.player.desktopEntry : "audio-x-generic", "audio-x-generic")
                            }
                        }

                        Loader {
                            anchors.fill: parent
                            active: !appIconLoader.active
                            sourceComponent: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "music_note"
                                iconSize: parent.width * 0.8
                                color: root.activeTextColor
                            }
                        }
                    }

                    StyledText {
                        text: root.trackTitle
                        color: root.activeTextColor
                        font.pixelSize: root.width * 0.07 // reduced font size
                        font.weight: Font.Bold
                        font.styleName: "Rounded"
                        Layout.maximumWidth: root.width * 0.46
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                // Artist Name Row
                StyledText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.leftMargin: parent.width * 0.06
                    Layout.rightMargin: parent.width * 0.06
                    text: root.trackArtist
                    color: root.activeSubtextColor
                    font.pixelSize: root.width * 0.038 // reduced font size
                    font.weight: Font.Normal
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                // Minimal Spacer between text and controls
                Item {
                    Layout.preferredHeight: 3
                }

                // Controls Area (Previous, Play/Pause + Squiggle progress, Next)
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: root.width * 0.28
                    Layout.preferredWidth: root.width * 0.76

                    Row {
                        anchors.centerIn: parent
                        spacing: root.width * 0.05

                        // Previous Button (Perfect Circle matching watch design guidelines)
                        RippleButton {
                            id: prevButton
                            visible: root.cfgShowPrevBtn
                            width: root.width * 0.20
                            height: width // perfect circle
                            anchors.verticalCenter: parent.verticalCenter
                            buttonRadius: width / 2
                            colBackground: root.activeAccentColor
                            colBackgroundHover: ColorUtils.mix(root.activeAccentColor, root.activeAccentColor, 0.9)
                            colRipple: ColorUtils.mix(root.activeAccentColor, root.activeAccentColor, 0.8)

                            contentItem: MaterialSymbol {
                                text: "skip_previous"
                                iconSize: parent.width * 0.6
                                color: root.activeOnPrimary
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: {
                                if (root.player)
                                    root.player.previous();
                            }
                        }

                        // Play/Pause central button wrapper (includes thickness for progress border)
                        Item {
                            id: centralButtonWrapper
                            width: root.width * 0.26
                            height: width
                            anchors.verticalCenter: parent.verticalCenter

                            // Underlay progress bar in Cookie9Sided shape with thicker borders
                            MaterialShape {
                                id: progressBgOutline
                                anchors.fill: parent
                                shapeString: Config.options.background.widgets.circular_media.progressShape ?? "Cookie9Sided"
                                color: "transparent"
                                borderColor: ColorUtils.mix("#000000", root.activeAccentColor, 0.70)
                                borderWidth: 0.055
                            }

                            MaterialShape {
                                id: progressActiveOutline
                                anchors.fill: parent
                                shapeString: Config.options.background.widgets.circular_media.progressShape ?? "Cookie9Sided"
                                color: "transparent"
                                borderColor: root.activeAccentColor
                                borderWidth: 0.055
                                visible: false
                            }

                            Shapes.Shape {
                                id: conicalMask
                                anchors.fill: progressActiveOutline
                                visible: false
                                Shapes.ShapePath {
                                    strokeColor: "transparent"
                                    fillGradient: Shapes.ConicalGradient {
                                        centerX: progressActiveOutline.width / 2
                                        centerY: progressActiveOutline.height / 2
                                        angle: -90
                                        GradientStop { position: 0.0; color: "white" }
                                        GradientStop { position: root.progressValue; color: "white" }
                                        GradientStop { position: root.progressValue + 0.0001; color: "transparent" }
                                        GradientStop { position: 1.0; color: "transparent" }
                                    }
                                    PathRectangle { x: 0; y: 0; width: progressActiveOutline.width; height: progressActiveOutline.height }
                                }
                            }

                            MultiEffect {
                                anchors.fill: progressActiveOutline
                                source: progressActiveOutline
                                maskEnabled: true
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1
                                maskSource: conicalMask
                            }

                            // Play/Pause button shape inside Cookie9Sided
                            RippleButton {
                                id: playPauseButton
                                anchors.fill: parent
                                anchors.margins: parent.width * 0.08
                                buttonRadius: width / 2
                                colBackground: root.activeAccentColor
                                colBackgroundHover: ColorUtils.mix(root.activeAccentColor, root.activeAccentColor, 0.9)
                                colRipple: ColorUtils.mix(root.activeAccentContainer, root.activeAccentColor, 0.8)

                                layer.enabled: playPauseButton.visible
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskThresholdMin: 0.5
                                    maskSpreadAtMin: 1
                                    maskSource: MaterialShape {
                                        width: playPauseButton.width
                                        height: playPauseButton.height
                                        shapeString: Config.options.background.widgets.circular_media.progressShape ?? "Cookie9Sided"
                                    }
                                }

                                contentItem: MaterialSymbol {
                                    text: root.playing ? "pause" : "play_arrow"
                                    fill: 1
                                    iconSize: parent.width * 0.5
                                    color: root.activeOnPrimary
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    if (root.player)
                                        root.player.togglePlaying();
                                }
                            }
                        }

                        // Next Button (Perfect Circle matching watch design guidelines)
                        RippleButton {
                            id: nextButton
                            visible: root.cfgShowNextBtn
                            width: root.width * 0.20
                            height: width // perfect circle
                            anchors.verticalCenter: parent.verticalCenter
                            buttonRadius: width / 2
                            colBackground: root.activeAccentColor
                            colBackgroundHover: ColorUtils.mix(root.activeAccentColor, root.activeAccentColor, 0.9)
                            colRipple: ColorUtils.mix(root.activeAccentColor, root.activeAccentColor, 0.8)

                            contentItem: MaterialSymbol {
                                text: "skip_next"
                                iconSize: parent.width * 0.6
                                color: root.activeOnPrimary
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: {
                                if (root.player)
                                    root.player.next();
                            }
                        }
                    }
                }

                // Spacer
                Item {
                    Layout.fillHeight: true
                }

                // Audio Output Device Pill Shape (Centered at the Bottom)
                RowLayout {
                    visible: root.cfgShowDevicePill
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: root.width * 0.13

                    RippleButton {
                        id: devicePill
                        implicitHeight: root.width * 0.09
                        leftPadding: root.width * 0.04
                        rightPadding: root.width * 0.04
                        colBackground: ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHigh, 0.75)
                        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHighestHover, 0.65)
                        colRipple: ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHighestActive, 0.55)
                        buttonRadius: Appearance.rounding.full

                        readonly property string activeAudioDeviceName: Audio.sink ? (Audio.sink.description || "") : ""
                        readonly property string audioDeviceIcon: {
                            let desc = activeAudioDeviceName.toLowerCase();
                            if (desc.includes("headphone") || desc.includes("headset") || desc.includes("wired")) {
                                return "headphones";
                            }
                            return "volume_up";
                        }

                        onClicked: {
                            GlobalStates.openRightSidebar();
                            Qt.callLater(() => {
                                GlobalStates.requestVolumeDialog = true;
                            });
                        }

                        contentItem: Item {
                            implicitWidth: deviceRowLayout.implicitWidth
                            implicitHeight: devicePill.height

                            Row {
                                id: deviceRowLayout
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialSymbol {
                                    text: devicePill.audioDeviceIcon
                                    iconSize: devicePill.height * 0.5
                                    color: root.activeTextColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: devicePill.activeAudioDeviceName !== "" ? devicePill.activeAudioDeviceName : Translation.tr("Audio")
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.weight: Font.Bold
                                    color: root.activeTextColor
                                    width: Math.min(root.width * 0.32, implicitWidth)
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }

                // Spacer bottom
                Item {
                    Layout.fillHeight: true
                }
            }
        }

        // 3D Glass Dome Reflection Overlay
        Item {
            id: glassReflectionOverlay
            anchors.fill: parent
            z: 10
            enabled: false // Transparent to mouse events
            visible: Config.options.background.widgets.circular_media.enableGlassReflection ?? true

            Rectangle {
                id: outerGlassMask
                width: glassReflectionOverlay.width
                height: glassReflectionOverlay.height
                radius: width / 2
                visible: false
            }

            // GPU: release FBO when glass reflection is disabled
            layer.enabled: glassReflectionOverlay.visible
            layer.effect: MultiEffect {
                maskEnabled: true
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
                maskSource: outerGlassMask
            }

        // Top-Right Crescent Reflection (14:00 / 70 degrees)
        Item {
            id: topReflectionContainer
            anchors.fill: parent

            Shapes.Shape {
                id: topCrescentShape
                anchors.fill: parent
                layer.enabled: glassReflectionOverlay.visible
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 32
                    blur: 0.8
                }

                Shapes.ShapePath {
                    strokeColor: "transparent"
                    fillGradient: Shapes.LinearGradient {
                        x1: topReflectionContainer.width * 0.40; y1: topReflectionContainer.height * 0.04
                        x2: topReflectionContainer.width * 0.96; y2: topReflectionContainer.height * 0.60
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.3; color: ColorUtils.applyAlpha("#FFFFFF", 0.42) }
                        GradientStop { position: 0.7; color: ColorUtils.applyAlpha("#FFFFFF", 0.42) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }

                    startX: topReflectionContainer.width * 0.40
                    startY: topReflectionContainer.height * 0.04
                    PathArc {
                        x: topReflectionContainer.width * 0.96
                        y: topReflectionContainer.height * 0.60
                        radiusX: topReflectionContainer.width * 0.48
                        radiusY: topReflectionContainer.height * 0.48
                        useLargeArc: false
                    }
                    PathArc {
                        x: topReflectionContainer.width * 0.40
                        y: topReflectionContainer.height * 0.04
                        radiusX: topReflectionContainer.width * 0.35
                        radiusY: topReflectionContainer.height * 0.35
                        useLargeArc: false
                        direction: PathArc.Counterclockwise
                    }
                }
            }
        }

        // Bottom-Left Crescent Reflection (250 degrees / 8:00)
        Item {
            id: bottomReflectionContainer
            anchors.fill: parent

            Shapes.Shape {
                id: bottomCrescentShape
                anchors.fill: parent
                layer.enabled: glassReflectionOverlay.visible
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 32
                    blur: 0.8
                }

                Shapes.ShapePath {
                    strokeColor: "transparent"
                    fillGradient: Shapes.LinearGradient {
                        x1: bottomReflectionContainer.width * 0.60; y1: bottomReflectionContainer.height * 0.96
                        x2: bottomReflectionContainer.width * 0.04; y2: bottomReflectionContainer.height * 0.40
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.3; color: ColorUtils.applyAlpha("#FFFFFF", 0.28) }
                        GradientStop { position: 0.7; color: ColorUtils.applyAlpha("#FFFFFF", 0.28) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }

                    startX: bottomReflectionContainer.width * 0.60
                    startY: bottomReflectionContainer.height * 0.96
                    PathArc {
                        x: bottomReflectionContainer.width * 0.04
                        y: bottomReflectionContainer.height * 0.40
                        radiusX: bottomReflectionContainer.width * 0.48
                        radiusY: bottomReflectionContainer.height * 0.48
                        useLargeArc: false
                    }
                    PathArc {
                        x: bottomReflectionContainer.width * 0.60
                        y: bottomReflectionContainer.height * 0.96
                        radiusX: bottomReflectionContainer.width * 0.35
                        radiusY: bottomReflectionContainer.height * 0.35
                        useLargeArc: false
                        direction: PathArc.Counterclockwise
                    }
                }
            }
        }
        }
    }
