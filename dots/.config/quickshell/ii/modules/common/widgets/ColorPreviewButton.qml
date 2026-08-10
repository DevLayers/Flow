import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RippleButton {
    id: root
    readonly property string builtInThemeDirectory: Directories.defaultThemes
    readonly property string customThemeDirectory: Directories.customThemes

    property string colorScheme: "scheme-auto"
    property string colorSchemeDisplayName: ""

    property bool builtInTheme: false
    readonly property string builtInThemeFilePath: builtInThemeDirectory + "/" + colorScheme + ".json"
    readonly property string builtInThemeCommand: `jq -r '.primary, .primary_container, .secondary' ${builtInThemeFilePath}`

    property bool customTheme: false
    readonly property string customThemeFilePath: customThemeDirectory + "/" + colorScheme + ".json"
    readonly property string customThemeCommand: `jq -r '.primary, .primary_container, .secondary' ${customThemeFilePath}`

    readonly property string wallpaperPath: (Config.options && Config.options.background && Config.options.background.wallpaperPath) ? Config.options.background.wallpaperPath : ""
    readonly property string activeWallpaperPath: {
        if (Config.options && Config.options.background && Config.options.background.useWallpaperEngine) {
            return "/tmp/wpe_screenshot.png";
        }
        return wallpaperPath;
    }
    readonly property string scriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/generate_colors_material.py`)

    readonly property string resolvedScheme: root.colorScheme === "scheme-auto" ? "scheme-tonal-spot" : root.colorScheme
    property string fullCommand: root.activeWallpaperPath !== "" ? `${root.scriptPath} --path ${root.activeWallpaperPath} --scheme ${root.resolvedScheme} --all-previews ${Directories.wallpaperPreviewColorsPath}` : ""

    // Primary/secondary/tertiary colors
    property color previewPrimary: "transparent"
    property color previewSecondary: "transparent"
    property color previewTertiary: "transparent"
    property bool usePreviewColors: false

    property color primaryColor: usePreviewColors ? previewPrimary : "transparent"
    property color secondaryColor: usePreviewColors ? previewSecondary : "transparent"
    property color tertiaryColor: usePreviewColors ? previewTertiary : "transparent"

    property bool loaded: usePreviewColors
    property bool shouldLoad: false

    property bool isWidgetScheme: false
    property bool widgetSchemeToggled: false
    readonly property bool toggled: isWidgetScheme ? widgetSchemeToggled : (
                                                         Config.options.appearance.palette.type
                                                         === root.colorScheme)
    readonly property bool sharpMode: Config.options.appearance.sharpMode

    colBackground: toggled ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
    colBackgroundHover: toggled ? Appearance.colors.colPrimaryContainerHover :
                                  Appearance.colors.colLayer2Hover
    colRipple: toggled ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active

    buttonRadius: Appearance.rounding.small

    Layout.fillWidth: true
    implicitHeight: 64

    onClicked: {
        if (isWidgetScheme) {
            return;
        }
        if (customTheme) {
            Config.options.appearance.palette.type = root.colorScheme;
            const themePath = FileUtils.trimFileProtocol(root.customThemeFilePath);
            const targetPath = FileUtils.trimFileProtocol(Directories.generatedMaterialThemePath);
            const script = FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/recolor_icons.py`);
            Quickshell.execDetached(["bash", "-c", `cp "${themePath}" "${targetPath}" && python3 "${script}"`]);
        } else if (builtInTheme) {
            Config.options.appearance.palette.type = root.colorScheme;
            const themePath = FileUtils.trimFileProtocol(root.builtInThemeFilePath);
            const targetPath = FileUtils.trimFileProtocol(Directories.generatedMaterialThemePath);
            const script = FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/recolor_icons.py`);
            Quickshell.execDetached(["bash", "-c", `cp "${themePath}" "${targetPath}" && python3 "${script}"`]);
        } else {
            Config.options.appearance.palette.type = root.colorScheme;
            Quickshell.execDetached(["bash", "-c", `env -u LD_LIBRARY_PATH -u PYTHONHOME -u PYTHONPATH PATH=$HOME/.local/bin:$HOME/.cargo/bin:$PATH ${Directories.wallpaperSwitchScriptPath} --type ${root.colorScheme} --noswitch > /tmp/switchwall_button.log 2>&1`]);
        }
    }

    FileView {
        id: previewCacheFileView
        path: (!root.customTheme && !root.builtInTheme) ? Directories.wallpaperPreviewColorsPath : ""
        watchChanges: true
        onLoaded: {
            root.cacheRetryCount = 0;
            root.loadFromCache();
            if (root._awaitingFreshCache) {
                if (root.primaryColor !== root._preReloadPrimaryColor) {
                    root._awaitingFreshCache = false;
                } else if (root._staleRetryCount < 6) {
                    root._staleRetryCount++;
                    staleCacheRetryTimer.restart();
                } else {
                    root._awaitingFreshCache = false;
                }
            }
        }
        onLoadFailed: {
            cacheRetryTimer.start();
        }
    }

    property int cacheRetryCount: 0

    // The backend write we're waiting for is atomic (os.replace), so file-watcher
    // events on the same path can be missed or coalesced depending on how the watch
    // is implemented under the hood. A fixed debounce alone can't tell "reloaded before
    // the backend finished" apart from "reloaded after" -- so track what was on screen
    // before the wallpaper changed and keep polling until it actually differs.
    property bool _awaitingFreshCache: false
    property color _preReloadPrimaryColor: "transparent"
    property int _staleRetryCount: 0

    // Background regeneration of the preview cache (matugen + material color gen for
    // all schemes) takes well over a second, so an immediate reload right after the
    // wallpaper changes would just re-read the previous wallpaper's stale cache.
    Timer {
        id: cacheReloadTimer
        interval: 900
        repeat: false
        onTriggered: {
            if (root.customTheme || root.builtInTheme)
                return;
            root._preReloadPrimaryColor = root.primaryColor;
            root._awaitingFreshCache = true;
            root._staleRetryCount = 0;
            root.loaded = false;
            previewCacheFileView.reload();
        }
    }

    Timer {
        id: staleCacheRetryTimer
        interval: 400
        repeat: false
        onTriggered: previewCacheFileView.reload();
    }

    Timer {
        id: cacheRetryTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (root.cacheRetryCount >= 5)
                return;
            root.cacheRetryCount++;
            previewCacheFileView.reload();
        }
    }

    FileView {
        id: themeFileView
        path: root.customTheme ? root.customThemeFilePath : root.builtInTheme ? root.builtInThemeFilePath : ""
        watchChanges: false
        onLoaded: {
            try {
                const raw = themeFileView.text().trim();
                if (!raw)
                    return;
                const data = JSON.parse(raw);
                root.primaryColor = data.primary || "transparent";
                root.secondaryColor = data.primary_container || "transparent";
                root.tertiaryColor = data.secondary || "transparent";
                root.loaded = true;
            } catch (e) {
                console.log("[ColorPreviewButton] Failed to parse theme file:", path);
            }
        }
    }

    function loadFromCache() {
        if (root.customTheme || root.builtInTheme)
            return false;
        try {
            const raw = previewCacheFileView.text().trim();
            if (!raw)
                return false;
            const cache = JSON.parse(raw);
            const schemeData = cache[root.colorScheme];
            if (schemeData && schemeData.primary) {
                root.primaryColor = schemeData.primary;
                root.secondaryColor = schemeData.primary_container;
                root.tertiaryColor = schemeData.secondary;
                root.loaded = true;
                return true;
            }
        } catch (e) {
            // Ignore parse error
        }
        return false;
    }

    function requestLoad() {
        if (root.customTheme || root.builtInTheme) {
            themeFileView.reload();
            return;
        }

        if (root.loadFromCache()) {
            return;
        }

        if (root.fullCommand !== "") {
            colorFetchProcess.running = true;
        }
    }

    onShouldLoadChanged: {
        if (shouldLoad && !loaded) {
            root.requestLoad();
        }
    }

    onWallpaperPathChanged: {
        if (shouldLoad && !root.customTheme && !root.builtInTheme) {
            cacheReloadTimer.restart();
        }
    }

    readonly property string wpeId: (Config.options && Config.options.background)
                                    ? Config.options.background.wallpaperEngineId : ""
    onWpeIdChanged: {
        if (shouldLoad && !root.customTheme && !root.builtInTheme) {
            cacheReloadTimer.restart();
        }
    }

    property bool useWpe: (Config.options && Config.options.background)
                          ? Config.options.background.useWallpaperEngine : false
    onUseWpeChanged: {
        if (shouldLoad && !root.customTheme && !root.builtInTheme) {
            cacheReloadTimer.restart();
        }
    }

    Process {
        id: colorFetchProcess
        running: false
        command: ["bash", "-c", root.fullCommand]

        onExited: {
            // After running fallback process, reload cache
            Qt.callLater(() => {
                previewCacheFileView.reload();
            });
        }
    }

    StyledToolTip {
        text: root.colorSchemeDisplayName
    }

    Item {
        anchors.fill: parent

        StyledText {
            anchors.fill: parent
            visible: !root.loaded
            elide: Text.ElideRight
            text: root.colorSchemeDisplayName
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.colors.colOnPrimaryContainer
            font.pixelSize: Appearance.font.pixelSize.small
        }

        Item {
            id: colorCircleContainer
            anchors.centerIn: parent
            width: root.implicitHeight - 16
            height: root.implicitHeight - 16
            visible: root.loaded

            // Sharp mode (Square)
            Item {
                anchors.fill: parent
                visible: root.sharpMode

                // Top half: primaryColor
                Rectangle {
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    height: parent.height / 2
                    color: root.primaryColor
                }

                // Bottom-left quadrant: tertiaryColor
                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                    }
                    width: parent.width / 2
                    height: parent.height / 2
                    color: root.tertiaryColor
                }

                // Bottom-right quadrant: secondaryColor
                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        right: parent.right
                    }
                    width: parent.width / 2
                    height: parent.height / 2
                    color: root.secondaryColor
                }
            }

            // Circle mode (GPU-accelerated Shape with anti-aliased arcs)
            Shape {
                id: circleShape
                anchors.fill: parent
                visible: !root.sharpMode
                layer.enabled: true
                layer.samples: 4

                // Top half semi-circle (primary)
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: root.primaryColor
                    startX: circleShape.width / 2
                    startY: circleShape.height / 2
                    PathAngleArc {
                        centerX: circleShape.width / 2
                        centerY: circleShape.height / 2
                        radiusX: circleShape.width / 2
                        radiusY: circleShape.height / 2
                        startAngle: 180
                        sweepAngle: 180
                    }
                    PathLine {
                        x: circleShape.width / 2
                        y: circleShape.height / 2
                    }
                }

                // Bottom-right quarter circle (secondary)
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: root.secondaryColor
                    startX: circleShape.width / 2
                    startY: circleShape.height / 2
                    PathAngleArc {
                        centerX: circleShape.width / 2
                        centerY: circleShape.height / 2
                        radiusX: circleShape.width / 2
                        radiusY: circleShape.height / 2
                        startAngle: 0
                        sweepAngle: 90
                    }
                    PathLine {
                        x: circleShape.width / 2
                        y: circleShape.height / 2
                    }
                }

                // Bottom-left quarter circle (tertiary)
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: root.tertiaryColor
                    startX: circleShape.width / 2
                    startY: circleShape.height / 2
                    PathAngleArc {
                        centerX: circleShape.width / 2
                        centerY: circleShape.height / 2
                        radiusX: circleShape.width / 2
                        radiusY: circleShape.height / 2
                        startAngle: 90
                        sweepAngle: 90
                    }
                    PathLine {
                        x: circleShape.width / 2
                        y: circleShape.height / 2
                    }
                }
            }
        }
    }
}
